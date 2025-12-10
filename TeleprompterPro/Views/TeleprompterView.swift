//
//  TeleprompterView.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import SwiftUI

struct TeleprompterView: View {
    let text: String
    let fontSize: CGFloat
    let scrollSpeed: Double
    let focusLinePosition: Double
    @Binding var isPlaying: Bool
    
    @State private var offset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var containerHeight: CGFloat = 0
    @State private var displayLink: CADisplayLink?
    
    func reset() {
        resetScroll()
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.7)
                // Place focus line at least ~2 lines from top; text starts below it.
                let lineHeight = fontSize * 1.4
                let minLineY = lineHeight * 2
                let desiredY = geo.size.height * focusLinePosition
                let lineY = min(max(minLineY, desiredY), geo.size.height - lineHeight)
                let spacerHeight = min(geo.size.height * 0.8, lineY + lineHeight * 0.5)
                VStack {
                    Color.clear.frame(height: spacerHeight)
                    Text(text)
                        .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(8)
                        .padding(.horizontal, 12)
                        .background(
                            HeightReader(height: $contentHeight)
                        )
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .offset(y: offset) // scrolling moves content upward
                
                GeometryReader { guideGeo in
                    let yPosition = max(0, min(guideGeo.size.height - 2, lineY))
                    VStack {
                        Rectangle()
                            .fill(Color.red.opacity(0.8))
                            .frame(height: 2)
                            .padding(.horizontal, 8)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .padding(.top, yPosition)
                        Spacer()
                    }
                }
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .onAppear {
                containerHeight = geo.size.height
                resetScroll()
                syncDisplayLinkIfNeeded()
            }
            .onChange(of: geo.size.height) { _, newHeight in
                containerHeight = newHeight
            }
            .onChange(of: isPlaying) { _, playing in
                playing ? startDisplayLink() : stopDisplayLink()
            }
            .onChange(of: text) { _, _ in
                resetScroll()
            }
            .onReceive(NotificationCenter.default.publisher(for: .teleprompterReset)) { _ in
                resetScroll()
            }
            .onDisappear {
                stopDisplayLink()
            }
        }
    }
    
    private func resetScroll() {
        offset = 0
    }
    
    private func syncDisplayLinkIfNeeded() {
        if isPlaying {
            startDisplayLink()
        }
    }
    
    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: DisplayLinkProxy { timestamp, delta in
            updateScroll(delta: delta)
        }, selector: #selector(DisplayLinkProxy.onFrame))
        displayLink = link
        link.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func updateScroll(delta: CFTimeInterval) {
        guard isPlaying else { return }
        
        let distance = scrollSpeed * delta
        offset -= CGFloat(distance)
        
        // Restart from the bottom once the text scrolls past the top.
        if abs(offset) > contentHeight + containerHeight {
            offset = 0
        }
    }
}

/// Helper to measure the height of variable text content.
private struct HeightReader: View {
    @Binding var height: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: HeightPreferenceKey.self, value: geo.size.height)
        }
        .onPreferenceChange(HeightPreferenceKey.self) { value in
            height = value
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// CADisplayLink target wrapper to avoid leaking `self`.
private final class DisplayLinkProxy {
    private let handler: (CFTimeInterval, CFTimeInterval) -> Void
    private var lastTimestamp: CFTimeInterval?
    
    init(handler: @escaping (CFTimeInterval, CFTimeInterval) -> Void) {
        self.handler = handler
    }
    
    @objc func onFrame(link: CADisplayLink) {
        let timestamp = link.timestamp
        defer { lastTimestamp = timestamp }
        
        guard let last = lastTimestamp else {
            return
        }
        
        let delta = timestamp - last
        handler(timestamp, delta)
    }
}
