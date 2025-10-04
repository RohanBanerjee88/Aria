//
//  CameraView.swift
//  Aria
//
//  Created by Rohan Banerjee on 10/4/25.
//
import SwiftUI
import AVFoundation

// UIKit wrapper for camera preview
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraService: CameraService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Remove old layer if it exists
        uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        // Add new preview layer
        if let previewLayer = cameraService.previewLayer {
            previewLayer.frame = uiView.bounds
            uiView.layer.addSublayer(previewLayer)
        }
    }
}

// Main Camera View
struct CameraView: View {
    @StateObject private var cameraService = CameraService()
    @State private var isProcessing = false
    
    var body: some View {
        ZStack {
            // Camera Preview (full screen)
            if cameraService.isAuthorized {
                CameraPreview(cameraService: cameraService)
                    .ignoresSafeArea()
                    .onAppear {
                        print("🎥 Starting camera session...")
                        cameraService.startSession()
                    }
                    .onDisappear {
                        cameraService.stopSession()
                    }
            } else {
                // Permission denied state
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Please enable camera access in Settings to use Augmented Vision Assistant")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // Overlay UI (Controls and Status)
            VStack {
                // Top status bar
                HStack {
                    Circle()
                        .fill(isProcessing ? Color.red : Color.green)
                        .frame(width: 12, height: 12)
                    
                    Text(isProcessing ? "Processing..." : "Ready")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("Environment Mode")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Spacer()
                
                // Bottom control panel
                VStack(spacing: 16) {
                    Text("Tap to analyze scene")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Button(action: {
                        captureAndAnalyze()
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 90, height: 90)
                            )
                    }
                    .disabled(isProcessing)
                    
                    Text("Later: Use gestures to control")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Actions
    private func captureAndAnalyze() {
        isProcessing = true
        
        // Capture current frame
        guard let frame = cameraService.captureCurrentFrame() else {
            print("❌ Failed to capture frame")
            isProcessing = false
            return
        }
        
        print("✅ Frame captured: \(frame.size)")
        
        // Analyze with Gemini
        Task {
            do {
                let geminiService = GeminiService()
                let analysis = try await geminiService.analyzeImage(frame)
                
                // Print result (we'll add speech next!)
                print("🎯 ANALYSIS: \(analysis)")
                
                // Speak the result
                speakText(analysis)
                
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                print("❌ Gemini error: \(error.localizedDescription)")
                speakText("Error analyzing scene. Please try again.")
                
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
    
    // MARK: - Text to Speech
    private func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5 // Slower speech for clarity
        utterance.volume = 1.0
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
        
        print("🔊 Speaking: \(text)")
    }
}

#Preview {
    CameraView()
}
