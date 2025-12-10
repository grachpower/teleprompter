//
//  RecordingAssetStore.swift
//  TeleprompterPro
//
//  Created by OpenCode on 22.01.26.
//

import Foundation

final class RecordingAssetStore {
    static let shared = RecordingAssetStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "gallery.recordingAssets"

    private init() {}

    func allIds() -> [String] {
        defaults.stringArray(forKey: storageKey) ?? []
    }

    func add(id: String) {
        var ids = Set(allIds())
        ids.insert(id)
        defaults.set(Array(ids), forKey: storageKey)
    }

    func remove(id: String) {
        var ids = Set(allIds())
        ids.remove(id)
        defaults.set(Array(ids), forKey: storageKey)
    }

    func prune(keeping idsToKeep: Set<String>) {
        let ids = Set(allIds()).intersection(idsToKeep)
        defaults.set(Array(ids), forKey: storageKey)
    }
}
