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
import SwiftUI
import simd


class CanvasState: ObservableObject {
    @Published var paths = [Path]()
    @Published var currentColor: SemanticColor = .primary
    @Published var currentTool: CanvasTool = .pen {
        willSet {
            if newValue != CanvasTool.selection {
                selection = nil
            }
            if newValue != CanvasTool.pen {
                withAnimation{ self.isShowingColorPicker = false }
            }
        }
    }
    @Published var selection: [Path]? = nil
    @Published var isShowingColorPicker: Bool = false
    
    var selectedPaths: [Path] {
        return selection ?? []
    }
}

enum CanvasTool: Equatable {
    case pen
    case selection
    case touch
    case remove
}


class Path {
    var curve: BezierCurve
    var color: SemanticColor
    var drawMode: DrawMode
    var transform: simd_float3x3
    
    init(curve: BezierCurve, color: UIColor, drawMode: DrawMode = .solid) {
        self.curve = curve
        self.color = SemanticColor.colorToSemanticColor(color: color)
        self.drawMode = drawMode
        self.transform = matrix_identity_float3x3
    }
    
    func resize(transform: simd_float3x3) {
        self.transform *= transform
    }
}

enum SemanticColor: CaseIterable {
    case primary
    case gray
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
        case .gray:
            return UIColor.systemGray
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
    
    public func name(isDark: Bool) -> String {
        switch self {
        case .primary:
            return isDark ? "White" : "Black"
        case .gray:
            return "Gray"
        case .red:
            return "Red"
        case .orange:
            return "Orange"
        case .yellow:
            return "Yellow"
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .purple:
            return "Purple"
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
