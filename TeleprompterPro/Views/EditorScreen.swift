//
//  EditorScreen.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import SwiftUI

struct EditorScreen: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground")
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Scroll speed")
                                .font(.headline)
                            Slider(value: Binding(
                                get: { viewModel.settings.scrollSpeed },
                                set: { viewModel.updateScrollSpeed($0) }
                            ), in: 20...80, step: 5) {
                                Text("Scroll speed")
                            }
                            Text("\(Int(viewModel.settings.scrollSpeed)) px/sec")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Font size")
                                .font(.headline)
                            Slider(value: Binding(
                                get: { viewModel.settings.fontSize },
                                set: { viewModel.updateFontSize($0) }
                            ), in: 18...54, step: 1) {
                                Text("Font size")
                            }
                            Text("\(Int(viewModel.settings.fontSize)) pt")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Visible lines")
                                .font(.headline)
                            Slider(value: Binding(
                                get: { Double(viewModel.settings.visibleLineCount) },
                                set: { viewModel.updateVisibleLines(Int($0)) }
                            ), in: 1...12, step: 1)
                            Text("\(viewModel.settings.visibleLineCount) lines")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Focus line position")
                                .font(.headline)
                            Slider(value: Binding(
                                get: { viewModel.settings.focusLinePosition },
                                set: { viewModel.updateFocusPosition($0) }
                            ), in: 0...1, step: 0.05)
                            Text(String(format: "%.0f%% from top", viewModel.settings.focusLinePosition * 100))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Teleprompter preview")
                                .font(.headline)
                            TeleprompterView(
                                text: viewModel.scriptText,
                                fontSize: viewModel.settings.fontSize,
                                scrollSpeed: viewModel.settings.scrollSpeed,
                                focusLinePosition: viewModel.settings.focusLinePosition,
                                isPlaying: .constant(false)
                            )
                            .frame(height: previewHeight)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Editor")
        }
    }

    private var previewHeight: CGFloat {
        let lineHeight = viewModel.settings.fontSize * 1.4
        let visibleLines = max(4, viewModel.settings.visibleLineCount)
        return min(260, lineHeight * CGFloat(visibleLines) + 32)
    }
}
