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

class Canvas: UIViewController {
    var state: CanvasState
    
    init(state: CanvasState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        let renderView = RenderView(state: state, frame: self.view.frame)
        renderView.translatesAutoresizingMaskIntoConstraints = false
        renderView.addGestureRecognizer(tapGesture)
        self.view.addSubview(renderView)
        
        let constraints = [
            renderView.topAnchor.constraint(equalTo: self.view.topAnchor),
            renderView.heightAnchor.constraint(greaterThanOrEqualTo: self.view.heightAnchor),
            renderView.widthAnchor.constraint(greaterThanOrEqualTo: self.view.widthAnchor),
            renderView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            renderView.widthAnchor.constraint(equalTo: renderView.heightAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
        
    }
    
    @objc
    func handleTap(_ sender: UITapGestureRecognizer) -> Void {
        if sender.state == .ended {
            withAnimation{ self.state.isShowingPenColorPicker = false }
            withAnimation{ state.selection = nil }
        }
    }
}

class RenderView: UIView {
    private var state: CanvasState
    
    // Move canvas
    private var canvasTransform: CGAffineTransform = .identity
    
    private var canvasTranslateStart: CGPoint?
    private var canvasTranslateEnd: CGPoint?
    
    private var canvasTranslation: CGAffineTransform? {
        guard let translateStart = canvasTranslateStart, let translateEnd = canvasTranslateEnd else {
            return nil
        }
        return CGAffineTransform.identity.translatedBy(x: translateEnd.x - translateStart.x, y: translateEnd.y - translateStart.y)
    }
    
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
    private var pathsToBeDeleted = Set<PhotoDrawPath>()
    
    private var cancellable: AnyCancellable? = nil
    
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
    
    private var imageTranslateStart: CGPoint?
    private var imageTranslateEnd: CGPoint?
    
    private var imageTranslation: CGAffineTransform? {
        guard let translateStart = imageTranslateStart, let translateEnd = imageTranslateEnd else {
            return nil
        }
        return CGAffineTransform.identity.translatedBy(x: translateEnd.x - translateStart.x, y: translateEnd.y - translateStart.y)
    }
    
    var pinchGesture: UIPinchGestureRecognizer?
    
    init(state: CanvasState, frame: CGRect) {
        self.state = state
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.cancellable = state.objectWillChange.sink(receiveValue: { [weak self] _ in
            self?.setNeedsDisplay()
        })
        self.pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
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
        
        switch sender.state {
        case .began:
            updateScale()
        case .changed:
            updateScale()
        case .ended:
            switch self.state.currentTool {
            case .placePhoto:
                self.imageScale = .identity
                self.state.imageConversion?.transform.concatenating(transform)
            default:
                break
            }
        default:
            break
        }
        self.setNeedsDisplay()
    }
    
    private func translatedPoint(_ point: CGPoint) -> CGPoint {
        return point.applying(canvasTransform.inverted())
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
            state.paths.append(path)
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
        case .touch:
            self.canvasTranslateStart = currentPoint
        case .placePhoto:
            self.imageTranslateStart = currentPoint
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
            self.currentPath = currentPath
            // Update bezier path to fit new data
            let newPath = LeastSquaresPath.pathFromPoints(currentPath.dataPoints)
            currentPath.path.updatePath(newPath: newPath)
            
        case .selection:
            if state.hasSelection {
                self.selectTranslateEnd = currentPoint
                guard let selection = state.selection, let translation = selectTranslation else { return }
                // Update the translation for the selection
                for path in selection {
                    path.transform(translation, commitTransform: false)
                }
            } else {
                self.selectEnd = currentPoint
            }
        case .remove:
            self.removePoint = currentPoint
            guard var removePathPoints = removePathPoints else { return }
            removePathPoints.append(currentPoint)
            let removePath = LeastSquaresPath.pathFromPoints(removePathPoints)
            let removeRect = CGRect(x: currentPoint.x - 5, y: currentPoint.y - 5, width: 10, height: 10)
            for path in self.state.paths where path.path.intersectsOrContainedBy(rect: removeRect) || removePath.intersects(path.path) {
                pathsToBeDeleted.insert(path)
            }
        case .touch:
            self.canvasTranslateEnd = currentPoint
        case .placePhoto:
            self.imageTranslateEnd = currentPoint
        default:
            break
        }
        self.setNeedsDisplay()
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
            guard var currentPath = currentPath else {
                return
            }
            currentPath.dataPoints.append(currentPoint)
            self.currentPath = currentPath
            // Update bezier path to fit new data
            let newPath = LeastSquaresPath.pathFromPoints(currentPath.dataPoints)
            currentPath.path.updatePath(newPath: newPath)
            
            self.finishPath()
        case .selection:
            if state.hasSelection {
                self.selectTranslateEnd = currentPoint
                guard let selection = state.selection, let translation = selectTranslation else { return }
                // Update the translation for the selection
                for path in selection {
                    path.transform(translation, commitTransform: true)
                }
                self.selectTranslateStart = nil
                self.selectTranslateEnd = nil
            } else {
                self.selectEnd = currentPoint
                self.finishSelection()
            }
        case .remove:
            self.finishRemove()
        case .touch:
            self.finishCanvasTranslate()
        case .placePhoto:
            self.finishPhotoTranslate()
        default:
            break
        }
        
        self.setNeedsDisplay()
    }
    
