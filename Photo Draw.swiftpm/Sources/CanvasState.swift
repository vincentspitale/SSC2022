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
    case touch
    case pen
    case remove
    case selection
    case placePhoto
}


class PhotoDrawPath {
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

extension PhotoDrawPath: Equatable, Hashable {
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
}

enum SemanticColor: CaseIterable, Comparable {
    // Supported colors
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
    
    // Accessibility label for color
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
        let hue: UnsafeMutablePointer<CGFloat>? = nil
        let saturation: UnsafeMutablePointer<CGFloat>? = nil
        color.getHue(hue, saturation: saturation, brightness: nil, alpha: nil)
        if let hue = hue?.pointee, let saturation = saturation, saturation.pointee > 0.4  {
            // Have only a few colors match options to prevent incorrect conversions
            let supportedColors: [SemanticColor] = [SemanticColor.red, SemanticColor.green, SemanticColor.blue]
            let hueColors = supportedColors.map { ($0, SemanticColor.colorHue(color: $0.color)) }
            let closestColor: (SemanticColor, CGFloat)? = hueColors.reduce(into: nil, { nearestColor, color in
                if let (_, previousHue) = nearestColor {
                    if abs(hue - color.1) < abs(hue - previousHue)  {
                        nearestColor = color
                    }
                } else {
                    nearestColor = color
                }
            })
            if let closestColor = closestColor, abs(closestColor.1 - hue) < 0.1 {
                return closestColor.0
            }
        }
        
        return .primary
    }
    
    private static func colorHue(color: UIColor) -> CGFloat {
        let hue: UnsafeMutablePointer<CGFloat>? = nil
        color.getHue(hue, saturation: nil, brightness: nil, alpha: nil)
        return hue?.pointee ?? 0.0
    }
    
}

enum DrawMode: Equatable {
    case solid
    case dashed
}
