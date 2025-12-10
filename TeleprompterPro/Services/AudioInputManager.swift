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
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    init() {
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
        selectedInputId = audioSession.preferredInput?.uid
    }
    
    func selectInput(id: String) {
        Task { @MainActor in
            guard let target = availableInputs.first(where: { $0.uid == id }) else { return }
            do {
                try audioSession.setPreferredInput(target)
                selectedInputId = target.uid
            } catch {
                errorMessage = "Failed to select mic: \(error.localizedDescription)"
            }
        }
    }
}
