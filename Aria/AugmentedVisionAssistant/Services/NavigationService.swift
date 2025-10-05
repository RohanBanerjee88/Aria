//
//  NavigationService.swift
//  Aria
//
//  Created by Rohan Banerjee on 10/4/25.
//

import Foundation
import CoreLocation
import Combine

// Navigation step structure
struct NavigationStep {
    let instruction: String
    let distance: String
    let duration: String
    let maneuver: String?
}

class NavigationService: NSObject, ObservableObject {
    @Published var isNavigating = false
    @Published var currentStepIndex = 0
    @Published var navigationSteps: [NavigationStep] = []
    @Published var destination: String = ""
    
    private let locationManager = CLLocationManager()
    private var userLocation: CLLocation?
    
    override init() {
        super.init()
        setupLocationManager()
        // Start location updates immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startLocationUpdates()
        }
    }
    
    // MARK: - Location Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Get Directions
    func getDirections(to destination: String) async throws -> [NavigationStep] {
        // Wait for location if not available yet
        if userLocation == nil {
            print("⏳ Waiting for location...")
            try await waitForLocation()
        }
        
        guard let currentLocation = userLocation else {
            throw NavigationError.noLocation
        }
        
        // Build URL
        guard var urlComponents = URLComponents(string: Constants.googleDirectionsEndpoint) else {
            throw NavigationError.invalidURL
        }
        
        let origin = "\(currentLocation.coordinate.latitude),\(currentLocation.coordinate.longitude)"
        
        urlComponents.queryItems = [
            URLQueryItem(name: "origin", value: origin),
            URLQueryItem(name: "destination", value: destination),
            URLQueryItem(name: "mode", value: "walking"),
            URLQueryItem(name: "key", value: Constants.googleMapsAPIKey)
        ]
        
        guard let url = urlComponents.url else {
            throw NavigationError.invalidURL
        }
        
        print("📍 Requesting directions from \(origin) to \(destination)")
        print("🔗 URL: \(url.absoluteString)")
        
        // Make API call
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                print("❌ HTTP Status: \(httpResponse.statusCode)")
            }
            throw NavigationError.apiError
        }
        
        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Print full response for debugging
        if let jsonData = try? JSONSerialization.data(withJSONObject: json ?? [:], options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📦 API Response: \(jsonString.prefix(500))...")
        }
        
        guard let status = json?["status"] as? String else {
            throw NavigationError.parsingFailed
        }
        
        print("📊 Google Maps Status: \(status)")
        
        if status != "OK" {
            // Print error message if available
            if let errorMessage = json?["error_message"] as? String {
                print("❌ Google Maps Error: \(errorMessage)")
            }
            
            switch status {
            case "ZERO_RESULTS":
                throw NavigationError.noRouteFound
            case "REQUEST_DENIED":
                throw NavigationError.apiKeyInvalid
            case "INVALID_REQUEST":
                throw NavigationError.invalidRequest
            default:
                throw NavigationError.apiError
            }
        }
        
        guard let routes = json?["routes"] as? [[String: Any]],
              let firstRoute = routes.first,
              let legs = firstRoute["legs"] as? [[String: Any]],
              let firstLeg = legs.first,
              let steps = firstLeg["steps"] as? [[String: Any]] else {
            throw NavigationError.parsingFailed
        }
        
        // Parse steps
        var navigationSteps: [NavigationStep] = []
        
        for step in steps {
            guard let htmlInstruction = step["html_instructions"] as? String,
                  let distance = step["distance"] as? [String: Any],
                  let duration = step["duration"] as? [String: Any],
                  let distanceText = distance["text"] as? String,
                  let durationText = duration["text"] as? String else {
                continue
            }
            
            // Clean HTML from instructions
            let instruction = htmlInstruction.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            
            let maneuver = step["maneuver"] as? String
            
            let navStep = NavigationStep(
                instruction: instruction,
                distance: distanceText,
                duration: durationText,
                maneuver: maneuver
            )
            
            navigationSteps.append(navStep)
        }
        
        print("✅ Got \(navigationSteps.count) navigation steps")
        return navigationSteps
    }
    
    // MARK: - Wait for Location
    private func waitForLocation() async throws {
        // Wait up to 10 seconds for location
        for _ in 0..<20 {
            if userLocation != nil {
                return
            }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        throw NavigationError.noLocation
    }
    
    // MARK: - Start Navigation
    func startNavigation(to destination: String) async throws {
        self.destination = destination
        
        let steps = try await getDirections(to: destination)
        
        await MainActor.run {
            self.navigationSteps = steps
            self.currentStepIndex = 0
            self.isNavigating = true
        }
        
        startLocationUpdates()
    }
    
    // MARK: - Get Current Instruction
    func getCurrentInstruction() -> String? {
        guard isNavigating,
              currentStepIndex < navigationSteps.count else {
            return nil
        }
        
        let step = navigationSteps[currentStepIndex]
        return "\(step.instruction). In \(step.distance)."
    }
    
    // MARK: - Next Step
    func nextStep() {
        guard currentStepIndex < navigationSteps.count - 1 else {
            // Reached destination
            stopNavigation()
            return
        }
        
        currentStepIndex += 1
    }
    
    // MARK: - Stop Navigation
    func stopNavigation() {
        isNavigating = false
        currentStepIndex = 0
        navigationSteps = []
        destination = ""
        stopLocationUpdates()
    }
}

// MARK: - Location Manager Delegate
extension NavigationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location authorized")
            startLocationUpdates()
        case .denied, .restricted:
            print("❌ Location denied")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - Error Types
enum NavigationError: LocalizedError {
    case noLocation
    case invalidURL
    case apiError
    case parsingFailed
    case noRouteFound
    case apiKeyInvalid
    case invalidRequest
    
    var errorDescription: String? {
        switch self {
        case .noLocation:
            return "Unable to get current location. Please allow location access."
        case .invalidURL:
            return "Invalid Google Maps URL"
        case .apiError:
            return "Google Maps API error"
        case .parsingFailed:
            return "Failed to parse directions"
        case .noRouteFound:
            return "No route found to destination. Try a different search."
        case .apiKeyInvalid:
            return "Google Maps API key is invalid or doesn't have required permissions"
        case .invalidRequest:
            return "Invalid destination. Please try a different search."
        }
    }
}
