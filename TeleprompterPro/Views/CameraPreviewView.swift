//
//  CameraPreviewView.swift
//  TeleprompterPro
//
//  Created by Codex on 09.12.25.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let manager: CameraManager
    
    func makeUIView(context: Context) -> Preview {
        let view = Preview()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = manager.session
        return view
    }
    
    func updateUIView(_ uiView: Preview, context: Context) { }
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
