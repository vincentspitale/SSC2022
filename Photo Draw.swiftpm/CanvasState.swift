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
    @Published var paths = [VectorPath]()
    @Published var currentColor: SemanticColor = .primary
    @Published var currentTool: CanvasTool = .pen {
        willSet {
            if newValue != CanvasTool.selection {
                selection = nil
                withAnimation{ self.isShowingSelectionColorPicker = false }
            }
            if newValue != CanvasTool.pen {
                withAnimation{ self.isShowingPenColorPicker = false }
            }
        }
    }
    @Published var selection: [VectorPath]? = nil {
        willSet {
            withAnimation{ self.isShowingSelectionColorPicker = false }
            if selection != nil {
                self.currentTool = .selection
            }
        }
    }
    @Published var isShowingPenColorPicker: Bool = false
    @Published var isShowingSelectionColorPicker: Bool = false
    
    var selectedPaths: [VectorPath] {
        return selection ?? []
    }
    
var selectionColors: Set<SemanticColor> {
        return self.selectedPaths.reduce(into: Set<SemanticColor>(), { colorSet, path in
            colorSet.insert(path.color)
        })
    }
    
    enum SelectionModifyError: Error {
        case noSelection
    }
    
    func recolorSelection(newColor: SemanticColor) throws -> Void {
        guard let selection = selection else {
            throw SelectionModifyError.noSelection
        }
        for path in selection {
            path.color = newColor
        }
        objectWillChange.send()
    }
}

enum CanvasTool: Equatable {
    case pen
    case selection
    case touch
    case remove
}


class VectorPath {
    var path: BezierKit.Path
    var color: SemanticColor
    var drawMode: DrawMode
    var transform: simd_float3x3
    
    init(path: BezierKit.Path, color: UIColor, drawMode: DrawMode = .solid) {
        self.path = path
        self.color = SemanticColor.colorToSemanticColor(color: color)
        self.drawMode = drawMode
        self.transform = matrix_identity_float3x3
    }
    
    init(path: BezierKit.Path, semanticColor: SemanticColor, drawMode: DrawMode = .solid) {
        self.path = path
        self.color = semanticColor
        self.drawMode = drawMode
        self.transform = matrix_identity_float3x3
    }
    
    func resize(transform: simd_float3x3) {
        self.transform *= transform
    }
}

enum SemanticColor: CaseIterable, Comparable {
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
