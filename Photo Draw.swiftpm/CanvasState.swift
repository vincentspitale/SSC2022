//
//  File.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/6/22.
//

import Foundation
import Combine
import BezierKit
import UIKit


class CanvasState: ObservableObject {
    @Published var paths = [Path]()
    @Published var currentColor: SemanticColor = .primary
    @Published var currentTool: CanvasTool = .pen {
        willSet {
            if newValue != CanvasTool.selection {
                selection = nil
            }
        }
    }
    @Published var selection: CGRect? = nil
}

enum CanvasTool: Equatable {
    case pen
    case selection
    case touch
}


class Path {
    var curve: BezierCurve
    var color: SemanticColor
    var drawMode: DrawMode
    
    init(curve: BezierCurve, color: UIColor, drawMode: DrawMode = .solid) {
        self.curve = curve
        self.color = SemanticColor.colorToSemanticColor(color: color)
        self.drawMode = drawMode
    }
}

enum SemanticColor {
    case primary
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    
    public var color: UIColor {
        switch self {
        case .primary:
            return UIColor.label
        case .red:
            return UIColor.systemRed
        case .orange:
            return UIColor.systemOrange
        case .yellow:
            return UIColor.systemYellow
        case .green:
            return UIColor.systemGreen
        case .blue:
            return UIColor.systemBlue
        case .purple:
            return UIColor.systemPurple
        }
    }
    
    public static func colorToSemanticColor(color: UIColor) -> SemanticColor {
        #warning("implement")
        return .primary
    }
    
    private static func colorHue(color: UIColor) -> Float {
        #warning("implement")
        return 1
    }
    
}

enum DrawMode {
    case solid
    case dashed
}
