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
    }
    
    func updateScrollSpeed(_ value: Double) {
        settings.scrollSpeed = value
    }
    
    func updateFontSize(_ value: CGFloat) {
        settings.fontSize = value
    }
}
