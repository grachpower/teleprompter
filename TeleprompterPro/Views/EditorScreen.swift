//
//  EditorScreen.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import SwiftUI

struct EditorScreen: View {
    @ObservedObject var viewModel: TeleprompterViewModel
    @FocusState private var isEditing: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Script")
                            .font(.headline)
                        TextEditor(text: $viewModel.scriptText)
                            .focused($isEditing)
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scroll speed")
                            .font(.headline)
                        Slider(value: Binding(
                            get: { viewModel.settings.scrollSpeed },
                            set: { viewModel.updateScrollSpeed($0) }
                        ), in: 20...180, step: 5) {
                            Text("Scroll speed")
                        }
                        Text("\(Int(viewModel.settings.scrollSpeed)) px/sec")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Font size")
                            .font(.headline)
                        Slider(value: Binding(
                            get: { viewModel.settings.fontSize },
                            set: { viewModel.updateFontSize($0) }
                        ), in: 18...54, step: 1) {
                            Text("Font size")
                        }
                        Text("\(Int(viewModel.settings.fontSize)) pt")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Teleprompter preview")
                            .font(.headline)
                        TeleprompterView(
                            text: viewModel.scriptText,
                            fontSize: viewModel.settings.fontSize,
                            scrollSpeed: viewModel.settings.scrollSpeed,
                            isPlaying: .constant(false)
                        )
                        .frame(height: 180)
                    }
                }
                .padding()
            }
            .navigationTitle("Editor")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isEditing = false
                    }
                }
            }
        }
    }
}
