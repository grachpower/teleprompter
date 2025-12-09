//
//  CameraManager.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import AVFoundation
import Foundation
import CoreGraphics

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var currentPosition: AVCaptureDevice.Position = .front
    @Published var selectedPreset: AVCaptureSession.Preset = .high
    @Published var maxZoomFactor: CGFloat = 1.0
    @Published var zoomFactor: CGFloat = 1.0
    
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
        
        // Select the front-facing wide angle camera.
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
        
        let videoOutput = AVCaptureVideoDataOutput()
        // We are not consuming frames yet, but keep output to make the session future-proof.
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        session.commitConfiguration()
        maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 8.0) // cap to avoid extreme zoom
        zoomFactor = 1.0
        session.startRunning()
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
}
