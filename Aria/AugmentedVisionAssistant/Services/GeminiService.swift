//
//  GeminiService.swift
//  Aria
//
//  Created by Rohan Banerjee on 10/4/25.
//

import Foundation
import UIKit

class GeminiService {
    
    // MARK: - Analyze Image with Gemini Vision
    func analyzeImage(_ image: UIImage, mode: AppMode) async throws -> String {
        // Select appropriate prompt based on mode
        let prompt: String
        switch mode {
        case .environment:
            prompt = Constants.visionPrompt
        case .communication:
            prompt = Constants.textReadingPrompt
        case .idle:
            prompt = Constants.visionPrompt // fallback
        }
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.imageConversionFailed
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Build request payload
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.4,
                "topK": 32,
                "topP": 1,
                "maxOutputTokens": mode == .communication ? 500 : 150  // More tokens for text reading
            ]
        ]
        
        // Create URL with API key
        guard var urlComponents = URLComponents(string: Constants.geminiEndpoint) else {
            throw GeminiError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: Constants.geminiAPIKey)
        ]
        
        guard let url = urlComponents.url else {
            throw GeminiError.invalidURL
        }
        
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("📤 Sending \(mode.displayName) request to Gemini...")
        
        // Make API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        print("📥 Response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            // Print error for debugging
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ API Error: \(errorString)")
            }
            throw GeminiError.apiError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let candidates = json?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.parsingFailed
        }
        
        print("✅ Gemini response: \(text)")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Error Types
enum GeminiError: LocalizedError {
    case imageConversionFailed
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to data"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let code):
            return "API error with status code: \(code)"
        case .parsingFailed:
            return "Failed to parse API response"
        }
    }
}
