//
//  CameraView.swift
//  Aria
//
//  Created by Rohan Banerjee on 10/4/25.
//

import SwiftUI
import AVFoundation
import UIKit

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
    @StateObject private var audioService = AudioService()  // NEW: Smart audio manager
    @State private var isProcessing = false
    @State private var currentMode: AppMode = .idle
    @State private var isModeLocked = false
    @State private var gestureTimer: Timer?
    
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
                        HStack(spacing: 4) {
                            if isModeLocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                            }
                            Text(currentMode.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        
                        Text(isModeLocked ? "Locked - Fist to unlock" : "Gesture: \(gestureService.currentGesture.description)")
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
                        Text("✋ Open Palm = Navigate (Locks)")
                            .font(.caption)
                        Text("✌️ Peace Sign = Read Text (Locks)")
                            .font(.caption)
                        Text("✊ Fist = Stop & Unlock")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Instruction Text
    private func getInstructionText() -> String {
        if !cameraService.isAuthorized {
            return "Camera access is required. Tap Open Settings to enable camera access."
        }
        
        if isProcessing {
            if currentMode == .idle {
                return "Processing..."
            } else {
                return "Analyzing \(currentMode.displayName.lowercased())..."
            }
        }
        
        if currentMode == .idle {
            return "Show an open palm to navigate or a peace sign to read text. Make a fist to stop."
        }
        
        if isModeLocked {
            return "\(currentMode.displayName) mode locked. Make a fist to stop and unlock."
        }
        
        return "Ready for \(currentMode.displayName). Make a fist to stop."
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
                let analysis = try await geminiService.analyzeImage(frame, mode: currentMode)
                
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
    private func speakText(_ text: String, usePremiumVoice: Bool = true) {
        // Always uses ElevenLabs now!
        audioService.speak(text, usePremiumVoice: usePremiumVoice)
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
        
        let detectedGesture = gestureService.currentGesture
        let detectedMode = gestureService.detectedMode
        
        // FIST GESTURE: Always unlock and reset to idle
        if detectedGesture == .fist {
            if currentMode != .idle || isModeLocked {
                currentMode = .idle
                isModeLocked = false
                speakText("Stopped", usePremiumVoice: false)  // Use Apple for quick feedback
                
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            return
        }
        
        // If mode is locked, ignore other gestures
        if isModeLocked {
            return
        }
        
        // ACTIVATE NEW MODE: Only if currently idle and non-fist gesture detected
        if currentMode == .idle && detectedMode != .idle && detectedGesture != .unknown {
            currentMode = detectedMode
            isModeLocked = true  // Lock the mode
            
            speakText("\(detectedMode.displayName) activated and locked", usePremiumVoice: false)  // Apple for mode changes
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Auto-trigger analysis after mode locks
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if self.currentMode == detectedMode && self.isModeLocked && !self.isProcessing {
                    self.captureAndAnalyze()
                }
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
