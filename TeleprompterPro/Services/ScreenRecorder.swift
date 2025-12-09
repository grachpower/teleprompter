//
//  ScreenRecorder.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import ReplayKit
import UIKit
import Photos

final class ScreenRecorder: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var errorMessage: String?
    
    private let recorder = RPScreenRecorder.shared()
    private var outputURL: URL? {
        let temp = FileManager.default.temporaryDirectory
        return temp.appendingPathComponent("teleprompter-recording.mp4")
    }
    
    func startRecording(completion: @escaping (Error?) -> Void) {
        recorder.isMicrophoneEnabled = true
        recorder.startRecording { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.isRecording = true
                }
                completion(error)
            }
        }
    }
    
    func stopRecording(completion: @escaping (Error?) -> Void) {
        guard let outputURL = outputURL else {
            completion(NSError(domain: "ScreenRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot create output URL"]))
            return
        }
        // Remove previous file if any.
        try? FileManager.default.removeItem(at: outputURL)
        
        recorder.stopRecording(withOutput: outputURL) { [weak self] error in
            DispatchQueue.main.async {
                self?.isRecording = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(error)
                    return
                }
                
                self?.saveToPhotoLibrary(videoURL: outputURL, completion: completion)
            }
        }
    }
    
    private func saveToPhotoLibrary(videoURL: URL, completion: @escaping (Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    let err = NSError(domain: "ScreenRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photo Library permission denied"])
                    self.errorMessage = err.localizedDescription
                    completion(err)
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Save failed: \(error.localizedDescription)"
                        completion(error)
                    } else if !success {
                        let err = NSError(domain: "ScreenRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Save failed"])
                        self.errorMessage = err.localizedDescription
                        completion(err)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }
}
