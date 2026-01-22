//
//  TeleprompterViewModel.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import Foundation
import Combine
import CoreGraphics

final class TeleprompterViewModel: ObservableObject {
    @Published var scriptText: String
    @Published var settings: TeleprompterSettings
    @Published var isPlaying: Bool = false
    @Published var timerSeconds: Int = 3
    @Published var currentScriptId: UUID?
    
    private var cancellables: Set<AnyCancellable> = []
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let scriptText = "teleprompter.scriptText"
        static let scrollSpeed = "teleprompter.scrollSpeed"
        static let fontSize = "teleprompter.fontSize"
        static let timer = "teleprompter.timer"
        static let lineCount = "teleprompter.lineCount"
        static let focusPosition = "teleprompter.focusPosition"
        static let currentScriptId = "teleprompter.currentScriptId"
    }
    
    init(
        scriptText: String = """
        Welcome to TeleprompterPro!
        Paste or type your script here.
        Adjust the speed and font size in the editor tab,
        then switch to the recording tab to start.
        """
    ) {
        self.scriptText = scriptText
        self.settings = TeleprompterSettings()
        loadPersistedValues()
        observeChanges()
    }
    
    func updateScrollSpeed(_ value: Double) {
        settings.scrollSpeed = value
    }
    
    func updateFontSize(_ value: CGFloat) {
        settings.fontSize = value
    }
    
    func updateVisibleLines(_ value: Int) {
        settings.visibleLineCount = max(1, min(12, value))
    }
    
    func updateFocusPosition(_ value: Double) {
        settings.focusLinePosition = max(0.0, min(1.0, value))
    }
    
    private func loadPersistedValues() {
        if let storedText = defaults.string(forKey: Keys.scriptText) {
            scriptText = storedText
        }
        let storedSpeed = defaults.double(forKey: Keys.scrollSpeed)
        if storedSpeed > 0 {
            settings.scrollSpeed = storedSpeed
        }
        let storedFont = defaults.double(forKey: Keys.fontSize)
        if storedFont > 0 {
            settings.fontSize = CGFloat(storedFont)
        }
        let storedTimer = defaults.integer(forKey: Keys.timer)
        if storedTimer > 0 {
            timerSeconds = storedTimer
        }
        let storedLines = defaults.integer(forKey: Keys.lineCount)
        if storedLines > 0 {
            settings.visibleLineCount = storedLines
        }
        let storedFocus = defaults.double(forKey: Keys.focusPosition)
        if storedFocus > 0 {
            settings.focusLinePosition = storedFocus
        }
        if let storedScriptId = defaults.string(forKey: Keys.currentScriptId) {
            currentScriptId = UUID(uuidString: storedScriptId)
        }
    }
    
    private func observeChanges() {
        $scriptText
            .dropFirst()
            .sink { [weak self] value in
                self?.defaults.set(value, forKey: Keys.scriptText)
            }
            .store(in: &cancellables)
        
        $settings
            .dropFirst()
            .sink { [weak self] value in
                self?.defaults.set(value.scrollSpeed, forKey: Keys.scrollSpeed)
                self?.defaults.set(Double(value.fontSize), forKey: Keys.fontSize)
                self?.defaults.set(value.visibleLineCount, forKey: Keys.lineCount)
                self?.defaults.set(value.focusLinePosition, forKey: Keys.focusPosition)
            }
            .store(in: &cancellables)
        
        $timerSeconds
            .dropFirst()
            .sink { [weak self] value in
                self?.defaults.set(value, forKey: Keys.timer)
            }
            .store(in: &cancellables)

        $currentScriptId
            .dropFirst()
            .sink { [weak self] value in
                self?.defaults.set(value?.uuidString, forKey: Keys.currentScriptId)
            }
            .store(in: &cancellables)
    }
}
