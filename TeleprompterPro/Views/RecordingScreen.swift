//
//  RecordingScreen.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import SwiftUI
import AVFoundation

struct RecordingScreen: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var audioInputManager: AudioInputManager
    
    @State private var statusMessage: String?
    @State private var countdownRemaining: Int?
    @State private var countdownTotal: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var showControls: Bool = true
    
    private let presets: [(name: String, preset: AVCaptureSession.Preset)] = [
        ("High", .high),
        ("Medium", .medium),
        ("Low", .low),
        ("720p", .hd1280x720),
        ("1080p", .hd1920x1080),
        ("4K", .hd4K3840x2160)
    ]
    
    var body: some View {
        ZStack {
            CameraPreviewView(manager: cameraManager)
                .ignoresSafeArea(edges: .top)
            
            Color.black.opacity(0.05)
                .ignoresSafeArea(edges: .top)
            
            countdownOverlay
            
            VStack {
                HStack {
                    Button(action: resetTeleprompter) {
                        Label("Reset", systemImage: "arrow.uturn.backward")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .padding([.top, .leading], 16)
                    
                    Button(action: { showControls.toggle() }) {
                        Label(showControls ? "Hide Controls" : "Show Controls", systemImage: showControls ? "eye.slash" : "eye")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .padding([.top, .leading], 8)
                    Spacer()
                }
                
                GeometryReader { geo in
                    let lineHeight = viewModel.settings.fontSize * 1.4
                    let visibleLines = max(4, viewModel.settings.visibleLineCount)
                    let desiredHeight = lineHeight * CGFloat(visibleLines) + 32
                    let maxHeight = geo.size.height * 0.5
                    let teleHeight = min(maxHeight, desiredHeight)
                    let teleWidth = min(geo.size.width * 0.9, 380)
                    
                    HStack {
                        Spacer()
                        TeleprompterView(
                            text: viewModel.scriptText,
                            fontSize: viewModel.settings.fontSize,
                            scrollSpeed: viewModel.settings.scrollSpeed,
                            focusLinePosition: viewModel.settings.focusLinePosition,
                            isPlaying: $viewModel.isPlaying
                        )
                        .frame(width: teleWidth, height: teleHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding()
                        Spacer()
                    }
                }

                Spacer()
                
                VStack(spacing: 12) {
                    if showControls {
                        controlsPanel
                    }
                    
                    if countdownRemaining != nil {
                        Button(action: cancelCountdown) {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 32)
                    } else {
                        Button(action: toggleRecording) {
                            Text(cameraManager.isRecording ? "Stop" : "Start")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(cameraManager.isRecording ? Color.red : Color.green)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    if let message = statusMessage {
                        Text(message)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                    } else if let cameraError = cameraManager.errorMessage {
                        Text(cameraError)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 16)
                    } else if let audioError = audioInputManager.errorMessage {
                        Text(audioError)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .onChange(of: cameraManager.isRecording) { _, isRecording in
            viewModel.isPlaying = isRecording
        }
        .onChange(of: cameraManager.lastSaveMessage) { _, msg in
            if let msg = msg {
                statusMessage = msg
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if statusMessage == msg {
                        statusMessage = nil
                    }
                }
            }
        }
        .onChange(of: cameraManager.errorMessage) { _, err in
            if let err = err {
                statusMessage = err
            }
        }
        .task {
            await audioInputManager.refreshAvailableInputs()
        }
    }
    
    private var controlsPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Camera")
                    .foregroundColor(.white)
                Spacer()
                Picker("Camera", selection: Binding(
                    get: { cameraManager.currentPosition },
                    set: { cameraManager.switchCamera(to: $0) }
                )) {
                    Text("Front").tag(AVCaptureDevice.Position.front)
                    Text("Back").tag(AVCaptureDevice.Position.back)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            
            HStack {
                Text("Quality")
                    .foregroundColor(.white)
                Spacer()
                Picker("Quality", selection: Binding(
                    get: { cameraManager.selectedPreset },
                    set: { cameraManager.updatePreset($0) }
                )) {
                    ForEach(presets, id: \.preset) { item in
                        Text(item.name).tag(item.preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Text("Zoom")
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.1fx", cameraManager.zoomFactor))
                        .foregroundColor(.white)
                }
                Slider(value: Binding(
                    get: { cameraManager.zoomFactor },
                    set: { cameraManager.updateZoom(to: $0) }
                ), in: zoomRange, step: 0.1)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Countdown")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(viewModel.countdownSeconds) s")
                        .foregroundColor(.white)
                }
                Slider(value: Binding(
                    get: { Double(viewModel.countdownSeconds) },
                    set: { viewModel.countdownSeconds = Int($0) }
                ), in: 0...30, step: 1)
            }
            
            if !audioInputManager.availableInputs.isEmpty {
                HStack {
                    Text("Mic")
                        .foregroundColor(.white)
                    Spacer()
                    Picker("Mic", selection: Binding(
                        get: { audioInputManager.selectedInputId ?? audioInputManager.availableInputs.first?.uid ?? "" },
                        set: { audioInputManager.selectInput(id: $0) }
                    )) {
                        ForEach(audioInputManager.availableInputs, id: \.uid) { input in
                            Text(input.portName).tag(input.uid)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var zoomRange: ClosedRange<Double> {
        let upper = max(Double(cameraManager.maxZoomFactor), 1.1)
        return 1.0...upper
    }
    
    private func toggleRecording() {
        if cameraManager.isRecording {
            stopRecording()
        } else if countdownRemaining != nil {
            cancelCountdown()
        } else {
            startRecordingWithCountdown()
        }
    }
    
    private var countdownOverlay: some View {
        Group {
            if let remaining = countdownRemaining, let total = countdownTotal, total > 0 {
                let progress = 1 - Double(remaining) / Double(total)
                VStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 6)
                            .frame(width: 120, height: 120)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.25), value: progress)
                        
                        VStack(spacing: 4) {
                            Text("\(remaining)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("seconds")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.bottom, 80)
                    
                    Button(action: cancelCountdown) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.9))
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private func startRecordingWithCountdown() {
        // Cancel any existing countdown.
        countdownTask?.cancel()
        countdownTask = nil
        
        let delay = max(viewModel.countdownSeconds, 0)
        guard delay > 0 else {
            startRecordingNow()
            return
        }
        
        countdownTotal = delay
        countdownTask = Task { @MainActor in
            var remaining = delay
            while remaining > 0 && !Task.isCancelled {
                countdownRemaining = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remaining -= 1
            }
            guard !Task.isCancelled else { return }
            countdownRemaining = nil
            countdownTotal = nil
            startRecordingNow()
        }
    }
    
    private func startRecordingNow() {
        statusMessage = "Recording..."
        viewModel.isPlaying = true
        cameraManager.startVideoRecording()
    }
    
    private func stopRecording() {
        viewModel.isPlaying = false
        countdownTask?.cancel()
        countdownTask = nil
        countdownRemaining = nil
        countdownTotal = nil
        cameraManager.stopVideoRecording()
    }
    
    private func resetTeleprompter() {
        NotificationCenter.default.post(name: .teleprompterReset, object: nil)
    }
    
    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownRemaining = nil
        countdownTotal = nil
        viewModel.isPlaying = false
        statusMessage = nil
    }
}

extension Notification.Name {
    static let teleprompterReset = Notification.Name("teleprompterReset")
}
