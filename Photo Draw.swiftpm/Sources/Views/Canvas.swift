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
    static var canvasSize: CGSize = CGSize(width: 10_000, height: 10_000)
    var state: WindowState
    
    var didScrollToOffset = false
    var cancellables = Set<AnyCancellable>()
    
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
    
    init(state: WindowState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
        state.canvas = self
        canvasView.delegate = self
        let changeToolCancellable = state.$currentTool.sink { [weak self] tool in
            guard let self = self else { return }
            switch tool {
            case .pen:
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKInkingTool(.pen, color: state.currentColor.pencilKitColor)
            case .placePhoto:
                self.canvasView.drawingGestureRecognizer.isEnabled = false
                self.canvasView.tool = PKInkingTool(.pen, color: state.currentColor.pencilKitColor)
            case .remove:
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKEraserTool(.vector)
            case .selection:
                self.canvasView.drawingGestureRecognizer.isEnabled = true
                self.canvasView.tool = PKLassoTool()
            case .touch:
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
        
        self.view.addSubview(canvasView)
        
        let constraints = [
            canvasView.topAnchor.constraint(equalTo: self.view.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
        
        
        canvasView.addGestureRecognizer(tapGesture)
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
    func handleTap(_ sender: UITapGestureRecognizer) -> Void {
        if sender.state == .ended {
            withAnimation{ self.state.isShowingPenColorPicker = false }
            withAnimation{ self.state.selection = nil }
        }
    }
    
    /// Find where the center of the screen is in canvas space
    func getCenterScreenCanvasPosition() async -> CGPoint {
        let screen = await MainActor.run { () -> CGRect in
            return self.view.bounds
        }
        let canvas = await MainActor.run { () -> CGRect in
            return self.canvasView.bounds ?? CGRect.zero
        }
        let centerScreen = CGPoint(x: canvas.width / 2, y: screen.height / 2)
        //guard let transform = self.canvasView?.canvasTransform else { return CGPoint(x: 0, y: 0)}
        //return centerScreen.applying(transform.inverted())
        return CGPoint(x: 0, y: 0)
    }
    
    
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        if state.currentTool == .selection {
            if let selectRect = self.selectRect {
                
            }
        }
    }
}

/*
class RenderView: UIView, UIGestureRecognizerDelegate {
    private var state: WindowState
    
    // Move canvas
    var canvasTransform: CGAffineTransform = .identity
    
    private var canvasTranslation: CGAffineTransform = .identity
    
    // Move selected paths
    private var selectTranslateStart: CGPoint?
    private var selectTranslateEnd: CGPoint?
    
    private var selectTranslation: CGAffineTransform? {
        guard let translateStart = selectTranslateStart, let translateEnd = selectTranslateEnd else {
            return nil
        }
        return CGAffineTransform.identity.translatedBy(x: translateEnd.x - translateStart.x, y: translateEnd.y - translateStart.y)
    }
    
    // Path that is currently being drawn
    private var currentPath: (dataPoints: [CGPoint], path: PhotoDrawPath)? = nil
    
    private var removePoint: CGPoint? = nil
    private var removePathPoints: [CGPoint]? = nil
    private var pathsToBeDeleted = Set<UUID>()
    
    private var cancellables = Set<AnyCancellable>()
    
    // Create a path selection
    private var selectStart: CGPoint?
    private var selectEnd: CGPoint?
    private var selectRect: CGRect? {
        guard let selectStart = selectStart, let selectEnd = selectEnd else {
            return nil
        }
        return CGRect(x: min(selectStart.x, selectEnd.x), y: min(selectStart.y, selectEnd.y),
                      width: abs(selectStart.x - selectEnd.x), height: abs(selectStart.y - selectEnd.y))
    }
    
    // Place photo image resizing
    private var imageScale: CGAffineTransform = .identity
    
    private var imageTranslation: CGAffineTransform = .identity
    
    var pinchGesture: UIPinchGestureRecognizer?
    var panGesture: UIPanGestureRecognizer?
    
    init(state: WindowState, frame: CGRect) {
        self.state = state
        super.init(frame: frame)
        self.backgroundColor = .clear
        
        // If the current tool changes, update the number of touches required
        // to trigger the pan gesture to allow the tools to be used
        let toolChange = state.$currentTool.sink(receiveValue: { [weak self] tool in
            if tool == .touch || tool == .placePhoto {
                self?.panGesture?.minimumNumberOfTouches = 1
            } else {
                self?.panGesture?.minimumNumberOfTouches = 2
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
        pan.minimumNumberOfTouches = 2
        pan.delegate = self
        self.panGesture = pan
        self.addGestureRecognizer(pan)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
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
        
        switch sender.state {
        case .began:
            updateScale()
        case .changed:
            updateScale()
        case .cancelled:
            switch self.state.currentTool {
            case .placePhoto:
                self.imageScale = .identity
                self.state.imageConversion?.applyScale(transform: transform)
            default:
                break
            }
        case .ended:
            switch self.state.currentTool {
            case .placePhoto:
                self.imageScale = .identity
                self.state.imageConversion?.applyScale(transform: transform)
            default:
                break
            }
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
            } else {
                self.canvasTranslation = translation
            }
        }
        
        switch sender.state {
        case .began:
            updatePan()
        case .changed:
            updatePan()
        case .cancelled:
            let currentTool = self.state.currentTool
            if currentTool == .placePhoto {
                self.finishPhotoTranslate(translation)
            } else {
                self.finishCanvasTranslate(translation)
            }
        case .ended:
            let currentTool = self.state.currentTool
            if currentTool == .placePhoto {
                self.finishPhotoTranslate(translation)
            } else {
                self.finishCanvasTranslate(translation)
            }
        default:
            break
        }
        self.setNeedsDisplay()
    }
    
    private func translatedPoint(_ point: CGPoint) -> CGPoint {
        let finalTransform = canvasTransform.concatenating(canvasTranslation)
        return point.applying(finalTransform.inverted())
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, event?.allTouches?.count == 1 else { return }
        let currentPoint = translatedPoint(touch.location(in: self))
        switch self.state.currentTool {
        case .pen:
            self.finishPath()
            // Don't start a new path if there are popovers
            guard !state.isShowingPopover else { return }
            // Start a new path
            let path = PhotoDrawPath(path: Path(components: []), semanticColor: state.currentColor)
            state.updatePaths(paths: [path])
            currentPath = ([currentPoint], path)
        case .selection:
            if state.hasSelection {
                self.selectTranslateStart = currentPoint
            } else {
                self.selectStart = currentPoint
            }
        case .remove:
            self.removePoint = currentPoint
            self.removePathPoints = [currentPoint]
        default:
            break
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, event?.allTouches?.count == 1 else { return }
        let currentPoint = translatedPoint(touch.location(in: self))
        switch self.state.currentTool {
        case .pen:
            guard var currentPath = currentPath else {
                return
            }
            currentPath.dataPoints.append(currentPoint)
            // Update bezier path to fit new data
            let newPath = CreatePath.pathFromPoints(currentPath.dataPoints)
            currentPath.path.updatePath(newPath: newPath)
            self.currentPath = (currentPath.dataPoints, currentPath.path)
            self.state.updatePaths(paths: [currentPath.path])
            // Find what area of the screen is updating
            let updateRect = newPath.boundingBox.cgRect
            let transformedRect = updateRect.applying(self.canvasTransform)
            let scaledRect = CGRect(x: transformedRect.minX - 2, y: transformedRect.minY - 2, width: transformedRect.width + 4, height: transformedRect.height + 4)
            
            self.setNeedsDisplay(scaledRect)
        case .selection:
            // Find what area of the screen is updating
            var updateSelectRect: CGRect?
            if let selectStart = selectStart, let selectEnd = selectEnd {
                updateSelectRect = CGRect(x: min(selectStart.x, selectEnd.x), y: min(selectStart.y, selectEnd.y),
                                          width: abs(selectStart.x - selectEnd.x), height: abs(selectStart.y - selectEnd.y))
            }
            
            let previousSelectedPathBox = state.selectedPaths.reduce(into: CGRect?.none, { boundingBox, path in
                guard let box = boundingBox else {
                    boundingBox = path.boundingBox()
                    return
                }
                let pathBox = path.boundingBox()
                boundingBox = pathBox.union(box)
            })
            
            if let previousSelectedPathBox = previousSelectedPathBox {
                updateSelectRect = updateSelectRect?.union(previousSelectedPathBox) ?? previousSelectedPathBox
            }
            
            if state.hasSelection {
                self.selectTranslateEnd = currentPoint
                let selection = state.selectedPaths
                guard let translation = selectTranslation else { return }
                // Update the translation for the selection
                var updatedPaths = [PhotoDrawPath]()
                for path in selection {
                    var newPath = path
                    newPath.transform(translation, commitTransform: false)
                    updatedPaths.append(newPath)
                }
                self.state.updatePaths(paths: updatedPaths)
            } else {
                self.selectEnd = currentPoint
            }
            
            let selectedPathBox = state.selectedPaths.reduce(into: CGRect?.none, { boundingBox, path in
                guard let box = boundingBox else {
                    boundingBox = path.boundingBox()
                    return
                }
                let pathBox = path.boundingBox()
                boundingBox = pathBox.union(box)
            })
            
            if let selectedPathBox = selectedPathBox {
                updateSelectRect = updateSelectRect?.union(selectedPathBox) ?? selectedPathBox
            }
            if let selectRect = selectRect {
                updateSelectRect = updateSelectRect?.union(selectRect) ?? selectRect
            }
            
            if let updateRect = updateSelectRect {
                let transformedRect = updateRect.applying(self.canvasTransform)
                let scaledRect = CGRect(x: transformedRect.minX - 20, y: transformedRect.minY - 20, width: transformedRect.width + 40, height: transformedRect.height + 40)
                self.setNeedsDisplay(scaledRect)
            }
        case .remove:
            var previousPointRect: CGRect?
            if let removePoint = removePoint {
                previousPointRect = CGRect(x: removePoint.x - 5, y: removePoint.y - 5, width: 10, height: 10)
            }
            self.removePoint = currentPoint
            guard var removePathPoints = removePathPoints else { return }
            removePathPoints.append(currentPoint)
            let removePath = CreatePath.pathFromPoints(removePathPoints)
            let removeRect = CGRect(x: currentPoint.x - 5, y: currentPoint.y - 5, width: 10, height: 10)
            
            // Find what area of the screen is updating
            var updateRect = previousPointRect ?? removeRect
            
            for path in self.state.paths where path.boundingBox().intersects(removeRect) && removePath.intersects(path.path) {
                pathsToBeDeleted.insert(path.id)
            }
            
            let deletedPathsBox = self.state.pathsForIdentifiers(pathsToBeDeleted).reduce(into: BoundingBox?.none, { boundingBox, path in
                guard let box = boundingBox else {
                    boundingBox = path.path.boundingBox
                    return
                }
                var pathBox = path.path.boundingBox
                pathBox.union(box)
                boundingBox = pathBox
            })
            if let deletedPathsBox = deletedPathsBox {
                updateRect = updateRect.union(deletedPathsBox.cgRect)
            }
            let transformedRect = updateRect.applying(self.canvasTransform)
            let scaledRect = CGRect(x: transformedRect.minX - 5, y: transformedRect.minY - 5, width: transformedRect.width + 10, height: transformedRect.height + 10)
            self.setNeedsDisplay(scaledRect)
        default:
            break
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.handleTouchStop(touches)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.handleTouchStop(touches)
    }
    
    private func handleTouchStop(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let currentPoint = translatedPoint(touch.location(in: self))
        switch self.state.currentTool {
        case .pen:
            guard let currentPath = currentPath else { return }
            let updateRect = currentPath.path.boundingBox()
            let transformedRect = updateRect.applying(self.canvasTransform)
            let scaledRect = CGRect(x: transformedRect.minX - 2, y: transformedRect.minY - 2, width: transformedRect.width + 4, height: transformedRect.height + 4)
            self.finishPath()
            self.setNeedsDisplay(scaledRect)
        case .selection:
            // Find what area of the screen is updating
            var updateSelectRect: CGRect?
            if let selectStart = selectStart, let selectEnd = selectEnd {
                updateSelectRect = CGRect(x: min(selectStart.x, selectEnd.x), y: min(selectStart.y, selectEnd.y),
                                          width: abs(selectStart.x - selectEnd.x), height: abs(selectStart.y - selectEnd.y))
            }
            
            let previousSelectedPathBox = state.selectedPaths.reduce(into: CGRect?.none, { boundingBox, path in
                guard let box = boundingBox else {
                    boundingBox = path.boundingBox()
                    return
                }
                let pathBox = path.boundingBox()
                boundingBox = pathBox.union(box)
            })
            
            if let previousSelectedPathBox = previousSelectedPathBox {
                updateSelectRect = updateSelectRect?.union(previousSelectedPathBox) ?? previousSelectedPathBox
            }
            
            if state.hasSelection {
                self.selectTranslateEnd = currentPoint
                let selection = state.selectedPaths
                guard let translation = selectTranslation else { return }
                // Update the translation for the selection
                var updatedPaths = [PhotoDrawPath]()
                for path in selection {
                    var newPath = path
                    newPath.transform(translation, commitTransform: true)
                    updatedPaths.append(newPath)
                }
                self.state.updatePaths(paths: updatedPaths)
                self.selectTranslateStart = nil
                self.selectTranslateEnd = nil
            } else {
                self.selectEnd = currentPoint
                self.finishSelection()
            }
            
            let selectedPathBox = state.selectedPaths.reduce(into: CGRect?.none, { boundingBox, path in
                guard let box = boundingBox else {
                    boundingBox = path.boundingBox()
                    return
                }
                let pathBox = path.boundingBox()
                boundingBox = pathBox.union(box)
            })
            
            if let selectedPathBox = selectedPathBox {
                updateSelectRect = updateSelectRect?.union(selectedPathBox) ?? selectedPathBox
            }
            if let selectRect = selectRect {
                updateSelectRect = updateSelectRect?.union(selectRect) ?? selectRect
            }
            
            if let updateRect = updateSelectRect {
                let transformedRect = updateRect.applying(self.canvasTransform)
                let scaledRect = CGRect(x: transformedRect.minX - 20, y: transformedRect.minY - 20, width: transformedRect.width + 40, height: transformedRect.height + 40)
                self.setNeedsDisplay(scaledRect)
            }
        case .remove:
            // Find what area of the screen is updating
            var updateRect = CGRect(x: currentPoint.x - 5, y: currentPoint.y - 5, width: 10, height: 10)
            let deletedPathsBox = self.state.pathsForIdentifiers(pathsToBeDeleted).reduce(into: BoundingBox?.none, { boundingBox, path in
                guard let box = boundingBox else {
                    boundingBox = path.path.boundingBox
                    return
                }
                var pathBox = path.path.boundingBox
                pathBox.union(box)
                boundingBox = pathBox
            })
            if let deletedPathsBox = deletedPathsBox {
                updateRect = updateRect.union(deletedPathsBox.cgRect)
            }
            let transformedRect = updateRect.applying(self.canvasTransform)
            let scaledRect = CGRect(x: transformedRect.minX - 5, y: transformedRect.minY - 5, width: transformedRect.width + 10, height: transformedRect.height + 10)
            self.finishRemove()
            self.setNeedsDisplay(scaledRect)
        default:
            break
        }
    }
    
    private func finishPath() {
        self.currentPath = nil
    }
    
    private func finishSelection() {
        if let selectRect = selectRect {
            var selection = Set<UUID>()
            for path in self.state.paths where path.boundingBox().intersects(selectRect) && path.path.intersectsOrContainedBy(rect: selectRect) {
                selection.insert(path.id)
            }
            if selection.count >= 1 {
                self.state.selection = selection
            }
        }
        self.selectStart = nil
        self.selectEnd = nil
    }
    
    private func finishRemove() {
        self.state.removePaths(pathsToBeDeleted)
        self.removePoint = nil
        self.removePathPoints = nil
    }
    
    private func finishCanvasTranslate(_ translation: CGAffineTransform) {
        self.canvasTransform = self.canvasTransform.concatenating(translation)
        self.canvasTranslation = .identity
    }
    
    private func finishPhotoTranslate(_ translation: CGAffineTransform) {
        self.state.imageConversion?.applyTranslate(transform: translation)
        self.imageTranslation = .identity
    }
    
    override func draw(_ rect: CGRect) {
        // Convert screen rect to canvas space
        let transformedRect = rect.applying(canvasTransform.inverted()).applying(canvasTranslation.inverted())
        let context = UIGraphicsGetCurrentContext()
        context?.setLineCap(.round)
        context?.setShouldAntialias(true)
        
        // Apply transformation
        context?.concatenate(canvasTransform)
        context?.concatenate(canvasTranslation)
        
        // Draw selection
        if let selectRect = selectRect {
            context?.setFillColor(AppColors.accent.withAlphaComponent(0.3).cgColor)
            context?.setStrokeColor(AppColors.accent.cgColor)
            context?.setLineWidth(2)
            context?.addRect(selectRect)
            context?.drawPath(using: .fillStroke)
            context?.strokePath()
        }
        
        // Draw remove tool
        if let removePoint = removePoint {
            context?.setFillColor(UIColor.systemRed.withAlphaComponent(0.3).cgColor)
            context?.setStrokeColor(UIColor.systemRed.cgColor)
            context?.setLineWidth(2)
            
            let rect = CGRect(x: removePoint.x - 5, y: removePoint.y - 5, width: 10, height: 10)
            context?.addEllipse(in: rect)
            context?.drawPath(using: .fillStroke)
        }
        
        
        // Draw selection around selected paths bounding box
        let selectionBoundingBox = state.selectedPaths.reduce(into: CGRect?.none, { boundingBox, path in
            guard let box = boundingBox else {
                boundingBox = path.boundingBox()
                return
            }
            boundingBox = box.union(path.boundingBox())
        })
        
        if let selectionBoundingBox = selectionBoundingBox {
            let largerBox = CGRect(x: selectionBoundingBox.minX - 10, y: selectionBoundingBox.minY - 10, width: selectionBoundingBox.width + 20, height: selectionBoundingBox.height + 20)
            let path = UIBezierPath(roundedRect: largerBox, cornerRadius: 5)
            context?.setFillColor(UIColor.clear.cgColor)
            context?.setStrokeColor(AppColors.accent.withAlphaComponent(0.3).cgColor)
            context?.setLineWidth(2)
            context?.addPath(path.cgPath)
            context?.drawPath(using: .stroke)
            context?.strokePath()
        }
        
        // Draw all bezier paths
        for path in state.paths where path.boundingBox().intersects(transformedRect) {
            
            // Paths that have been touched by the remove tool should have lower opacity
            let color = pathsToBeDeleted.contains(path.id) ? path.color.color.withAlphaComponent(0.3).cgColor : path.color.color.cgColor
            
            context?.setFillColor(color)
            context?.setStrokeColor(color)
            context?.setLineWidth(2)
            // Apply in-progress transform
            let pathTransform = path.transform
            context?.concatenate(pathTransform)
            context?.addPath(path.path.cgPath)
            context?.drawPath(using: .fillStroke)
            context?.strokePath()
            
            // Undo in-progress transform
            context?.concatenate(pathTransform.inverted())
            
        }
        
        // Draw the image that's being placed
        if let imageConversion = state.imageConversion {
            let size = imageConversion.image.size
            var rect: CGRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            rect = rect.applying(imageConversion.scaleTransform)
            rect = rect.applying(imageScale)
            rect = rect.applying(imageConversion.translateTransform)
            rect = rect.applying(imageTranslation)
            // The image needs to be flipped vertically
            context?.saveGState()
            context?.translateBy(x: 0, y: rect.origin.y + rect.height)
            context?.scaleBy(x: 1, y: -1)
            if let cgImage = imageConversion.image.cgImage {
                context?.draw(cgImage, in: CGRect(origin: CGPoint(x: rect.origin.x, y: 0), size: rect.size))
            }
            context?.restoreGState()
        }
        
    }
    
}
 */

class AppColors {
    static var accent: UIColor = {
        let lightMode = #colorLiteral(red: 0.2, green: 0.6666666667, blue: 0.5960784314, alpha: 1)
        let darkMode = #colorLiteral(red: 0.5450980392, green: 0.9607843137, blue: 0.8549019608, alpha: 1)
        let provider: (UITraitCollection) -> UIColor = { traits in
            if traits.userInterfaceStyle == .dark {
                return darkMode
            } else {
                return lightMode
            }
        }
        return UIColor(dynamicProvider: provider)
    }()
    
}

struct CanvasView: UIViewControllerRepresentable {
    @ObservedObject var windowState: WindowState
    
    func makeUIViewController(context: Context) -> UIViewController {
        Canvas(state: windowState)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        
    }
}
