//
//  ContentView.swift
//  TeleprompterPro
//
//  Created by Артем Андреев on 09.12.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TeleprompterViewModel()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var screenRecorder = ScreenRecorder()
    @StateObject private var audioInputManager = AudioInputManager()
    
    var body: some View {
        TabView {
            EditorScreen(viewModel: viewModel)
                .tabItem {
                    Label("Editor", systemName: "pencil")
                }
            
            RecordingScreen(
                viewModel: viewModel,
                cameraManager: cameraManager,
                screenRecorder: screenRecorder,
                audioInputManager: audioInputManager
            )
            .tabItem {
                Label("Record", systemName: "record.circle")
            }
        }
    }
}
