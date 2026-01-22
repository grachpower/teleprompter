//
//  ScriptItem.swift
//  TeleprompterPro
//
//  Created by OpenCode on 22.01.26.
//

import Foundation

struct ScriptItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var text: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, text: String, tags: [String] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.text = text
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
