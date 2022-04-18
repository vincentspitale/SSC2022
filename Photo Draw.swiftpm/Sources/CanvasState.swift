//
//  CanvasState.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/6/22.
//

import Foundation
import Combine
import UIKit
import SwiftUI
import simd

class CanvasState: ObservableObject {
    // Strokes that are on the canvas
    @Published var paths = [PhotoDrawPath]()
    // The color of the pen tool
    @Published var currentColor: SemanticColor = .primary
    @Published var currentTool: CanvasTool = .pen {
        willSet {
            DispatchQueue.main.async {
                // No longer in selection mode, remove selection
                if newValue != CanvasTool.selection {
                    self.selection = nil
                }
                // No longer in pen mode, dismiss the pen color picker
                if newValue != CanvasTool.pen {
                    withAnimation{ self.isShowingPenColorPicker = false }
                }
            }
        }
    }
    @Published var selection: [PhotoDrawPath]? = nil {
        // Selection changed, the selection color picker should not be visible
        willSet {
            DispatchQueue.main.async {
                withAnimation{ self.isShowingSelectionColorPicker = false }
            }
            
        }
    }
    @Published var isShowingPenColorPicker: Bool = false
    @Published var isShowingSelectionColorPicker: Bool = false
    @Published var photoMode: PhotoMode = .welcome
    
    var imageConversion: ImageConversion? = nil
    // Notify when the image convdrsion has completed
    var imageCancellable: AnyCancellable? = nil
    
    var hasSelection: Bool {
        self.selection != nil
    }
    
    var isShowingPopover: Bool {
        isShowingPenColorPicker || isShowingSelectionColorPicker
    }
    
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
        // Update the canvas with the new color
        objectWillChange.send()
    }
    
    func removeSelectionPaths() throws -> Void {
        guard selection != nil else {
            throw SelectionModifyError.noSelection
        }
        let selectionSet = Set<PhotoDrawPath>(selectedPaths)
        paths.removeAll(where: { selectionSet.contains($0) })
        withAnimation { self.selection = nil }
    }
    
    func removePaths(_ removeSet: Set<PhotoDrawPath>) {
        paths.removeAll(where: { removeSet.contains($0) })
    }
    
    func startConversion(image: UIImage) {
        let conversion = ImageConversion(image: image)
        // Begin background conversion
        conversion.convert()
        self.imageConversion = conversion
        // Subscribe to this image conversion's updates
        self.imageCancellable = conversion.objectWillChange.sink(receiveValue: { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        })
        DispatchQueue.main.async {
            withAnimation { self.currentTool = .placePhoto }
        }
    }
    
    /// Adds the image conversion paths to the canvas
    func placeImage() {
        guard let imageConversion = imageConversion else { return }
        let imagePaths = imageConversion.getPaths()
        self.paths.append(contentsOf: imagePaths)
        withAnimation { self.currentTool = .pen }
        self.imageConversion = nil
    }
}

enum CanvasTool: Equatable {
    case touch
    case pen
    case remove
    case selection
    case placePhoto
}


enum PhotoMode {
    case welcome
    case none
    case cameraScan
    case library
    case example
}


class PhotoDrawPath {
    var path: Path
    var color: SemanticColor
    var transform: CGAffineTransform?
    
    init(path: Path, color: UIColor) {
        self.path = path
        self.color = SemanticColor.colorToSemanticColor(color: color)
        self.transform = .identity
    }
    
    init(path: Path, semanticColor: SemanticColor) {
        self.path = path
        self.color = semanticColor
        self.transform = .identity
    }
    
    func transform(_ newTransform: CGAffineTransform, commitTransform: Bool) {
        self.transform = newTransform
        if commitTransform {
            self.path = self.path.copy(using: newTransform)
            self.transform = .identity
        }
    }
    
    // Allow the path to be modified with a new path to fit to the new point data
    func updatePath(newPath: Path) {
        self.path = newPath
    }
    
}

extension PhotoDrawPath: Equatable, Hashable {
    static func == (lhs: PhotoDrawPath, rhs: PhotoDrawPath) -> Bool {
        lhs.path == rhs.path &&
        lhs.color == rhs.color &&
        lhs.transform == rhs.transform
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(color)
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
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        // If the saturation and brightness are high enough, try to match to a color
        if saturation > 0.4 && brightness > 0.3  {
            // Have only a few color match options to prevent incorrect conversions
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
        var hue: CGFloat = 0.0
        color.getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
        return hue
    }
    
}

class ImageConversion: ObservableObject {
    let image: UIImage
    private var paths: [PhotoDrawPath]? = nil
    
    lazy var scaleTransform: CGAffineTransform = {
        // Initially fit the image within a 300 point square
        let dimension: CGFloat = 300
        guard let cgImage = image.cgImage else { return .identity }
        let width = cgImage.width
        let height = cgImage.height
        let max: CGFloat = CGFloat(max(width, height))
        let scale = dimension / max
        let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(height))
        let transform = flipVertical.concatenating(CGAffineTransform.init(scaleX: scale, y: scale))
        return transform
    }()
    
    var translateTransform: CGAffineTransform = .identity
    
    var transform: CGAffineTransform {
        return scaleTransform.concatenating(translateTransform)
    }
    
    var isConversionFinished: Bool {
        paths != nil
    }
    
    init(image: UIImage) {
        self.image = image
    }
    
    func applyTranslate(transform: CGAffineTransform) {
        self.translateTransform = self.translateTransform.concatenating(transform)
    }
    
    func applyScale(transform: CGAffineTransform) {
        self.scaleTransform = self.scaleTransform.concatenating(transform)
    }
    
    /// Start the path conversion of this image
    func convert() {
        Task {
            let convertedPaths = ImagePathConverter(image: image).findPaths()
            self.paths = convertedPaths.map { (path, color) -> PhotoDrawPath in
                return PhotoDrawPath(path: path, color: color)
            }
            // Notify that the image has been converted
            self.objectWillChange.send()
        }
    }
    
    func getPaths() -> [PhotoDrawPath] {
        guard let paths = self.paths else { return [] }
        return paths.map { path in
            PhotoDrawPath(path: path.path.copy(using: transform), semanticColor: path.color)
        }
    }
}
