//
//  CameraScan.swift
//  
//
//  Created by Vincent Spitale on 4/22/22.
//

import Foundation
import Combine
import VisionKit
import SwiftUI

struct CameraScanView: UIViewControllerRepresentable {
    typealias UIViewControllerType = CameraScan
    @ObservedObject var windowState: WindowState
    
    func makeUIViewController(context: Context) -> CameraScan {
        CameraScan(windowState: windowState)
    }
    
    func updateUIViewController(_ uiViewController: CameraScan, context: Context) {
        
    }
    
}

class CameraScan: UIViewController, VNDocumentCameraViewControllerDelegate {
    var state: WindowState
    var cancellable: AnyCancellable? = nil
    var documentScanner: VNDocumentCameraViewController? = nil
    
    init(windowState: WindowState) {
        self.state = windowState
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cancellable = state.$photoMode.sink(receiveValue: { [weak self] mode in
            guard let self = self else { return }
            if mode == .cameraScan  {
                let documentViewController = VNDocumentCameraViewController()
                documentViewController.delegate = self
                self.documentScanner = documentViewController
                self.present(documentViewController, animated: true)
            } else {
                self.documentScanner?.dismiss(animated: true)
            }
        })
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        if scan.pageCount > 0 {
            let image = scan.imageOfPage(at: 0)
            Task { @MainActor in
                await self.state.startConversion(image: image)
            }
        }
        documentScanner?.dismiss(animated: true)
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        documentScanner?.dismiss(animated: true)
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        documentScanner?.dismiss(animated: true)
    }
    
}
