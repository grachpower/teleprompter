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
#if canImport(UIKit)
import UIKit
#endif

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
    @Published var lastSavedAssetId: String?
    @Published var exposureBias: Float = 0
    @Published var minExposureBias: Float = -2
    @Published var maxExposureBias: Float = 2
    @Published var showControls: Bool = true
    @Published var focusSupported: Bool = false
    @Published var focusPosition: Float = 0.5
    
    private let defaults = UserDefaults.standard
    private enum Keys {
        static let cameraPosition = "camera.position"
        static let preset = "camera.preset"
        static let zoom = "camera.zoom"
        static let exposureBias = "camera.exposureBias"
        static let focusPosition = "camera.focusPosition"
        static let showControls = "camera.showControls"
    }
    
    private let movieOutput = AVCaptureMovieFileOutput()
    private var outputURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("camera-recording.mov")
    }
    override init() {
        super.init()
        loadPersisted()
        Task { @MainActor in
            await configureSession(position: currentPosition, preset: selectedPreset)
            applyInitialZoomAndExposure()
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
        zoomFactor = min(maxZoomFactor, max(1.0, zoomFactor))
        minExposureBias = device.minExposureTargetBias
        maxExposureBias = device.maxExposureTargetBias
        exposureBias = min(maxExposureBias, max(minExposureBias, exposureBias))
        focusSupported = device.isLockingFocusWithCustomLensPositionSupported
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func switchCamera(to position: AVCaptureDevice.Position) {
        Task { @MainActor in
            await configureSession(position: position, preset: selectedPreset)
            defaults.set(position.rawValue, forKey: Keys.cameraPosition)
        }
    }
    
    func updatePreset(_ preset: AVCaptureSession.Preset) {
        Task { @MainActor in
            await configureSession(position: currentPosition, preset: preset)
            defaults.set(preset.rawValue, forKey: Keys.preset)
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
                defaults.set(Double(zoomFactor), forKey: Keys.zoom)
            } catch {
                errorMessage = "Failed to set zoom: \(error.localizedDescription)"
            }
        }
    }
    
    func updateExposureBias(to value: Float) {
        Task { @MainActor in
            guard let device = activeVideoDevice else { return }
            let clamped = max(minExposureBias, min(value, maxExposureBias))
            do {
                try device.lockForConfiguration()
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.setExposureTargetBias(clamped) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.exposureBias = clamped
                        self?.defaults.set(clamped, forKey: Keys.exposureBias)
                    }
                }
                device.unlockForConfiguration()
            } catch {
                errorMessage = "Failed to set exposure: \(error.localizedDescription)"
            }
        }
    }
    
    func updateFocus(to value: Float) {
        Task { @MainActor in
            guard let device = activeVideoDevice, device.isLockingFocusWithCustomLensPositionSupported else {
                focusSupported = false
                return
            }
            let clamped = max(0, min(value, 1))
            do {
                try device.lockForConfiguration()
                device.setFocusModeLocked(lensPosition: clamped) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.focusPosition = clamped
                        self?.defaults.set(clamped, forKey: Keys.focusPosition)
                    }
                }
                device.unlockForConfiguration()
            } catch {
                errorMessage = "Failed to set focus: \(error.localizedDescription)"
            }
        }
    }
    
    func focus(at devicePoint: CGPoint) {
        Task { @MainActor in
            guard let device = activeVideoDevice else { return }
            guard device.isFocusPointOfInterestSupported || device.isExposurePointOfInterestSupported else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    } else if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    } else if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                }
                device.unlockForConfiguration()
            } catch {
                errorMessage = "Failed to set focus point: \(error.localizedDescription)"
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
        lastSavedAssetId = nil
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
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
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    private func loadPersisted() {
        if let storedPosition = defaults.object(forKey: Keys.cameraPosition) as? Int,
           let position = AVCaptureDevice.Position(rawValue: storedPosition) {
            currentPosition = position
        }
        if let presetRaw = defaults.string(forKey: Keys.preset) {
            let preset = AVCaptureSession.Preset(rawValue: presetRaw)
            selectedPreset = preset
        }
        let storedZoom = defaults.double(forKey: Keys.zoom)
        if storedZoom > 0 {
            zoomFactor = CGFloat(storedZoom)
        }
        let storedExposure = defaults.object(forKey: Keys.exposureBias) as? Float
        if let storedExposure = storedExposure {
            exposureBias = storedExposure
        }
        if let storedFocus = defaults.object(forKey: Keys.focusPosition) as? Float {
            focusPosition = storedFocus
        }
        showControls = defaults.object(forKey: Keys.showControls) as? Bool ?? true
    }
    
    private func applyInitialZoomAndExposure() {
        updateZoom(to: zoomFactor)
        updateExposureBias(to: exposureBias)
        updateFocus(to: focusPosition)
    }
    
    func setControlsVisibility(_ visible: Bool) {
        showControls = visible
        defaults.set(visible, forKey: Keys.showControls)
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
            self?.saveVideoToPhotos(outputFileURL) { assetId in
                if let assetId = assetId {
                    RecordingAssetStore.shared.add(id: assetId)
                    self?.lastSavedAssetId = assetId
                }
            }
        }
    }
    
    private func saveVideoToPhotos(_ url: URL, completion: @escaping (String?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.errorMessage = "Photo Library permission denied"
                    completion(nil)
                }
                return
            }

            var createdId: String?
            PHPhotoLibrary.shared().performChanges({
                if let request = PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url),
                   let placeholder = request.placeholderForCreatedAsset {
                    createdId = placeholder.localIdentifier
                }
            }) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Save failed: \(error.localizedDescription)"
                        completion(nil)
                    } else if !success {
                        self.errorMessage = "Save failed."
                        completion(nil)
                    } else {
                        completion(createdId)
                    }
                }
            }
        }
    }
}
