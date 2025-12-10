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
        view.videoPreviewLayer.isGeometryFlipped = true // align touch coordinates with SwiftUI layout
        
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.previewView = view
        return view
    }
    
    func updateUIView(_ uiView: Preview, context: Context) { }
    
    final class Coordinator: NSObject {
        private let manager: CameraManager
        weak var previewView: Preview?
        
        init(manager: CameraManager) {
            self.manager = manager
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
