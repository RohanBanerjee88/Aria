//
//  Constants.swift
//  Aria
//
//  Created by Rohan Banerjee on 10/4/25.
//

import Foundation

struct Constants {
    // REPLACE WITH YOUR ACTUAL API KEY
    static let geminiAPIKey = "YOUR_API_KEY_HERE"
    
    // Gemini API Endpoint
    static let geminiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"
    
    // System prompt for vision analysis
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
}
