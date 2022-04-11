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
    @Published var paths = [PhotoDrawPath]()
    @Published var currentColor: SemanticColor = .primary
    @Published var currentTool: CanvasTool = .pen {
        willSet {
            // No longer in selection mode, remove selection
            if newValue != CanvasTool.selection {
                selection = nil
            }
            // No longer in pen mode, dismiss the pen color picker
            if newValue != CanvasTool.pen {
                withAnimation{ self.isShowingPenColorPicker = false }
            }
        }
    }
    @Published var selection: [PhotoDrawPath]? = nil {
        // Selection changed, the selection color picker should not be visible
        willSet {
            withAnimation{ self.isShowingSelectionColorPicker = false }
        }
    }
    @Published var isShowingPenColorPicker: Bool = false
    @Published var isShowingSelectionColorPicker: Bool = false
    
    var selectedPaths: [PhotoDrawPath] {
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
    
    func removeSelectionPaths() throws -> Void {
        guard selection != nil else {
            throw SelectionModifyError.noSelection
        }
        let selectionSet = Set<PhotoDrawPath>(selectedPaths)
        paths.removeAll(where: { selectionSet.contains($0) })
        self.selection = nil
    }
}

enum CanvasTool: Equatable {
    case pen
    case selection
    case touch
    case remove
}


class PhotoDrawPath: Equatable, Hashable {
    static func == (lhs: PhotoDrawPath, rhs: PhotoDrawPath) -> Bool {
        lhs.path == rhs.path &&
        lhs.color == rhs.color &&
        lhs.drawMode == rhs.drawMode &&
        lhs.transform == rhs.transform
    }
    func hash(into hasher: inout Hasher) {
            hasher.combine(path)
            hasher.combine(color)
            hasher.combine(drawMode)
    }

    
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
    
    // Allow the path to be modified with a new path to fit to the new point data
    func updatePath(newPath: BezierKit.Path) {
        self.path = newPath
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

enum DrawMode: Equatable {
    case solid
    case dashed
}
