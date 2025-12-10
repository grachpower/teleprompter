//
//  CameraManager.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import AVFoundation
import Foundation
import CoreGraphics
import Combine
import Photos

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var currentPosition: AVCaptureDevice.Position = .front
    @Published var selectedPreset: AVCaptureSession.Preset = .high
    @Published var maxZoomFactor: CGFloat = 1.0
    @Published var zoomFactor: CGFloat = 1.0
    @Published var isRecording: Bool = false
    @Published var lastSaveMessage: String?
    
    private let movieOutput = AVCaptureMovieFileOutput()
    private var outputURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("camera-recording.mov")
    }
    override init() {
        super.init()
        Task { @MainActor in
            await configureSession()
        }
    }
    
    @MainActor
    private func configureSession(position: AVCaptureDevice.Position? = nil, preset: AVCaptureSession.Preset? = nil) async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status
        
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
        }
        
        guard authorizationStatus == .authorized else {
            errorMessage = "Camera access is not granted. Please enable it in Settings."
            return
        }
        
        session.beginConfiguration()
        if let newPreset = preset {
            selectedPreset = newPreset
        }
        if session.canSetSessionPreset(selectedPreset) {
            session.sessionPreset = selectedPreset
        }
        
        // Select camera.
        let desiredPosition = position ?? currentPosition
        currentPosition = desiredPosition
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: desiredPosition) else {
            errorMessage = "\(desiredPosition == .front ? "Front" : "Back") camera is unavailable."
            session.commitConfiguration()
            return
        }
        
        // Clean old inputs/outputs before applying new ones.
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            errorMessage = "Failed to create camera input: \(error.localizedDescription)"
            session.commitConfiguration()
            return
        }
        
        // Audio input for recorded video.
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            } catch {
                errorMessage = "Failed to add audio: \(error.localizedDescription)"
            }
        }
        
        // Movie output for camera recording.
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        
        session.commitConfiguration()
        maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 8.0) // cap to avoid extreme zoom
        zoomFactor = 1.0
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func switchCamera(to position: AVCaptureDevice.Position) {
        Task { @MainActor in
            await configureSession(position: position, preset: selectedPreset)
        }
    }
    
    func updatePreset(_ preset: AVCaptureSession.Preset) {
        Task { @MainActor in
            await configureSession(position: currentPosition, preset: preset)
        }
    }
    
    func updateZoom(to factor: CGFloat) {
        Task { @MainActor in
            guard let device = activeVideoDevice else { return }
            let clamped = max(1.0, min(factor, maxZoomFactor))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                zoomFactor = device.videoZoomFactor
            } catch {
                errorMessage = "Failed to set zoom: \(error.localizedDescription)"
            }
        }
    }
    
    private var activeVideoDevice: AVCaptureDevice? {
        session.inputs
            .compactMap { $0 as? AVCaptureDeviceInput }
            .first(where: { $0.device.hasMediaType(.video) })?
            .device
    }
    
    // MARK: - Recording
    
    func startVideoRecording() {
        errorMessage = nil
        lastSaveMessage = nil
        // Remove previous file if exists.
        try? FileManager.default.removeItem(at: outputURL)
        if let connection = movieOutput.connection(with: .video) {
            let angle = 90.0 // portrait
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
        if !movieOutput.isRecording {
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        }
    }
    
    func stopVideoRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            self?.lastSaveMessage = "Saved to Photos."
            self?.saveVideoToPhotos(outputFileURL)
        }
    }
    
    private func saveVideoToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.errorMessage = "Photo Library permission denied"
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Save failed: \(error.localizedDescription)"
                    } else if !success {
                        self.errorMessage = "Save failed."
                    }
                }
            }
        }
    }
}
