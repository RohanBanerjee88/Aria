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
    @StateObject private var audioService = AudioService()
    @StateObject private var navigationService = NavigationService()
    @State private var isProcessing = false
    @State private var currentMode: AppMode = .idle
    @State private var isModeLocked = false
    @State private var gestureTimer: Timer?
    @State private var showNavigationInput = false
    @State private var navigationDestination = ""
    
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
                    
                    HStack(spacing: 20) {
                        // Manual Capture button (hidden during navigation)
                        if !navigationService.isNavigating {
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
                                    
                                    Text("Analyze")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .disabled(isProcessing || currentMode == .idle)
                        }
                        
                        // Next Step button (only during navigation)
                        if navigationService.isNavigating {
                            Button(action: {
                                navigationService.nextStep()
                                if let instruction = navigationService.getCurrentInstruction() {
                                    speakText(instruction, usePremiumVoice: true)
                                } else {
                                    speakText("You have arrived at your destination", usePremiumVoice: true)
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 70, height: 70)
                                        .overlay(
                                            Image(systemName: "arrow.right.circle.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(.white)
                                        )
                                    
                                    Text("Next Step")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        
                        // Navigation button
                        Button(action: {
                            if navigationService.isNavigating {
                                navigationService.stopNavigation()
                                currentMode = .idle
                                isModeLocked = false
                                speakText("Navigation stopped", usePremiumVoice: true)
                            } else {
                                showNavigationInput = true
                            }
                        }) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(navigationService.isNavigating ? Color.red : Color.blue)
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        Image(systemName: navigationService.isNavigating ? "xmark" : "map.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white)
                                    )
                                
                                Text(navigationService.isNavigating ? "Stop" : "Navigate")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    
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
        .sheet(isPresented: $showNavigationInput) {
            NavigationInputView(
                navigationService: navigationService,
                audioService: audioService,
                isPresented: $showNavigationInput,
                onNavigationStart: {
                    currentMode = .navigation
                    isModeLocked = true
                }
            )
        }
    }
    
    // MARK: - Actions
    private func captureAndAnalyze() {
        guard currentMode != .idle else {
            speakText("Please show a gesture first", usePremiumVoice: false)
            return
        }
        
        // Don't analyze in navigation mode (navigation handles its own speech)
        guard currentMode != .navigation else {
            return
        }
        
        isProcessing = true
        
        // Capture current frame
        guard let frame = cameraService.captureCurrentFrame() else {
            print("❌ Failed to capture frame")
            isProcessing = false
            return
        }
        
        print("✅ Frame captured: \(frame.size)")
        
        // Analyze with Gemini based on current mode
        let modeToUse = currentMode
        
        Task {
            do {
                let geminiService = GeminiService()
                let analysis = try await geminiService.analyzeImage(frame, mode: modeToUse)
                
                // Print result
                print("🎯 ANALYSIS (\(modeToUse.displayName)): \(analysis)")
                
                // Speak with premium voice for analysis results
                speakText(analysis, usePremiumVoice: true)
                
                await MainActor.run {
                    isProcessing = false
                }
            } catch {
                print("❌ Gemini error: \(error.localizedDescription)")
                speakText("Error analyzing scene. Please try again.", usePremiumVoice: false)
                
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
                // Stop navigation if active
                if navigationService.isNavigating {
                    navigationService.stopNavigation()
                    speakText("Navigation stopped", usePremiumVoice: true)
                } else {
                    speakText("Stopped", usePremiumVoice: false)
                }
                
                currentMode = .idle
                isModeLocked = false
                
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
            
            speakText("\(detectedMode.displayName) activated and locked", usePremiumVoice: false)
            
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
    
    // MARK: - Helper Methods
    private func getInstructionText() -> String {
        if navigationService.isNavigating {
            if let instruction = navigationService.getCurrentInstruction() {
                return instruction
            }
            return "Navigation active"
        }
        
        if isModeLocked {
            switch currentMode {
            case .environment:
                return "🔒 Environment Mode Locked\nMove freely - Fist to stop"
            case .communication:
                return "🔒 Reading Mode Locked\nPoint at text - Fist to stop"
            case .navigation:
                return "🔒 Navigation Mode\nFollowing directions"
            case .idle:
                return "Show a gesture to start"
            }
        } else {
            return "Show a gesture to start"
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

// MARK: - Navigation Input View
struct NavigationInputView: View {
    @ObservedObject var navigationService: NavigationService
    @ObservedObject var audioService: AudioService
    @Binding var isPresented: Bool
    var onNavigationStart: () -> Void
    
    @State private var destination = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Common destinations
    let quickDestinations = ["Starbucks", "Subway", "CVS", "7-Eleven", "McDonald's"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Where do you want to go?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Text input
                TextField("Enter destination", text: $destination)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .padding(.horizontal)
                    .autocapitalization(.words)
                
                // Quick destinations
                Text("Quick picks:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(quickDestinations, id: \.self) { place in
                            Button(action: {
                                destination = place
                            }) {
                                Text(place)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                Spacer()
                
                // Start navigation button
                Button(action: {
                    startNavigation()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "location.fill")
                            Text("Start Navigation")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(destination.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(destination.isEmpty || isLoading)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationTitle("Navigation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func startNavigation() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await navigationService.startNavigation(to: destination)
                
                await MainActor.run {
                    audioService.speak("Navigation started to \(destination)")
                    isPresented = false
                    onNavigationStart()
                    
                    // Speak first instruction
                    if let instruction = navigationService.getCurrentInstruction() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            audioService.speak(instruction)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    audioService.speak("Unable to get directions. \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    CameraView()
}
