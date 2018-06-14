//
//  ViewController.swift
//  baseCoreMl
//
//  Created by christophe milliere on 11/06/2018.
//  Copyright © 2018 christophe milliere. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var buttonRotation: UIButton!
    @IBOutlet weak var segment: UISegmentedControl!
    
    let mediaType = AVMediaType.video
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var position = AVCaptureDevice.Position.back
    var shapeLayers = [CAShapeLayer]()
    var shapeLayer = CAShapeLayer()
    var moustaches = [CALayer]()
    var isMoustache = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //verify auhtorize
        verifyAuhtorize()
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        shapeLayer.frame = cameraView.bounds
        shapeLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: -1))
        view.layer.addSublayer(shapeLayer)
    }

    func verifyAuhtorize() {
        let authorize = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch authorize {
        case .authorized: setupCamera()
        case .denied: print("L'utilisateur a refuser")
        case .restricted: print("l'utilisateur de la camera est restreint")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { (success) in
                DispatchQueue.main.async {
                    self.verifyAuhtorize()
                }
            }
        }
    }
    
    func setupCamera(){
        previewLayer?.removeFromSuperlayer()
        session = AVCaptureSession()
        guard session != nil else { return }
        guard let devicePhoto = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: mediaType, position: position) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: devicePhoto)
            if session!.canAddInput(input) {
                session!.addInput(input)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            output.alwaysDiscardsLateVideoFrames = true
            if session!.canAddOutput(output) {
                session!.addOutput(output)
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: session!)
            previewLayer?.frame = cameraView.bounds
            previewLayer?.connection?.videoOrientation = .portrait
            previewLayer?.videoGravity = .resizeAspect
            
            guard previewLayer != nil else { return }
            cameraView.layer.addSublayer(previewLayer!)
            
            let queue = DispatchQueue(label: "videoQueue")
            output.setSampleBufferDelegate(self, queue: queue)
            session!.startRunning()
        }catch {
            print(error.localizedDescription)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let copy = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate) else { return }
        let ciImage = CIImage(cvImageBuffer: pixel, options: copy as? [String: Any])
        if position == .front{
            self.choicieAction(ciImage: ciImage.oriented(forExifOrientation: Int32(UIImageOrientation.leftMirrored.rawValue)))
            //image using with vision
        } else {
            self.choicieAction(ciImage: ciImage.oriented(forExifOrientation: Int32(UIImageOrientation.downMirrored.rawValue)))
        }
    }
    
    func choicieAction(ciImage: CIImage) {
        DispatchQueue.main.sync {
            switch self.segment.selectedSegmentIndex {
            case 0: self.detectFace(ciImage)
            case 1:
                self.isMoustache = false
                self.dectectElement(ciImage)
            case 2:
                self.isMoustache = true
                self.dectectElement(ciImage)
            default: break
            }
        }
    }
    
    @IBAction func actionRotation(_ sender: Any) {
        session!.stopRunning()
        switch position {
        case .back: position = .front
        case .front: position = .back
        case .unspecified: position = .back
        }
        verifyAuhtorize()
    }
}

