//
//  ScriptsScreen.swift
//  TeleprompterPro
//
//  Created by OpenCode on 22.01.26.
//

import SwiftUI

struct ScriptsScreen: View {
    @ObservedObject var teleprompterViewModel: TeleprompterViewModel
    @StateObject private var viewModel = ScriptLibraryViewModel()
    @State private var showEditor = false
    @State private var editingScript: ScriptItem?
    @State private var viewingScript: ScriptItem?
    @State private var activeScripts: [ScriptItem] = []
    @State private var activeTags: [String] = []
    @State private var showRecent = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground")
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("Scripts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingScript = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(item: $viewingScript) { script in
                ScriptPreviewSheet(
                    script: script,
                    onUse: {
                        teleprompterViewModel.scriptText = script.text
                        teleprompterViewModel.currentScriptId = script.id
                    },
                    onEdit: {
                        viewingScript = nil
                        showEditor = false
                        editingScript = script
                    },
                    onDuplicate: {
                        viewModel.duplicate(script)
                        viewModel.load()
                        refreshDerivedData()
                    },
                    onDelete: {
                        viewModel.deleteScript(script)
                        viewModel.load()
                        refreshDerivedData()
                    }
                )
            }
            .sheet(item: $editingScript) { script in
                ScriptEditorSheet(
                    script: script,
                    onSave: { title, text, tags in
                        viewModel.updateScript(script, title: title, text: text, tags: tags)
                        viewModel.load()
                        refreshDerivedData()
                    }
                )
            }
            .sheet(isPresented: $showEditor) {
                ScriptEditorSheet(
                    script: nil,
                    onSave: { title, text, tags in
                        viewModel.saveScript(title: title, text: text, tags: tags)
                        viewModel.load()
                        refreshDerivedData()
                        showEditor = false
                    }
                )
            }
            .task {
                viewModel.load()
                refreshDerivedData()
            }
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            currentScriptSection
            searchBar
            tagPicker
            list
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onChange(of: viewModel.searchQuery) { _, _ in
            refreshDerivedData()
        }
        .onChange(of: viewModel.selectedTag) { _, _ in
            refreshDerivedData()
        }
        .onChange(of: viewModel.scripts) { _, _ in
            refreshDerivedData()
        }
        .onChange(of: teleprompterViewModel.currentScriptId) { _, _ in
            refreshDerivedData()
        }
        .onAppear {
            refreshDerivedData()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search scripts", text: $viewModel.searchQuery)
                .foregroundColor(.primary)
            Spacer()
            Button {
                showRecent.toggle()
                refreshDerivedData()
            } label: {
                Image(systemName: showRecent ? "clock.fill" : "clock")
                    .foregroundColor(showRecent ? .primary : .secondary)
                    .padding(6)
                    .background(Color("AppCardBackground"))
                    .clipShape(Circle())
            }
        }
        .padding(10)
        .background(Color("AppCardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var tagPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(activeTags, id: \.self) { tag in
                    tagButton(for: tag)
                }
            }
        }
    }

    private func tagButton(for tag: String) -> some View {
        let isSelected = tag == viewModel.selectedTag
        return Button {
            viewModel.selectedTag = tag
        } label: {
            Text(tag)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.primary.opacity(0.12) : Color("AppCardBackground"))
                .foregroundColor(isSelected ? .primary : .secondary)
                .clipShape(Capsule())
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(activeScripts, id: \.id) { script in
                    ScriptRow(
                        script: script,
                        isSelected: script.id == teleprompterViewModel.currentScriptId,
                        onUse: {
                            viewingScript = script
                        },
                        onActivate: {
                            teleprompterViewModel.scriptText = script.text
                            teleprompterViewModel.currentScriptId = script.id
                        },
                        onEdit: {
                            showEditor = false
                            editingScript = script
                        },
                        onDelete: {
                            viewModel.deleteScript(script)
                            refreshDerivedData()
                        },
                        onDuplicate: {
                            viewModel.duplicate(script)
                            refreshDerivedData()
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var currentScriptSection: some View {
        let trimmed = teleprompterViewModel.scriptText
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let currentScript = selectedScript
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current script")
                    .font(.headline)
                Spacer()
                if currentScript != nil {
                    Text("Selected")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.12))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                }
            }

            Text(currentScript?.title ?? "No script selected")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            Text(currentScript.map { shortenedText($0.text) } ?? (trimmed.isEmpty ? "Pick a script from the list to keep it in sync." : shortenedText(trimmed)))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color("AppCardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var selectedScript: ScriptItem? {
        guard let currentId = teleprompterViewModel.currentScriptId else {
            return nil
        }
        return viewModel.scripts.first { $0.id == currentId }
    }

    private func shortenedText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.count <= 20 {
            return trimmed
        }
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: 20)
        return String(trimmed[..<endIndex]) + "…"
    }

    private func refreshDerivedData() {
        var items = viewModel.scriptsForList()
        if showRecent {
            items = Array(items.prefix(10))
        }
        activeScripts = items
        activeTags = viewModel.allTags()
    }
}

private struct ScriptRow: View {
    let script: ScriptItem
    let isSelected: Bool
    let onUse: () -> Void
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(script.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Text(script.text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)

            HStack(spacing: 10) {
                Button(action: onActivate) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("Activate")

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("Edit")

                Spacer()

                Menu {
                    Button("Duplicate", action: onDuplicate)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Text(script.updatedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                ForEach(script.tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color("AppCardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onUse)
    }
}

private struct ScriptPreviewSheet: View {
    let script: ScriptItem
    let onUse: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground")
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(script.title)
                            .font(.title2.weight(.semibold))

                        if !script.tags.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(script.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color("AppCardBackground"))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        Text(script.text)
                            .font(.body)
                            .foregroundColor(.primary)

                        HStack(spacing: 12) {
                            Text(script.updatedAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Script")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onUse()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Use")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onEdit()
                        dismiss()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Duplicate") {
                            onDuplicate()
                            dismiss()
                        }
                        Button("Delete", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

private struct ScriptEditorSheet: View {
    let script: ScriptItem?
    let onSave: (String, String, [String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var text: String
    @State private var tags: String

    init(script: ScriptItem?, onSave: @escaping (String, String, [String]) -> Void) {
        self.script = script
        self.onSave = onSave
        _title = State(initialValue: script?.title ?? "")
        _text = State(initialValue: script?.text ?? "")
        _tags = State(initialValue: script?.tags.joined(separator: ", ") ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Title")) {
                    TextField("Script title", text: $title)
                }
                Section(header: Text("Script")) {
                    TextEditor(text: $text)
                        .frame(minHeight: 320, maxHeight: .infinity, alignment: .top)
                }
                Section(header: Text("Tags")) {
                    TextField("comma, separated, tags", text: $tags)
                }
            }
            .navigationTitle(script == nil ? "New Script" : "Edit Script")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let tagList = tags
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        onSave(title, text, tagList)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Save")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel")
                }
            }
        }
    }
}
