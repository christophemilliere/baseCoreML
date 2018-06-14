//
//  ExtensionVision.swift
//  baseCoreMl
//
//  Created by christophe milliere on 13/06/2018.
//  Copyright © 2018 christophe milliere. All rights reserved.
//

import UIKit
import Vision

extension ViewController {
    
    func deleteOldFrames(){
        for s in shapeLayers {
            s.removeFromSuperlayer()
        }
        
        for m in moustaches {
            m.removeFromSuperlayer()
        }
        shapeLayers.removeAll()
        moustaches.removeAll()
        shapeLayer.sublayers?.removeAll()
    }
    
    func detectFace(_ ciImage: CIImage){
        let req = VNDetectFaceRectanglesRequest(completionHandler: completionDetect)
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([req])
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func completionDetect(_ req: VNRequest, _ error: Error?){
        guard let resultats = req.results as? [VNFaceObservation], resultats.count > 0  else { return }
        //delete old detect face
        deleteOldFrames()
        
        for result in resultats {
            //add new frames
            DispatchQueue.main.async {
                let myRect = result.boundingBox.scaling(from: self.cameraView.bounds)
                let path = UIBezierPath(rect: myRect)
                let layer = CAShapeLayer()
                layer.strokeColor = UIColor.red.cgColor
                layer.lineWidth = 1
                layer.fillColor = UIColor.clear.cgColor
                layer.path = path.cgPath
                self.shapeLayers.append(layer)
                self.cameraView.layer.addSublayer(layer)
            }
        }
        
    }
    
    func dectectElement(_ ciImage: CIImage){
        let req = VNDetectFaceLandmarksRequest(completionHandler: completionDetectelement)
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([req])
        } catch  {
            print(error.localizedDescription)
        }
    }
    
    func completionDetectelement(_ req: VNRequest, error: Error?){
        if let resultats = req.results as? [VNFaceObservation], resultats.count > 0 {
            DispatchQueue.main.async {
                let resultatsSort = resultats.sorted(by: {$0.boundingBox.minX > $1.boundingBox.minX})
                if self.isMoustache {
                    if self.moustaches.count > 0 {
                        for x in (0...self.moustaches.count - 1) {
                            if x > resultatsSort.count, self.moustaches.count > x {
                                let moustache = self.moustaches[x]
                                moustache.removeFromSuperlayer()
                                self.moustaches.remove(at: x)
                            }
                        }
                    }
                } else {
                    self.deleteOldFrames()
                }
                
                for observer in resultatsSort {
                    let rectScalling = observer.boundingBox.scalingElement(from: self.view.bounds.size)
                    if !self.isMoustache{
                        self.convertLandmarkShape(observer.landmarks?.faceContour, rectScalling)
                        self.convertLandmarkShape(observer.landmarks?.nose, rectScalling)
                        self.convertLandmarkShape(observer.landmarks?.innerLips, rectScalling)
                        self.convertLandmarkShape(observer.landmarks?.outerLips, rectScalling)
                        self.convertLandmarkShape(observer.landmarks?.leftEye, rectScalling)
                        self.convertLandmarkShape(observer.landmarks?.rightEye, rectScalling)
                        self.convertLandmarkShape(observer.landmarks?.leftEyebrow, rectScalling)
                        self.convertLandmarkShape(observer.landmarks?.rightEyebrow, rectScalling)
                    } else {
                        if let nose = observer.landmarks?.nose, let index = resultatsSort.index(of: observer){
                            let points = self.convertPoint(points: nose.normalizedPoints,  rectScalling)
                            var minX = points[0].x
                            var maxX = points[0].x
                            var minY = points[0].y
                            var maxY = points[0].y
                            for point in points {
                                if point.x > maxX {
                                    maxX = point.x
                                }
                                if point.x < minX {
                                    minX = point.x
                                }
                                
                                if point.y > maxY {
                                    maxY = point.y
                                }
                                if point.y < minY {
                                    minY = point.y
                                }
                                let width = (maxX - minX) * 3
                                let middle = (maxX + minX) / 2
                                let height = width / 2
                                
                                if self.moustaches.count <= index {
                                    let moustache = CALayer()
                                    moustache.backgroundColor = UIColor.clear.cgColor
                                    moustache.frame = CGRect(x: 0, y: 0, width: width, height: height)
                                    moustache.position = CGPoint(x: middle, y: minY - (height / 8))
                                    moustache.contents = #imageLiteral(resourceName: "moustache").cgImage
                                    self.moustaches.append(moustache)
                                    self.shapeLayer.addSublayer(moustache)
                                } else {
                                    let moustache = self.moustaches[index]
                                    moustache.frame = CGRect(x: 0, y: 0, width: width, height: height)
                                    moustache.position = CGPoint(x: middle, y: minY - (width / 8))
                                }
                            }
                        }
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.deleteOldFrames()
            }
        }
    }
    
    func convertLandmarkShape(_ landmark: VNFaceLandmarkRegion2D?, _ boundinBox: CGRect){
        guard let points = landmark?.normalizedPoints else { return }
        let pointsConvert = convertPoint(points: points, boundinBox)
        guard pointsConvert.count > 0 else { return }
        DispatchQueue.main.async {
            let newLayer = CAShapeLayer()
            newLayer.strokeColor = UIColor.blue.cgColor
            newLayer.lineWidth = 1
            let path = UIBezierPath()
            path.move(to: pointsConvert[0])
            for point in pointsConvert {
                path.addLine(to: point)
                path.move(to: point)
            }
            path.addLine(to: pointsConvert[0])
            newLayer.path = path.cgPath
            self.shapeLayer.addSublayer(newLayer)
            
        }
        
    }
    
    func convertPoint(points: [CGPoint], _ boundingBox: CGRect) ->[CGPoint] {
        var newPoints = [CGPoint]()
        for point in points {
            let pointX = point.x * boundingBox.width + boundingBox.origin.x
            let pointY = point.y * boundingBox.height + boundingBox.origin.y
            let new = CGPoint(x: pointX, y: pointY)
            newPoints.append(new)
        }
        
        return newPoints
    }
}

extension CGRect {
    func scaling(from: CGRect) -> CGRect{
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: from.width, y: -from.height)
        let translate = CGAffineTransform.identity.scaledBy(x: -from.width, y: from.height)
        
        return self.applying(translate).applying(transform)
    }
    
    func scalingElement(from: CGSize) -> CGRect{
        let x = self.origin.x * from.width
        let y = self.origin.y * from.height
        let width = self.size.width * from.width
        let height = self.size.height * from.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
