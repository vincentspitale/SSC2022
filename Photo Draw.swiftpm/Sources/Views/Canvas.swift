//
//  Canvas.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/6/22.
//

import CoreGraphics
import Combine
import Foundation
import UIKit
import SwiftUI
import PencilKit

class Canvas: UIViewController, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
    // Make a really large canvas!
    static var canvasSize: CGSize = CGSize(width: 10_000, height: 10_000)
    var state: WindowState
    
    var didScrollToOffset = false
    var cancellables = Set<AnyCancellable>()
    
    // Workaround to get approximate selection
    var selectionGestureRecognizer: UIPanGestureRecognizer?
    var selectMinX: CGFloat?
    var selectMaxX: CGFloat?
    var selectMinY: CGFloat?
    var selectMaxY: CGFloat?
    
    var selectRect: CGRect? {
        guard let selectMinX = selectMinX,
              let selectMaxX = selectMaxX,
              let selectMinY = selectMinY,
              let selectMaxY = selectMaxY else { return nil }
        return CGRect(x: selectMinX, y: selectMinY,
                      width: abs(selectMaxX - selectMinX), height: abs(selectMaxY - selectMinY))
    }
    
    var imageRenderView: ImageRenderView?
    
    let canvasView: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.backgroundColor = .systemGray6
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.zoomScale = 1
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.contentSize = Canvas.canvasSize
        canvas.drawingPolicy = UIPencilInteraction.prefersPencilOnlyDrawing ? .default : .anyInput
        return canvas
    }()
    
    var strokes: [PKStroke] {
        self.canvasView.drawing.strokes
    }
    
    init(state: WindowState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
        state.canvas = self
        canvasView.delegate = self
        let changeToolCancellable = state.$currentTool.sink { [weak self] tool in
            guard let self = self else { return }
            switch tool {
            case .pen:
                self.imageRenderView?.isUserInteractionEnabled = false
                self.canvasView.isUserInteractionEnabled = true
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKInkingTool(.pen, color: state.currentColor.pencilKitColor)
            case .placePhoto:
                self.imageRenderView?.isUserInteractionEnabled = true
                self.canvasView.isUserInteractionEnabled = false
                self.canvasView.drawingGestureRecognizer.isEnabled = false
                self.canvasView.tool = PKInkingTool(.pen, color: state.currentColor.pencilKitColor)
            case .remove:
                self.imageRenderView?.isUserInteractionEnabled = false
                self.canvasView.isUserInteractionEnabled = true
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKEraserTool(.vector)
            case .selection:
                self.imageRenderView?.isUserInteractionEnabled = false
                self.canvasView.isUserInteractionEnabled = true
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKLassoTool()
            case .touch:
                self.imageRenderView?.isUserInteractionEnabled = false
                self.canvasView.isUserInteractionEnabled = true
                self.canvasView.tool = PKInkingTool(.pen, color: state.currentColor.pencilKitColor)
                self.canvasView.drawingGestureRecognizer.isEnabled = false
            }
        }
        cancellables.insert(changeToolCancellable)
        
        let colorCancellable = state.$currentColor.sink { [weak self] color in
            guard let self = self else { return }
            if state.currentTool == .pen {
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKInkingTool(.pen, color: color.pencilKitColor)
            }
        }
        
        cancellables.insert(colorCancellable)
        
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        tapGesture.delegate = self
        self.view.addSubview(canvasView)
        
        let constraints = [
            canvasView.topAnchor.constraint(equalTo: self.view.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
        canvasView.addGestureRecognizer(tapGesture)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        panGesture.delegate = self
        self.view.addGestureRecognizer(panGesture)
        
        let imageRenderView = ImageRenderView(state: state, canvas: canvasView, frame: self.view.bounds)
        imageRenderView.isUserInteractionEnabled = false
        self.imageRenderView = imageRenderView
        imageRenderView.translatesAutoresizingMaskIntoConstraints = false
        let imageViewConstraints = [
            imageRenderView.topAnchor.constraint(equalTo: self.view.topAnchor),
            imageRenderView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            imageRenderView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            imageRenderView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ]
        self.view.addSubview(imageRenderView)
        NSLayoutConstraint.activate(imageViewConstraints)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.scrollToInitialOffsetIfRequired()
    }
    
    private func scrollToInitialOffsetIfRequired() {
        if !didScrollToOffset {
            let offsetX = (canvasView.contentSize.width - canvasView.frame.width) / 2
            let offsetY = (canvasView.contentSize.height - canvasView.frame.height) / 2
            self.canvasView.contentOffset = CGPoint(x: offsetX, y: offsetY)
            didScrollToOffset = true
        }
    }
    
    @objc
    func handlePan(_ sender: UIPanGestureRecognizer) -> Void {
        guard state.currentTool == .selection else {
            self.selectionOver()
            return
        }
        
        let point = sender.location(in: self.canvasView)
        
        switch sender.state {
        case .began:
            self.updateSelectRect(point)
        case .changed:
            self.updateSelectRect(point)
        case .cancelled:
            self.finishSelection()
        case .ended:
            self.finishSelection()
        default:
            break
        }
    }
    
    private func updateSelectRect(_ translatedPoint: CGPoint) {
        guard let selectMinX = selectMinX,
              let selectMaxX = selectMaxX,
              let selectMinY = selectMinY,
              let selectMaxY = selectMaxY else {
            selectMinX = translatedPoint.x
            selectMaxX = translatedPoint.x
            selectMinY = translatedPoint.y
            selectMaxY = translatedPoint.y
            return
        }
        self.selectMinX = min(selectMinX, translatedPoint.x)
        self.selectMaxX = max(selectMaxX, translatedPoint.x)
        self.selectMinY = min(selectMinY, translatedPoint.y)
        self.selectMaxY = max(selectMaxY, translatedPoint.y)
    }
    
    @objc
    func handleTap(_ sender: UITapGestureRecognizer) -> Void {
        if sender.state == .ended {
            withAnimation{ self.state.isShowingPenColorPicker = false }
            withAnimation{ self.state.selection = nil }
        }
    }
    
    /// Find where the center of the screen is in canvas space
    func getCenterScreenCanvasPosition() async -> CGPoint {
        let contentOffset = self.canvasView.contentOffset
        return CGPoint(x: contentOffset.x + (self.view.bounds.width / 2),
                       y: contentOffset.y + (self.view.bounds.height / 2))
    }
    
    
    // Update selection
    private func finishSelection() {
        if state.currentTool == .selection {
            if let selectRect = self.selectRect {
                var selection = Set<Int>()
                for (index, path) in self.canvasView.drawing.strokes.enumerated() {
                    if selectRect.intersects(path.renderBounds) {
                        selection.insert(index)
                    }
                }
                if !selection.isEmpty {
                    withAnimation{ self.state.selection = selection }
                }
                self.selectionOver()
            }
        }
    }
    
    private func selectionOver() {
        self.selectMinX = nil
        self.selectMaxX = nil
        self.selectMinY = nil
        self.selectMaxY = nil
    }
    
    func addStrokes(_ strokes: [PKStroke]) {
        self.canvasView.drawing.strokes.append(contentsOf: strokes)
    }
    
    func updateStrokes(_ strokes: [(Int, PKStroke)]) {
        var indexToStroke = [Int : PKStroke]()
        for (index, stroke) in strokes {
            indexToStroke[index] = stroke
        }
        
        var newStrokes = self.canvasView.drawing.strokes
        for index in newStrokes.indices {
            if let stroke = indexToStroke[index] {
                newStrokes[index] = stroke
            }
        }
        self.canvasView.drawing.strokes = newStrokes
        
    }
    
    func removeStrokes(_ strokes: Set<Int>) {
        self.canvasView.drawing.strokes = self.canvasView.drawing.strokes.enumerated().filter { index, stroke in
            !strokes.contains(index)
        }.map { _, stroke in
            return stroke
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
}

class ImageRenderView: UIView, UIGestureRecognizerDelegate {
    private var state: WindowState
    // Place photo image resizing
    private var imageScale: CGAffineTransform = .identity
    private var imageTranslation: CGAffineTransform = .identity
    
    var pinchGesture: UIPinchGestureRecognizer?
    var panGesture: UIPanGestureRecognizer?
    private var cancellables = Set<AnyCancellable>()
    private var canvasView: PKCanvasView
    
    init(state: WindowState, canvas: PKCanvasView, frame: CGRect) {
        self.state = state
        self.canvasView = canvas
        super.init(frame: frame)
        self.backgroundColor = .clear
        
        // If the current tool changes, update the number of touches required
        // to trigger the pan gesture to allow the tools to be used
        let toolChange = state.$currentTool.sink(receiveValue: { [weak self] tool in
            if tool == .touch || tool == .placePhoto {
                self?.panGesture?.isEnabled = true
            } else {
                self?.panGesture?.isEnabled = false
            }
        })
        
        let stateChange = state.objectWillChange.sink(receiveValue: { [weak self] _ in
            self?.setNeedsDisplay()
        })
        
        self.cancellables.insert(toolChange)
        self.cancellables.insert(stateChange)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        
        self.pinchGesture = pinch
        self.addGestureRecognizer(pinch)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.allowedScrollTypesMask = [.all]
        self.panGesture = pan
        self.addGestureRecognizer(pan)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    func handlePinch(_ sender: UIPinchGestureRecognizer) -> Void {
        // Scale the image that is being converted
        let transform = CGAffineTransform(scaleX: sender.scale, y: sender.scale)
        let updateScale = {
            switch self.state.currentTool {
            case .placePhoto:
                self.imageScale = transform
            default:
                break
            }
        }
        
        let applyScale = {
            switch self.state.currentTool {
            case .placePhoto:
                self.imageScale = .identity
                self.state.imageConversion?.applyScale(transform: transform)
            default:
                break
            }
        }
        
        switch sender.state {
        case .began:
            updateScale()
        case .changed:
            updateScale()
        case .cancelled:
            applyScale()
        case .ended:
            applyScale()
        default:
            break
        }
        self.setNeedsDisplay()
    }
    
    @objc
    func handlePan(_ sender: UIPanGestureRecognizer) -> Void {
        // Scale the image that is being converted
        let point = sender.translation(in: self)
        
        let translation = CGAffineTransform.init(translationX: point.x, y: point.y)
        let updatePan = {
            let currentTool = self.state.currentTool
            if currentTool == .placePhoto {
                self.imageTranslation = translation
            }
        }
        
        let applyPan = {
            let currentTool = self.state.currentTool
            if currentTool == .placePhoto {
                self.finishPhotoTranslate(translation)
            }
        }
        
        switch sender.state {
        case .began:
            updatePan()
        case .changed:
            updatePan()
        case .cancelled:
            applyPan()
        case .ended:
            applyPan()
        default:
            break
        }
        self.setNeedsDisplay()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
    private func finishPhotoTranslate(_ translation: CGAffineTransform) {
        self.state.imageConversion?.applyTranslate(transform: translation)
        self.imageTranslation = .identity
    }
    
    override func draw(_ rect: CGRect) {
        // Convert screen rect to canvas space
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw the image that's being placed
        if let imageConversion = state.imageConversion {
            let size = imageConversion.image.size
            // Find the correct position in this view's space
            var rect: CGRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            rect = rect.applying(imageConversion.scaleTransform)
            rect = rect.applying(imageScale)
            rect = rect.applying(imageConversion.translateTransform)
            rect = rect.applying(imageTranslation)
            rect = rect.applying(.init(translationX: -canvasView.contentOffset.x, y: -canvasView.contentOffset.y))
            // The image needs to be flipped vertically
            context.saveGState()
            context.translateBy(x: 0, y: rect.origin.y + rect.height)
            context.scaleBy(x: 1, y: -1)
            if let cgImage = imageConversion.image.cgImage {
                context.draw(cgImage, in: CGRect(origin: CGPoint(x: rect.origin.x, y: 0), size: rect.size))
            }
            context.restoreGState()
        }
        
    }
    
}

struct CanvasView: UIViewControllerRepresentable {
    @ObservedObject var windowState: WindowState
    
    func makeUIViewController(context: Context) -> UIViewController {
        Canvas(state: windowState)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        
    }
}
