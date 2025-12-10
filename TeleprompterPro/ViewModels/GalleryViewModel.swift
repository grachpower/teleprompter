//
//  GalleryViewModel.swift
//  TeleprompterPro
//
//  Created by OpenCode on 22.01.26.
//

import AVFoundation
import Combine
import Photos
import SwiftUI

final class GalleryViewModel: NSObject, ObservableObject {
    @Published private(set) var assets: [PHAsset] = []
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    let imageManager = PHCachingImageManager()

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func requestAccessAndLoad() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = currentStatus
        guard currentStatus == .notDetermined else {
            loadAssets()
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                self?.loadAssets()
            }
        }
    }

    func loadAssets() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = status
        guard status == .authorized || status == .limited else {
            return
        }

        let storedIds = RecordingAssetStore.shared.allIds()
        guard !storedIds.isEmpty else {
            assets = []
            RecordingTitleStore.shared.prune(keeping: [])
            return
        }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(withLocalIdentifiers: storedIds, options: options)

        var items: [PHAsset] = []
        items.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            items.append(asset)
        }
        assets = items
        let ids = Set(items.map { $0.localIdentifier })
        RecordingAssetStore.shared.prune(keeping: ids)
        RecordingTitleStore.shared.prune(keeping: ids)
    }

    func requestPlayerItem(for asset: PHAsset, completion: @escaping (AVPlayerItem?) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        options.version = .current

        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
            if let item = item {
                DispatchQueue.main.async {
                    completion(item)
                }
                return
            }

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                DispatchQueue.main.async {
                    if let avAsset = avAsset {
                        completion(AVPlayerItem(asset: avAsset))
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }

    func delete(_ asset: PHAsset, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { success, error in
            DispatchQueue.main.async { [weak self] in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
                if success {
                    RecordingAssetStore.shared.remove(id: asset.localIdentifier)
                }
                completion(success)
            }
        }
    }
}

extension GalleryViewModel: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            self?.loadAssets()
        }
    }
}
