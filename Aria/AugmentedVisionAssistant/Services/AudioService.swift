//
//  AudioService.swift
//  Aria
//
//  Created by Rohan Banerjee on 10/4/25.
//

import Foundation
import AVFoundation
import Combine

class AudioService: ObservableObject {
    private let elevenLabsService = ElevenLabsService()
    
    @Published var isSpeaking = false
    
    // Character count tracking for ElevenLabs quota management
    private var elevenLabsCharacterCount = 0
    private let elevenLabsFreeLimit = 10000  // 10k characters per month
    
    // MARK: - Text-to-Speech with ElevenLabs ONLY
    func speak(_ text: String, usePremiumVoice: Bool = true) {
        guard !text.isEmpty else { return }
        
        // Stop any current speech
        stopSpeaking()
        
        isSpeaking = true
        
        print("🎙️ Using ElevenLabs for: \"\(text.prefix(50))...\"")
        
        Task {
            await elevenLabsService.speak(text) { [weak self] success in
                if success {
                    self?.elevenLabsCharacterCount += text.count
                    print("📊 ElevenLabs usage: \(self?.elevenLabsCharacterCount ?? 0)/\(self?.elevenLabsFreeLimit ?? 0) chars")
                } else {
                    print("❌ ElevenLabs failed for text: \(text)")
                }
                
                DispatchQueue.main.async {
                    self?.isSpeaking = false
                }
            }
        }
    }
    
    // MARK: - Stop All Audio
    func stopSpeaking() {
        elevenLabsService.stopSpeaking()
        isSpeaking = false
    }
    
    // MARK: - Get Quota Status
    func getQuotaStatus() -> String {
        let remaining = elevenLabsFreeLimit - elevenLabsCharacterCount
        let percentage = (Double(elevenLabsCharacterCount) / Double(elevenLabsFreeLimit)) * 100
        return String(format: "%.0f%% used (%d/%d chars)", percentage, elevenLabsCharacterCount, elevenLabsFreeLimit)
    }
    
    func resetQuota() {
        elevenLabsCharacterCount = 0
    }
}
