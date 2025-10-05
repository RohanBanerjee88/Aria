//
//  Constants.swift
//  Aria
//
//  Created by Rohan Banerjee on 10/4/25.
//
//

import Foundation

struct Constants {
    // REPLACE WITH YOUR ACTUAL API KEYS
    static let geminiAPIKey = "key key key "
    static let elevenLabsAPIKey = "hahahah" 
    
    // API Endpoints
    static let geminiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"
    static let elevenLabsEndpoint = "https://api.elevenlabs.io/v1/text-to-speech"  // NEW
    
    // ElevenLabs Voice ID (Rachel - clear, professional female voice)
    static let elevenLabsVoiceID = "21m00Tcm4TlvDq8ikWAM"  // Rachel voice
    
    // System prompt for vision analysis (Environment Mode)
    static let visionPrompt = """
    You are an AI assistant helping a blind or visually impaired person navigate their environment.
    
    Analyze this image and provide:
    1. OBSTACLES: Any obstacles directly in their path
    2. CLEAR PATHS: Which direction is safe to walk
    3. IMPORTANT OBJECTS: Key objects they should know about
    4. SPATIAL INFO: Brief distances and positions
    
    Keep your response:
    - BRIEF (2-3 sentences max)
    - ACTIONABLE (tell them what to do)
    - CLEAR (no technical jargon)
    - IMMEDIATE (focus on what's relevant right now)
    
    Example good response: "Clear path ahead for about 10 feet. There's a chair on your right side. Wall is about 5 feet to your left."
    """
    
    // System prompt for text reading (Communication Mode)
    static let textReadingPrompt = """
    You are helping a blind or visually impaired person read text from an image.
    
    Extract and read ALL visible text from this image. This could be:
    - Signs and labels
    - Documents and papers
    - Menus and receipts
    - Books and magazines
    - Product packaging
    - Street signs
    - Any other written content
    
    Instructions:
    - Read the text EXACTLY as it appears
    - Maintain the original order (top to bottom, left to right)
    - If there are multiple sections, clearly indicate transitions
    - If text is unclear or partially visible, mention that
    - If there's NO readable text, say "No readable text detected in this image"
    
    Keep it natural and easy to follow when spoken aloud.
    """
}
