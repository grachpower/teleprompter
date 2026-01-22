//
//  AudioInputManager.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import AVFoundation
import Foundation
import Combine

final class AudioInputManager: ObservableObject {
    @Published var availableInputs: [AVAudioSessionPortDescription] = []
    @Published var selectedInputId: String?
    @Published var errorMessage: String?
    @Published var inputLevel: Float = 0
    @Published var peakLevel: Float = 0
    @Published var isSilent: Bool = false
    
    private let audioSession = AVAudioSession.sharedInstance()
    private let defaults = UserDefaults.standard
    private let selectedInputKey = "audio.selectedInputId"
    private var cancellables: Set<AnyCancellable> = []
    private var audioEngine: AVAudioEngine?
    private var lastActiveInputDate = Date()
    private let levelQueue = DispatchQueue(label: "audio.level.queue")
    
    init() {
        selectedInputId = defaults.string(forKey: selectedInputKey)
        observeAudioRouteChanges()
        Task { @MainActor in
            await refreshAvailableInputs()
        }
    }
    
    @MainActor
    func refreshAvailableInputs() async {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .videoRecording,
                options: [.allowBluetoothA2DP, .allowBluetoothHFP, .defaultToSpeaker]
            )
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Audio session failed: \(error.localizedDescription)"
        }
        availableInputs = audioSession.availableInputs ?? []
        if let storedId = selectedInputId, availableInputs.contains(where: { $0.uid == storedId }) {
            applyPreferredInputIfNeeded()
        } else {
            selectedInputId = audioSession.preferredInput?.uid
            defaults.set(selectedInputId, forKey: selectedInputKey)
        }
        startLevelMonitoring()
    }
    
    func selectInput(id: String) {
        Task { @MainActor in
            guard let target = availableInputs.first(where: { $0.uid == id }) else { return }
            do {
                try audioSession.setPreferredInput(target)
                selectedInputId = target.uid
                defaults.set(selectedInputId, forKey: selectedInputKey)
            } catch {
                errorMessage = "Failed to select mic: \(error.localizedDescription)"
            }
        }
    }

    private func observeAudioRouteChanges() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshAvailableInputs()
                    self?.applyPreferredInputIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func applyPreferredInputIfNeeded() {
        guard let selectedId = selectedInputId else { return }
        guard let target = availableInputs.first(where: { $0.uid == selectedId }) else { return }
        do {
            try audioSession.setPreferredInput(target)
            defaults.set(target.uid, forKey: selectedInputKey)
        } catch {
            errorMessage = "Failed to set mic: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func startLevelMonitoring() {
        stopLevelMonitoring()

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        do {
            try engine.start()
            audioEngine = engine
        } catch {
            errorMessage = "Mic monitor failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func stopLevelMonitoring() {
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            audioEngine = nil
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?.pointee else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var sum: Float = 0
        var peak: Float = 0
        for i in 0..<frameLength {
            let value = abs(channelData[i])
            sum += value
            peak = max(peak, value)
        }

        let avg = sum / Float(frameLength)
        let normalized = min(max(avg * 8, 0), 1)
        let peakNormalized = min(max(peak * 8, 0), 1)

        levelQueue.async { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.inputLevel = normalized
                self.peakLevel = max(self.peakLevel * 0.85, peakNormalized)
                if normalized > 0.02 {
                    self.lastActiveInputDate = Date()
                }
                self.isSilent = Date().timeIntervalSince(self.lastActiveInputDate) > 2.0
            }
        }
    }
}
