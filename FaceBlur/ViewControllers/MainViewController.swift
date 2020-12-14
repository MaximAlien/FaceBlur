//
//  MainViewController.swift
//  FaceBlur
//
//  Created by Maxim Makhun on 1/15/18.
//  Copyright © 2018 Maxim Makhun. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

final class MainViewController: UIViewController {
    
    let captureSession = AVCaptureSession()
    let faceLandmarksRequest = VNDetectFaceLandmarksRequest()
    let faceLandmarksDetectionHandler = VNSequenceRequestHandler()
    lazy var videoPreviewLayer: AVCaptureVideoPreviewLayer = {
        var previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        
        return previewLayer
    }()
    let landmarksLayer = CAShapeLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        videoPreviewLayer.frame = view.bounds
        landmarksLayer.frame = view.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        view.layer.addSublayer(videoPreviewLayer)
        view.layer.addSublayer(landmarksLayer)
    }
    
    func startSession() {
        guard let captureDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera,
                                                          for: AVMediaType.video,
                                                          position: .front) else { return }
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.beginConfiguration()
            
            if captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            
            output.alwaysDiscardsLateVideoFrames = true
            
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }
            
            captureSession.commitConfiguration()
            let queue = DispatchQueue(label: "output.queue")
            output.setSampleBufferDelegate(self, queue: queue)
            
            captureSession.startRunning()
        } catch {
            NSLog("Failed to setup AVCaptureSession with error: \(error.localizedDescription).")
        }
    }
    
    // MARK: - Face landmarks detection methods
    
    func detectLandmarks(_ image: CIImage) {
        do {
            DispatchQueue.main.async {
                self.landmarksLayer.sublayers?.removeAll()
            }
            
            try faceLandmarksDetectionHandler.perform([faceLandmarksRequest], on: image)
            
            guard let results = faceLandmarksRequest.results as? [VNFaceObservation], !results.isEmpty else { return }
            
            for result in results {
                NSLog("Result: \(result)")
                
                DispatchQueue.main.async {
                    let size = CGSize(width: result.boundingBox.width * self.view.bounds.width,
                                      height: result.boundingBox.height * self.view.bounds.height)
                    let origin = CGPoint(x: result.boundingBox.minX * self.view.bounds.width,
                                         y: (1 - result.boundingBox.minY) * self.view.bounds.height - size.height)
                    
                    let layer = CAShapeLayer()
                    layer.frame = CGRect(origin: origin, size: size)
                    layer.borderColor = UIColor.red.cgColor
                    layer.borderWidth = 2
                    
                    self.landmarksLayer.addSublayer(layer)
                }
            }
        } catch {
            NSLog("Failed to perform face landmarks request with error: \(error.localizedDescription).")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate methods

extension MainViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func imageOptions(_ attachments: [String: Any]?) -> [CIImageOption: Any]? {
        guard let attachments = attachments else { return nil }
        return Dictionary(uniqueKeysWithValues: attachments.map({ key, value in (CIImageOption(rawValue: key), value) }))
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault,
                                                        target: sampleBuffer,
                                                        attachmentMode: kCMAttachmentMode_ShouldPropagate)
        let image = CIImage(cvImageBuffer: pixelBuffer!, options: imageOptions(attachments as! [String : Any]?))
        
        detectLandmarks(image.oriented(.leftMirrored))
    }
}
