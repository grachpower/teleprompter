//
//  CameraPreviewView.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let manager: CameraManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }
    
    func makeUIView(context: Context) -> Preview {
        let view = Preview()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = manager.session
        
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.previewView = view
        context.coordinator.updatePreviewOrientation()
        return view
    }
    
    func updateUIView(_ uiView: Preview, context: Context) {
        context.coordinator.updatePreviewOrientation()
    }
    
    final class Coordinator: NSObject {
        private let manager: CameraManager
        weak var previewView: Preview?
        private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
        private var rotationObservation: NSKeyValueObservation?
        private var observedDeviceID: String?
        
        init(manager: CameraManager) {
            self.manager = manager
        }

        func updatePreviewOrientation() {
            guard let previewView,
                  let device = manager.activeVideoDevice else { return }

            if observedDeviceID != device.uniqueID {
                rotationObservation = nil

                let coordinator = AVCaptureDevice.RotationCoordinator(
                    device: device,
                    previewLayer: previewView.videoPreviewLayer
                )
                rotationCoordinator = coordinator
                observedDeviceID = device.uniqueID

                rotationObservation = coordinator.observe(
                    \.videoRotationAngleForHorizonLevelPreview,
                    options: [.initial, .new]
                ) { [weak previewView] coordinator, _ in
                    let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                    guard let connection = previewView?.videoPreviewLayer.connection,
                          connection.isVideoRotationAngleSupported(angle) else { return }
                    connection.videoRotationAngle = angle
                }
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let layer = previewView?.videoPreviewLayer else { return }
            let point = gesture.location(in: previewView)
            let devicePoint = layer.captureDevicePointConverted(fromLayerPoint: point)
            manager.focus(at: devicePoint)
        }
    }
}

final class Preview: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        // Safe to force-cast because layerClass is AVCaptureVideoPreviewLayer.
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }
}
