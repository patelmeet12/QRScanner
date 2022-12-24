//
//  QRScannerVC.swift
//  QRScanner
//
//  Created by Meet Patel on 24/12/22.
//

import UIKit
import AVFoundation
import SafariServices

class QRScannerVC: UIViewController {
    
    //MARK:  Outlets and Variable Declarations
    @IBOutlet weak var viewCamera: UIView!
    
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var capturePhotoOutput: AVCapturePhotoOutput?
    var qrCodeFrameView: UIView?
    
    //MARK: 
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initialSetup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    override func viewDidLayoutSubviews() {
        videoPreviewLayer?.frame = viewCamera.bounds
        if let previewLayer = videoPreviewLayer ,(previewLayer.connection?.isVideoOrientationSupported)! {
            previewLayer.connection?.videoOrientation = UIApplication.shared.statusBarOrientation.videoOrientation ?? .portrait
        }
    }
    
    //MARK:  Buttons Clicked Action
    
    //MARK:  Functions
    private func initialSetup() {
        
        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video as the media type parameter
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            self.showAlertWithOkButton(message: "Unable to access back camera!")
            return
        }
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous deivce object
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Initialize the captureSession object
            captureSession = AVCaptureSession()
            
            // Set the input devcie on the capture session
            captureSession?.addInput(input)
            
            // Get an instance of ACCapturePhotoOutput class
            capturePhotoOutput = AVCapturePhotoOutput()
            capturePhotoOutput?.isHighResolutionCaptureEnabled = true
            
            // Set the output on the capture session
            captureSession?.addOutput(capturePhotoOutput!)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the input device
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)
            
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            
            //Initialise the video preview layer and add it as a sublayer to the viewPreview view's layer
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            //videoPreviewLayer?.frame = view.layer.bounds
            viewCamera.layer.addSublayer(videoPreviewLayer!)
            
            //start video capture
            captureSession?.startRunning()
            
            //Initialize QR Code Frame to highlight the QR code
            qrCodeFrameView = UIView()
            
            if let qrCodeFrameView = qrCodeFrameView {
                
                qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                qrCodeFrameView.layer.borderWidth = 2
                view.addSubview(qrCodeFrameView)
                view.bringSubviewToFront(qrCodeFrameView)
            }
        } catch {
            //If any error occurs, simply print it out
            print(error)
            return
        }
    }
}

//MARK:  AVCapturePhotoCaptureDelegate Methods
extension QRScannerVC: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Fail to capture photo: \(String(describing: error))")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            print("Fail to convert pixel buffer")
            return
        }

        guard let capturedImage = UIImage.init(data: imageData , scale: 1.0) else {
            print("Fail to convert image data to UIImage")
            return
        }

        let width = capturedImage.size.width
        let height = capturedImage.size.height
        let origin = CGPoint(x: (width - height)/2, y: (height - height)/2)
        let size = CGSize(width: height, height: height)

        guard let imageRef = capturedImage.cgImage?.cropping(to: CGRect(origin: origin, size: size)) else {
            print("Fail to crop image")
            return
        }

        let imageToSave = UIImage(cgImage: imageRef, scale: 1.0, orientation: .down)
        UIImageWriteToSavedPhotosAlbum(imageToSave, nil, nil, nil)
    }
}

//MARK:  AVCaptureMetadataOutputObjectsDelegate
extension QRScannerVC: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            
            qrCodeFrameView?.frame = CGRect.zero
            self.showAlertWithOkButton(message: "No QR code is detected")
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            self.captureSession?.stopRunning()
            // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                
                self.showAlertWithTwoButtons(message: metadataObj.stringValue ?? "", btn1Name: "Copy", btn2Name: "Search Web") { btnClickedIndex in
                    if btnClickedIndex == 1 {
                        
                        UIPasteboard.general.string = metadataObj.stringValue ?? ""
                        self.captureSession?.startRunning()
                    } else if btnClickedIndex == 2 {
                        
                        if let url = URL(string: "https://www.google.com/search?q=\(metadataObj.stringValue ?? "")") {
                            
                            let vc = SFSafariViewController(url: url)
                            self.present(vc, animated: true, completion: nil)
                            self.captureSession?.startRunning()
                        }
                    }
                }
                //self.showAlertWithOkButton(message: metadataObj.stringValue ?? "")
            }
        }
    }
}

//MARK:  UIInterfaceOrientation
extension UIInterfaceOrientation {
    
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeRight: return .landscapeRight
        case .landscapeLeft: return .landscapeLeft
        case .portrait: return .portrait
        default: return nil
        }
    }
}
