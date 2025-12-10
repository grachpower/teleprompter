//
//  TeleprompterSettings.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import Foundation
import CoreGraphics

struct TeleprompterSettings {
    var scrollSpeed: Double = 30.0 // px per second for display link updates
    var fontSize: CGFloat = 28.0
    var visibleLineCount: Int = 6   // approximate lines visible in the overlay
    var focusLinePosition: Double = 0.25 // 0 (top) ... 1 (bottom) relative position of focus line
}
