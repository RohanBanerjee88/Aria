//
//  GestureService.swift
//  Aria
//
//  Created by Rohan Banerjee on 10/4/25.
//

import Vision
import UIKit
import AVFoundation
import Combine

// App modes based on gestures
enum AppMode {
    case environment  // Navigation and obstacle detection
    case communication // Translation and reading text
    case navigation   // Turn-by-turn directions
    case idle         // No active mode
    
    var displayName: String {
        switch self {
        case .environment: return "Environment Mode"
        case .communication: return "Communication Mode"
        case .navigation: return "Navigation Mode"
        case .idle: return "Idle"
        }
    }
}

// Detected gesture types
enum GestureType {
    case openPalm      // 5 fingers = Environment mode
    case peaceSign     // 2 fingers = Communication mode
    case fist          // Closed hand = Stop/Idle
    case unknown
    
    var mode: AppMode {
        switch self {
        case .openPalm: return .environment
        case .peaceSign: return .communication
        case .fist: return .idle
        case .unknown: return .idle
        }
    }
}

class GestureService: ObservableObject {
    @Published var currentGesture: GestureType = .unknown
    @Published var detectedMode: AppMode = .idle
    @Published var confidence: Float = 0.0
    
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    init() {
        handPoseRequest.maximumHandCount = 1 // Only track one hand
    }
    
    // MARK: - Analyze Hand Gesture from Image
    func analyzeGesture(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([handPoseRequest])
            
            guard let observation = handPoseRequest.results?.first else {
                DispatchQueue.main.async {
                    self.currentGesture = .unknown
                    self.confidence = 0.0
                }
                return
            }
            
            let gesture = classifyHandPose(observation)
            
            DispatchQueue.main.async {
                self.currentGesture = gesture
                self.detectedMode = gesture.mode
                self.confidence = observation.confidence
            }
            
        } catch {
            print("❌ Hand pose detection error: \(error)")
        }
    }
    
    // MARK: - Classify Hand Pose
    private func classifyHandPose(_ observation: VNHumanHandPoseObservation) -> GestureType {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
            return .unknown
        }
        
        // Get finger tip points
        let thumbTip = recognizedPoints[.thumbTip]
        let indexTip = recognizedPoints[.indexTip]
        let middleTip = recognizedPoints[.middleTip]
        let ringTip = recognizedPoints[.ringTip]
        let littleTip = recognizedPoints[.littleTip]
        
        // Get finger base points (to determine if finger is extended)
        let thumbIP = recognizedPoints[.thumbIP]
        let indexMCP = recognizedPoints[.indexMCP]
        let middleMCP = recognizedPoints[.middleMCP]
        let ringMCP = recognizedPoints[.ringMCP]
        let littleMCP = recognizedPoints[.littleMCP]
        
        let wrist = recognizedPoints[.wrist]
        
        // Count extended fingers
        var extendedFingers = 0
        
        // Check each finger (compare tip distance from wrist vs base distance from wrist)
        if let thumbT = thumbTip, let thumbB = thumbIP, let w = wrist,
           thumbT.confidence > 0.3 && thumbB.confidence > 0.3 {
            let tipDistance = distance(thumbT.location, w.location)
            let baseDistance = distance(thumbB.location, w.location)
            if tipDistance > baseDistance * 1.2 {
                extendedFingers += 1
            }
        }
        
        if let indexT = indexTip, let indexB = indexMCP, let w = wrist,
           indexT.confidence > 0.3 && indexB.confidence > 0.3 {
            let tipDistance = distance(indexT.location, w.location)
            let baseDistance = distance(indexB.location, w.location)
            if tipDistance > baseDistance * 1.3 {
                extendedFingers += 1
            }
        }
        
        if let middleT = middleTip, let middleB = middleMCP, let w = wrist,
           middleT.confidence > 0.3 && middleB.confidence > 0.3 {
            let tipDistance = distance(middleT.location, w.location)
            let baseDistance = distance(middleB.location, w.location)
            if tipDistance > baseDistance * 1.3 {
                extendedFingers += 1
            }
        }
        
        if let ringT = ringTip, let ringB = ringMCP, let w = wrist,
           ringT.confidence > 0.3 && ringB.confidence > 0.3 {
            let tipDistance = distance(ringT.location, w.location)
            let baseDistance = distance(ringB.location, w.location)
            if tipDistance > baseDistance * 1.3 {
                extendedFingers += 1
            }
        }
        
        if let littleT = littleTip, let littleB = littleMCP, let w = wrist,
           littleT.confidence > 0.3 && littleB.confidence > 0.3 {
            let tipDistance = distance(littleT.location, w.location)
            let baseDistance = distance(littleB.location, w.location)
            if tipDistance > baseDistance * 1.3 {
                extendedFingers += 1
            }
        }
        
        // Classify gesture based on extended fingers
        print("🖐️ Extended fingers: \(extendedFingers)")
        
        switch extendedFingers {
        case 5, 4: // Open palm (allowing some detection error)
            return .openPalm
        case 2: // Peace sign
            return .peaceSign
        case 0, 1: // Fist or almost fist
            return .fist
        default:
            return .unknown
        }
    }
    
    // MARK: - Helper: Calculate Distance
    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
}
