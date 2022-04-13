//
//  Canvas.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/6/22.
//

import BezierKit
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
    var state: CanvasState
    var selectStart: CGPoint?
    var selectEnd: CGPoint?
    
    var currentPath: (dataPoints: [CGPoint], path: PhotoDrawPath)? = nil
    
    var removePoint: CGPoint? = nil
    var pathsToBeDeleted = Set<PhotoDrawPath>()
    
    private var cancellable: AnyCancellable? = nil
    
    var selectRect: CGRect? {
        guard let selectStart = selectStart, let selectEnd = selectEnd else {
            return nil
        }
        return CGRect(x: min(selectStart.x, selectEnd.x), y: min(selectStart.y, selectEnd.y),
                      width: abs(selectStart.x - selectEnd.x), height: abs(selectStart.y - selectEnd.y))
    }
    
    init(state: CanvasState, frame: CGRect) {
        self.state = state
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.cancellable = state.objectWillChange.sink(receiveValue: { [weak self] _ in
                self?.setNeedsDisplay()
            })
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, event?.allTouches?.count == 1 else { return }
        let currentPoint = touch.location(in: self)
        switch self.state.currentTool {
        case .pen:
            self.finishPath()
            // Start a new path
            let path = PhotoDrawPath(path: BezierKit.Path(components: []), semanticColor: state.currentColor)
            state.paths.append(path)
            currentPath = ([currentPoint], path)
        case .selection:
            self.selectStart = currentPoint
        case .remove:
            self.removePoint = currentPoint
        default:
            break
        }
    }
        
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, event?.allTouches?.count == 1 else { return }
        let currentPoint = touch.location(in: self)
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
            self.selectEnd = currentPoint
        case .remove:
            let removeRect = CGRect(x: currentPoint.x - 5, y: currentPoint.y - 5, width: 10, height: 10)
            for path in self.state.paths where path.path.intersectsOrContainedBy(rect: removeRect) {
                pathsToBeDeleted.insert(path)
            }
            self.removePoint = currentPoint
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
        let currentPoint = touch.location(in: self)
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
            self.selectEnd = currentPoint
            self.finishSelection()
        case .remove:
            self.finishRemove()
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
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setLineCap(.round)
        context?.setShouldAntialias(true)
        
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
                context?.setLineWidth(3)
                context?.addPath(path.path.cgPath)
                context?.drawPath(using: .fillStroke)
                context?.strokePath()
            }
            
            // Paths that have been touched by the remove tool should have lower opacity
            let color = pathsToBeDeleted.contains(path) ? path.color.color.withAlphaComponent(0.3).cgColor : path.color.color.cgColor
            
            context?.setFillColor(color)
            context?.setStrokeColor(color)
            context?.setLineWidth(2)
            context?.addPath(path.path.cgPath)
            context?.drawPath(using: .fillStroke)
            context?.strokePath()
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


fileprivate extension BezierKit.Path {
    func intersectsOrContainedBy(rect: CGRect) -> Bool {
        let rectPath = BezierKit.Path(cgPath: CGPath(rect: rect, transform: nil))
        return self.intersects(rectPath) || rectPath.contains(self)
    }
}
