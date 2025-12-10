//
//  RecordingTitleStore.swift
//  TeleprompterPro
//
//  Created by OpenCode on 22.01.26.
//

import Foundation

final class RecordingTitleStore {
    static let shared = RecordingTitleStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "gallery.recordingTitles"

    private init() {}

    func title(for assetId: String) -> String? {
        let map = loadMap()
        return map[assetId]
    }

    func setTitle(_ title: String, for assetId: String) {
        var map = loadMap()
        map[assetId] = title
        saveMap(map)
    }

    func removeTitle(for assetId: String) {
        var map = loadMap()
        map.removeValue(forKey: assetId)
        saveMap(map)
    }

    func prune(keeping assetIds: Set<String>) {
        var map = loadMap()
        map = map.filter { assetIds.contains($0.key) }
        saveMap(map)
    }

    private func loadMap() -> [String: String] {
        guard let data = defaults.data(forKey: storageKey) else {
            return [:]
        }
        let map = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        return map
    }

    private func saveMap(_ map: [String: String]) {
        let data = (try? JSONEncoder().encode(map)) ?? Data()
        defaults.set(data, forKey: storageKey)
    }
}