    private func finishPath() {
        self.currentPath = nil
    }
    
    private func finishSelection() {
        if let selectRect = selectRect {
            var selection = [PhotoDrawPath]()
            for path in self.state.paths where path.path.intersectsOrContainedBy(rect: selectRect) {
                selection.append(path)
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
    
    private func finishCanvasTranslate() {
        guard let canvasTranslation = canvasTranslation else {
            return
        }
        self.canvasTransform = self.canvasTransform.concatenating(canvasTranslation)
        self.canvasTranslateStart = nil
        self.canvasTranslateEnd = nil
    }
    
    private func finishPhotoTranslate() {
        guard let imageTranslation = imageTranslation else {
            return
        }
        self.state.imageConversion?.transform.concatenating(imageTranslation)
        self.imageTranslateStart = nil
        self.imageTranslateEnd = nil
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setLineCap(.round)
        context?.setShouldAntialias(true)
        
        // Apply transformation
        context?.concatenate(canvasTransform)
        if let canvasTranslation = canvasTranslation {
            context?.concatenate(canvasTranslation)
        }
        
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
        
        // Draw all bezier paths
        for path in state.paths {
            // Draw selection border around selected paths
            if state.selectedPaths.contains(path) {
                context?.setFillColor(AppColors.accent.cgColor)
                context?.setStrokeColor(AppColors.accent.cgColor)
                context?.setLineWidth(5)
                // Apply in-progress transform
                if let pathTransform = path.transform {
                    context?.concatenate(pathTransform)
                }
                context?.addPath(path.path.cgPath)
                context?.drawPath(using: .fillStroke)
                context?.strokePath()
                // Undo in-progress transform
                if let pathTransform = path.transform {
                    context?.concatenate(pathTransform.inverted())
                }
            }
            
            
            // Paths that have been touched by the remove tool should have lower opacity
            let color = pathsToBeDeleted.contains(path) ? path.color.color.withAlphaComponent(0.3).cgColor : path.color.color.cgColor
            
            context?.setFillColor(color)
            context?.setStrokeColor(color)
            context?.setLineWidth(2)
            // Apply in-progress transform
            if let pathTransform = path.transform {
                context?.concatenate(pathTransform)
            }
            context?.addPath(path.path.cgPath)
            context?.drawPath(using: .fillStroke)
            context?.strokePath()
            
            // Undo in-progress transform
            if let pathTransform = path.transform {
                context?.concatenate(pathTransform.inverted())
            }
            
        }
        
        // Draw the image that's being placed
        if let imageConversion = state.imageConversion {
            let imageTransform = imageConversion.transform
            let size = imageConversion.image.size
            let rect: CGRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            rect.applying(imageTransform)
            rect.applying(imageScale)
            if let cgImage = imageConversion.image.cgImage {
                context?.draw(cgImage, in: rect)
            }
        }
        
    }
    
}

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
    @ObservedObject var windowState: CanvasState
    
    func makeUIViewController(context: Context) -> UIViewController {
        Canvas(state: windowState)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        
    }
}


fileprivate extension Path {
    // Determine if this path should be selected by a selection area
    func intersectsOrContainedBy(rect: CGRect) -> Bool {
        let rectPath = Path(cgPath: CGPath(rect: rect, transform: nil))
        return self.intersects(rectPath) || rectPath.contains(self)
    }
}
