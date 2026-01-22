//
//  GalleryScreen.swift
//  TeleprompterPro
//
//  Created by OpenCode on 22.01.26.
//

import AVFoundation
import AVKit
import Combine
import Photos
import SwiftUI
#if canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#endif

struct GalleryScreen: View {
    @StateObject private var viewModel = GalleryViewModel()
    @StateObject private var titleStore = RecordingTitleStoreAdapter()
    @State private var selectedAsset: PHAsset?
    @State private var player: AVPlayer?
    @State private var showPlayer = false
    @State private var isLoadingPlayer = false
    @State private var showRenamePrompt = false
    @State private var showPlaybackError = false
    @State private var renameText = ""
    @State private var filter: GalleryFilter = .all
    @State private var sort: GallerySort = .newest

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppBackground")
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Filter", selection: $filter) {
                            ForEach(GalleryFilter.allCases, id: \.self) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        Picker("Sort", selection: $sort) {
                            ForEach(GallerySort.allCases, id: \.self) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showPlayer, onDismiss: {
                player?.replaceCurrentItem(with: nil)
                player = nil
            }) {
                ZStack(alignment: .topTrailing) {
                    if let player = player {
                        VideoPlayerView(player: player)
                            .ignoresSafeArea()
                    } else {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.primary)
                            Text("Preparing video...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color("AppBackground"))
                    }

                    Button {
                        showPlayer = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(radius: 6)
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 64)
                    .accessibilityLabel("Close")
                }
            }
            .alert("Rename", isPresented: $showRenamePrompt) {
                TextField("Title", text: $renameText)
                Button("Save") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let asset = selectedAsset {
                        if trimmed.isEmpty {
                            titleStore.removeTitle(for: asset.localIdentifier)
                        } else {
                            titleStore.setTitle(trimmed, for: asset.localIdentifier)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Playback failed", isPresented: $showPlaybackError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Unable to load this video. Try again or check iCloud download.")
            }
            .task {
                viewModel.requestAccessAndLoad()
            }
        }
    }

    private var content: some View {
        Group {
            switch viewModel.authorizationStatus {
            case .authorized, .limited:
                if viewModel.assets.isEmpty {
                    emptyState
                } else if filteredAssets.isEmpty {
                    filteredEmptyState
                } else {
                    assetGrid
                }
            case .denied, .restricted:
                permissionState
            case .notDetermined:
                loadingState
            @unknown default:
                loadingState
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.primary)
            Text("Loading library...")
                .foregroundColor(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(.secondary)
            Text("No teleprompter recordings yet")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            Text("Record a take and it will appear here.")
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(32)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.secondary)
            Text("No matches")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            Text("Try changing the filter or sorting.")
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(32)
    }

    private var permissionState: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Photos access needed")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
            Text("Enable Photos access in Settings to browse your recordings.")
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(32)
    }

    private var assetGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredAssets, id: \PHAsset.localIdentifier) { asset in
                    GalleryCell(
                        asset: asset,
                        imageManager: viewModel.imageManager,
                        title: titleStore.title(for: asset.localIdentifier)
                    ) {
                        openPlayer(for: asset)
                    } onRename: {
                        selectedAsset = asset
                        renameText = titleStore.title(for: asset.localIdentifier) ?? ""
                        showRenamePrompt = true
                    } onDelete: {
                        delete(asset)
                    }
                }
            }
            .padding(16)
        }
    }

    private var filteredAssets: [PHAsset] {
        let items = filter.apply(to: viewModel.assets, titleStore: titleStore)
        return sort.apply(to: items, titleStore: titleStore)
    }

    private func openPlayer(for asset: PHAsset) {
        guard !isLoadingPlayer else { return }
        isLoadingPlayer = true
        selectedAsset = asset
        player = nil
        showPlayer = true
        viewModel.requestPlayerItem(for: asset) { item in
            if let item = item {
                player = AVPlayer(playerItem: item)
            } else {
                player = nil
                showPlayer = false
                showPlaybackError = true
            }
            isLoadingPlayer = false
        }
    }

    private func delete(_ asset: PHAsset) {
        viewModel.delete(asset) { success in
            if success {
                titleStore.removeTitle(for: asset.localIdentifier)
            }
        }
    }
}

private enum GalleryFilter: String, CaseIterable {
    case all
    case named
    case long

    var title: String {
        switch self {
        case .all:
            return "All"
        case .named:
            return "Named"
        case .long:
            return "Long (1+ min)"
        }
    }

    func apply(to assets: [PHAsset], titleStore: RecordingTitleStoreAdapter) -> [PHAsset] {
        switch self {
        case .all:
            return assets
        case .named:
            return assets.filter { asset in
                let title = titleStore.title(for: asset.localIdentifier) ?? ""
                return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        case .long:
            return assets.filter { $0.duration >= 60 }
        }
    }
}

private enum GallerySort: String, CaseIterable {
    case newest
    case oldest
    case duration
    case title

    var title: String {
        switch self {
        case .newest:
            return "Newest"
        case .oldest:
            return "Oldest"
        case .duration:
            return "Duration"
        case .title:
            return "Title"
        }
    }

    func apply(to assets: [PHAsset], titleStore: RecordingTitleStoreAdapter? = nil) -> [PHAsset] {
        switch self {
        case .newest:
            return assets.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        case .oldest:
            return assets.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        case .duration:
            return assets.sorted { $0.duration > $1.duration }
        case .title:
            guard let titleStore = titleStore else {
                return assets
            }
            return assets.sorted {
                let left = (titleStore.title(for: $0.localIdentifier) ?? dateFallback($0.creationDate)).lowercased()
                let right = (titleStore.title(for: $1.localIdentifier) ?? dateFallback($1.creationDate)).lowercased()
                return left < right
            }
        }
    }

    private func dateFallback(_ date: Date?) -> String {
        guard let date = date else { return "Untitled" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct GalleryCell: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    let title: String?
    let onPlay: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var thumbnail: PlatformImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Rectangle()
                    .fill(Color("AppCardBackground"))
                    .aspectRatio(9 / 16, contentMode: .fit)
                    .overlay(
                        Group {
                            if let thumbnail = thumbnail {
#if canImport(UIKit)
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
#elseif canImport(AppKit)
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
#endif
                            } else {
                                Image(systemName: "video")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onTapGesture(perform: onPlay)

                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(Color("AppCardBackground"))
                    .clipShape(Circle())
                    .padding(10)
            }

            Text(title?.isEmpty == false ? title! : formattedDate(asset.creationDate))
                .font(.footnote.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(durationText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Menu {
                    Button("Rename", action: onRename)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color("AppCardBackground"))
                        .clipShape(Circle())
                }
            }
        }
        .onAppear(perform: loadThumbnail)
    }

    private func loadThumbnail() {
        let targetSize = CGSize(width: 360, height: 640)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            thumbnail = image
        }
    }

    private var durationText: String {
        let duration = max(0, asset.duration)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "Untitled" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct VideoPlayerView: View {
    let player: AVPlayer

    var body: some View {
        VideoPlayer(player: player)
            .onAppear { player.play() }
            .onDisappear { player.pause() }
    }
}

private final class RecordingTitleStoreAdapter: ObservableObject {
    private let store = RecordingTitleStore.shared

    func title(for assetId: String) -> String? {
        store.title(for: assetId)
    }

    func setTitle(_ title: String, for assetId: String) {
        store.setTitle(title, for: assetId)
        objectWillChange.send()
    }

    func removeTitle(for assetId: String) {
        store.removeTitle(for: assetId)
        objectWillChange.send()
    }
}
