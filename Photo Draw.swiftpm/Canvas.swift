//
//  Canvas.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/6/22.
//

import Foundation
import CoreGraphics
import UIKit
import SwiftUI
import BezierKit

class AccentColor {
    static var color: UIColor = {
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
    
    var currentPath: ([CGPoint], PhotoDrawPath)? = nil
    
    var isDrawing: Bool {
        self.state.currentTool == .pen
    }
    
    var isSelecting: Bool {
        self.state.currentTool == .selection
    }
    
    var selectRect: CGRect? {
        guard let selectStart = selectStart, let selectEnd = selectEnd else {
            return nil
        }
        return CGRect(x: min(selectStart.x, selectEnd.x), y: min(selectStart.y, selectEnd.y), width: abs(selectStart.x - selectEnd.x), height: abs(selectStart.y - selectEnd.y))
    }
    
    init(state: CanvasState, frame: CGRect) {
        self.state = state
        super.init(frame: frame)
        self.backgroundColor = .clear
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDrawing {
            guard let touch = touches.first, touches.count == 1 else { return }
            self.finishPath()
            
            let currentPoint = touch.location(in: self)
            
            let path = PhotoDrawPath(path: BezierKit.Path(components: []), semanticColor: state.currentColor)
            state.paths.append(path)
            currentPath = ([currentPoint], path)
        } else if isSelecting {
            guard let touch = touches.first, touches.count == 1 else { return }
            let currentPoint = touch.location(in: self)
            self.selectStart = currentPoint
        }
    }
        
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDrawing {
            guard let touch = touches.first, touches.count == 1 else { return }
            let currentPoint = touch.location(in: self)
            
            guard var currentPath = currentPath else {
                return
            }
            currentPath.0.append(currentPoint)
            self.currentPath = currentPath
            // Update bezier path to fit new data
            let newPath = LeastSquaresPath.pathFromPoints(currentPath.0)
            currentPath.1.updatePath(newPath: newPath)
            
            self.setNeedsDisplay()
        } else if isSelecting {
            guard let touch = touches.first, touches.count == 1 else { return }
            let currentPoint = touch.location(in: self)
            self.selectEnd = currentPoint
            self.setNeedsDisplay()
        }
    }
        
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDrawing {
            guard let touch = touches.first, touches.count == 1 else { return }
            let currentPoint = touch.location(in: self)
            
            guard var currentPath = currentPath else {
                return
            }
            currentPath.0.append(currentPoint)
            self.currentPath = currentPath
            // Update bezier path to fit new data
            let newPath = LeastSquaresPath.pathFromPoints(currentPath.0)
            currentPath.1.updatePath(newPath: newPath)
            
            self.finishPath()
            
            self.setNeedsDisplay()
        } else if isSelecting {
            guard let touch = touches.first, touches.count == 1 else { return }
            let currentPoint = touch.location(in: self)
            self.selectEnd = currentPoint
            self.finishSelection()
            self.setNeedsDisplay()
        }
    }
    
    private func finishPath() {
        self.currentPath = nil
    }
    
    private func finishSelection() {
        self.selectStart = nil
        self.selectEnd = nil
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setLineCap(.round)
        context?.setShouldAntialias(true)
        
        // Draw selection
        if let selectRect = selectRect {
            context?.setFillColor(AccentColor.color.withAlphaComponent(0.3).cgColor)
            context?.setStrokeColor(AccentColor.color.cgColor)
            context?.setLineWidth(2)
            context?.beginPath()
            context?.addRect(selectRect)
            context?.drawPath(using: .fillStroke)
            context?.strokePath()
        }
        
        // Draw all bezier paths
        for path in state.paths {
            context?.setFillColor(path.color.color.cgColor)
            context?.setStrokeColor(path.color.color.cgColor)
            context?.addPath(path.path.cgPath)
            context?.drawPath(using: .fillStroke)
            context?.strokePath()
        }
    }
    
}

struct CanvasView: UIViewControllerRepresentable {
    @ObservedObject var windowState: CanvasState
    
    func makeUIViewController(context: Context) -> UIViewController {
        Canvas(state: windowState)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        
    }
}
