//
//  ScriptStore.swift
//  TeleprompterPro
//
//  Created by OpenCode on 22.01.26.
//

import Foundation

final class ScriptStore {
    static let shared = ScriptStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "teleprompter.scripts"

    private init() {}

    func load() -> [ScriptItem] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([ScriptItem].self, from: data)) ?? []
    }

    func save(_ scripts: [ScriptItem]) {
        let data = (try? JSONEncoder().encode(scripts)) ?? Data()
        defaults.set(data, forKey: storageKey)
    }
}
