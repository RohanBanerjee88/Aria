//
//  CameraService.swift
//  Aria
//
//  Created by Rohan Banerjee on 10/4/25.
//
import AVFoundation
import UIKit
import Combine

class CameraService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var currentFrame: UIImage?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    override init() {
        super.init()
        checkAuthorization()
    }
    
    // MARK: - Authorization
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
            setupCamera()
        case .notDetermined:
            requestAccess()
        default:
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        }
    }
    
    private func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.setupCamera()
                }
            }
        }
    }
    
    // MARK: - Camera Setup
    func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high
            
            // Add camera input
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.captureSession.canAddInput(input) else {
                print("❌ Failed to add camera input")
                self.captureSession.commitConfiguration()
                return
            }
            
            self.captureSession.addInput(input)
            
            // Add video output
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output.queue"))
            self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }
            
            self.captureSession.commitConfiguration()
            
            // Create preview layer on main thread
            DispatchQueue.main.async {
                let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
                preview.videoGravity = .resizeAspectFill
                self.previewLayer = preview
                print("✅ Camera setup complete")
            }
        }
    }
    
    // MARK: - Session Control
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            print("✅ Camera session started")
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            print("⏸️ Camera session stopped")
        }
    }
    
    // MARK: - Frame Capture for Gemini API
    func captureCurrentFrame() -> UIImage? {
        return currentFrame
    }
}

// MARK: - Video Output Delegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let uiImage = UIImage(cgImage: cgImage)
        
        // Update on main thread
        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = uiImage
        }
    }
}
