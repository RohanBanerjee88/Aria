//
//  ElevenLabsService.swift
//  Aria
//
//  Created by Rohan Banerjee on 10/4/25.
//

import Foundation
import AVFoundation

class ElevenLabsService {
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - Text to Speech with ElevenLabs
    func speak(_ text: String, completion: @escaping (Bool) -> Void) async {
        do {
            let audioData = try await generateSpeech(text: text)
            
            // Play audio on main thread
            await MainActor.run {
                playAudio(data: audioData, completion: completion)
            }
        } catch {
            print("❌ ElevenLabs error: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // MARK: - Generate Speech from ElevenLabs API
    private func generateSpeech(text: String) async throws -> Data {
        // Build URL with voice ID
        let urlString = "\(Constants.elevenLabsEndpoint)/\(Constants.elevenLabsVoiceID)"
        guard let url = URL(string: urlString) else {
            throw ElevenLabsError.invalidURL
        }
        
        // Build request payload
        let payload: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
                "style": 0.0,
                "use_speaker_boost": true
            ]
        ]
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("📤 Sending text to ElevenLabs: \"\(text.prefix(50))...\"")
        
        // Make API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.invalidResponse
        }
        
        print("📥 ElevenLabs response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ ElevenLabs API Error: \(errorString)")
            }
            throw ElevenLabsError.apiError(statusCode: httpResponse.statusCode)
        }
        
        print("✅ Audio generated successfully (\(data.count) bytes)")
        return data
    }
    
    // MARK: - Play Audio
    private func playAudio(data: Data, completion: @escaping (Bool) -> Void) {
        do {
            // Configure audio session for playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Create and play audio
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.volume = 1.0
            
            guard let player = audioPlayer else {
                completion(false)
                return
            }
            
            // Play audio
            player.play()
            print("🔊 Playing ElevenLabs audio...")
            
            // Wait for audio to finish
            DispatchQueue.global().async {
                while player.isPlaying {
                    Thread.sleep(forTimeInterval: 0.1)
                }
                DispatchQueue.main.async {
                    print("✅ Audio playback complete")
                    completion(true)
                }
            }
            
        } catch {
            print("❌ Audio playback error: \(error)")
            completion(false)
        }
    }
    
    // MARK: - Stop Current Audio
    func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

// MARK: - Error Types
enum ElevenLabsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid ElevenLabs API URL"
        case .invalidResponse:
            return "Invalid response from ElevenLabs"
        case .apiError(let code):
            return "ElevenLabs API error with status code: \(code)"
        }
    }
}
