//
//  ScriptLibraryViewModel.swift
//  TeleprompterPro
//
//  Created by OpenCode on 22.01.26.
//

import Foundation
import Combine

final class ScriptLibraryViewModel: ObservableObject {
    @Published private(set) var scripts: [ScriptItem] = []
    @Published var searchQuery: String = ""
    @Published var selectedTag: String = "All"

    private let store = ScriptStore.shared

    init() {
        load()
    }

    func load() {
        scripts = store.load().sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveScript(title: String, text: String, tags: [String]) {
        let now = Date()
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTitle = trimmedTitle.isEmpty ? "Untitled" : trimmedTitle
        let item = ScriptItem(title: newTitle, text: text, tags: tags, createdAt: now, updatedAt: now)
        scripts.insert(item, at: 0)
        persist()
    }

    func updateScript(_ item: ScriptItem, title: String, text: String, tags: [String]) {
        guard let index = scripts.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        scripts[index].title = trimmedTitle.isEmpty ? "Untitled" : trimmedTitle
        scripts[index].text = text
        scripts[index].tags = tags 
        scripts[index].updatedAt = Date()
        persist()
    }

    func deleteScript(_ item: ScriptItem) {
        scripts.removeAll { $0.id == item.id }
        persist()
    }

    func duplicate(_ item: ScriptItem) {
        let copy = ScriptItem(
            title: "\(item.title) Copy",
            text: item.text,
            tags: item.tags,
            createdAt: Date(),
            updatedAt: Date()
        )
        scripts.insert(copy, at: 0)
        persist()
    }

    func scriptsForList() -> [ScriptItem] {
        var filtered = scripts
        if selectedTag != "All" {
            filtered = filtered.filter { $0.tags.contains(selectedTag) }
        }
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchQuery.lowercased()
            filtered = filtered.filter {
                $0.title.lowercased().contains(query) || $0.text.lowercased().contains(query)
            }
        }
        return filtered
    }

    func allTags() -> [String] {
        let tags = scripts.flatMap { $0.tags }
        let unique = Array(Set(tags)).sorted()
        return ["All"] + unique
    }

    private func persist() {
        scripts.sort { $0.updatedAt > $1.updatedAt }
        store.save(scripts)
    }
}
