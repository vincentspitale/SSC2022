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
        guard let touch = touches.first, touches.count == 1 else { return }
        self.finishPath()
        
        let currentPoint = touch.location(in: self)
        
        let path = PhotoDrawPath(path: BezierKit.Path(components: []), semanticColor: state.currentColor)
        state.paths.append(path)
        currentPath = ([currentPoint], path)
    }
        
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawing else { return }
        guard let touch = touches.first, touches.count == 1 else { return }
        let currentPoint = touch.location(in: self)
        
        guard var currentPath = currentPath else {
            return
        }
        currentPath.0.append(currentPoint)
        self.currentPath = currentPath
        // update bezier path
        let newPath = LeastSquaresPath.pathFromPoints(currentPath.0)
        currentPath.1.updatePath(newPath: newPath)
        
        self.setNeedsDisplay()
    }
        
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawing else { return }
        guard let touch = touches.first, touches.count == 1 else { return }
        let currentPoint = touch.location(in: self)
        
        guard var currentPath = currentPath else {
            return
        }
        currentPath.0.append(currentPoint)
        self.currentPath = currentPath
        // update bezier path
        let newPath = LeastSquaresPath.pathFromPoints(currentPath.0)
        currentPath.1.updatePath(newPath: newPath)
        
        self.finishPath()
        
        self.setNeedsDisplay()
    }
    
    private func finishPath() {
        self.currentPath = nil
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setLineCap(.round)
        // draw all bezier paths
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
