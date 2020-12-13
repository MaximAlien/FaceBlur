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
    
    let faceRectanglesRequest = VNDetectFaceRectanglesRequest()
    let faceRectanglesDetectionHandler = VNSequenceRequestHandler()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        var previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        
        return previewLayer
    }()
    
    let captureDevice: AVCaptureDevice? = {
        return AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewLayer.frame = view.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        view.layer.addSublayer(previewLayer)
    }
    
    func startSession() {
        guard let captureDevice = captureDevice else { return }
        
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
        
        detectFace(image.oriented(.leftMirrored))
    }
}

// MARK: - Face detection methods

extension MainViewController {
    
    func detectFace(_ image: CIImage) {
        do {
            try faceRectanglesDetectionHandler.perform([faceRectanglesRequest], on: image)
            
            if let results = faceRectanglesRequest.results as? [VNFaceObservation], !results.isEmpty {
                faceLandmarksRequest.inputFaceObservations = results
                detectLandmarks(image)
            }
        } catch {
            NSLog("Failed to perform face rectangles request with error: \(error.localizedDescription).")
        }
    }
    
    func detectLandmarks(_ image: CIImage) {
        do {
            try faceLandmarksDetectionHandler.perform([faceLandmarksRequest], on: image)
            
            if let results = faceLandmarksRequest.results as? [VNFaceObservation], !results.isEmpty {
                for result in results {
                    NSLog("Result: \(result)")
                }
            }
        } catch {
            NSLog("Failed to perform face landmarks request with error: \(error.localizedDescription).")
        }
    }
}
