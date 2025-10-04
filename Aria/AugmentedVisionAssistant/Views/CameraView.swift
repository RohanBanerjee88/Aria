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
    @StateObject private var gestureService = GestureService()
    @State private var isProcessing = false
    @State private var currentMode: AppMode = .idle
    @State private var isModeLocked = false  // NEW: Lock mode once activated
    @State private var gestureTimer: Timer?
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        ZStack {
            // Camera Preview (full screen)
            if cameraService.isAuthorized {
                CameraPreview(cameraService: cameraService)
                    .ignoresSafeArea()
                    .onAppear {
                        print("🎥 Starting camera session...")
                        cameraService.startSession()
                        startGestureDetection()
                    }
                    .onDisappear {
                        cameraService.stopSession()
                        stopGestureDetection()
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
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(currentMode.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("Gesture: \(gestureService.currentGesture.description)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
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
                    Text(getInstructionText())
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Manual trigger button (optional backup)
                    Button(action: {
                        captureAndAnalyze()
                    }) {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(currentMode == .idle ? Color.gray : Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Image(systemName: isProcessing ? "hourglass" : "camera.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(currentMode == .idle ? .white : .black)
                                )
                            
                            Text("Manual Capture")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .disabled(isProcessing || currentMode == .idle)
                    
                    VStack(spacing: 4) {
                        Text("✋ Open Palm = Navigate (Auto)")
                            .font(.caption)
                        Text("✌️ Peace Sign = Read Text (Auto)")
                            .font(.caption)
                        Text("✊ Fist = Stop")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - UI Helpers
    private func getInstructionText() -> String {
        switch currentMode {
        case .idle:
            return "Show a hand gesture to choose a mode:\n✋ Open Palm = Navigate\n✌️ Peace Sign = Read Text\n✊ Fist = Stop"
        default:
            return isProcessing
                ? "Analyzing... hold steady."
                : "Hold steady. Auto-capturing when ready."
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
                let analysis = try await geminiService.analyzeImage(frame, mode: <#AppMode#>)
                
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
        // Stop any current speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5 // Slower speech for clarity
        utterance.volume = 1.0
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        
        print("🔊 Speaking: \(text)")
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - Gesture Detection
    private func startGestureDetection() {
        // Run gesture detection every 0.5 seconds
        gestureTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            detectGesture()
        }
    }
    
    private func stopGestureDetection() {
        gestureTimer?.invalidate()
        gestureTimer = nil
    }
    
    private func detectGesture() {
        guard let frame = cameraService.captureCurrentFrame() else { return }
        
        gestureService.analyzeGesture(from: frame)
        
        // Update mode if gesture changed
        if gestureService.detectedMode != currentMode {
            let newMode = gestureService.detectedMode
            let previousMode = currentMode
            currentMode = newMode
            
            // Announce mode change and auto-trigger analysis
            if newMode != .idle {
                speakText("\(newMode.displayName) activated")
                
                // Add haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // Auto-trigger analysis after a short delay (let user stabilize hand)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if self.currentMode == newMode && !self.isProcessing {
                        self.captureAndAnalyze()
                    }
                }
            } else if previousMode != .idle {
                // Switched to idle (fist gesture)
                speakText("Stopped")
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
    }
}

// MARK: - Gesture Type Description Extension
extension GestureType {
    var description: String {
        switch self {
        case .openPalm: return "Open Palm ✋"
        case .peaceSign: return "Peace Sign ✌️"
        case .fist: return "Fist ✊"
        case .unknown: return "None"
        }
    }
}

#Preview {
    CameraView()
}
