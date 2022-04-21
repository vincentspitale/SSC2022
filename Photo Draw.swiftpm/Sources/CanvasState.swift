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

@MainActor
class CanvasState: ObservableObject {
    // Strokes that are on the canvas
    private var currentPathState: (paths: [UUID : PhotoDrawPath], order: [UUID]) = ([:], [])
    private var previousPathState: (paths: [UUID : PhotoDrawPath], order: [UUID])?
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
    @Published var selection: Set<UUID>? = nil {
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
    
    weak var canvas: Canvas? = nil
    
    var hasSelection: Bool {
        self.selection != nil
    }
    
    var isShowingPopover: Bool {
        isShowingPenColorPicker || isShowingSelectionColorPicker
    }
    
    var selectedPaths: [PhotoDrawPath] {
        guard let selection = selection else { return [] }
        return selection.compactMap { id in
            self.currentPathState.paths[id]
        }
    }
    
    var selectionColors: Set<SemanticColor> {
        return self.selectedPaths.reduce(into: Set<SemanticColor>(), { colorSet, path in
            colorSet.insert(path.color)
        })
    }
    
    var paths: [PhotoDrawPath] {
        self.currentPathState.order.compactMap { id in
            return self.currentPathState.paths[id]
        }
    }
    
    enum SelectionModifyError: Error {
        case noSelection
    }
    
    func updatePaths(paths: [PhotoDrawPath]) {
        var newPaths = [PhotoDrawPath]()
        for path in paths {
            if self.currentPathState.paths[path.id] == nil {
                newPaths.append(path)
            }
            self.currentPathState.paths[path.id] = path
        }
        for newPath in newPaths {
            self.currentPathState.order.append(newPath.id)
        }
    }
    
    func pathsForIdentifiers(ids: Set<UUID>) -> [PhotoDrawPath] {
        return ids.compactMap { id in
            return self.currentPathState.paths[id]
        }
    }
    
    func recolorSelection(newColor: SemanticColor) throws -> Void {
        guard selection != nil else {
            throw SelectionModifyError.noSelection
        }
        let updatedPaths = selectedPaths.map { path -> PhotoDrawPath in
            var path = path
            path.color = newColor
            return path
        }
        self.updatePaths(paths: updatedPaths)
        
        // Update the canvas with the new color
        objectWillChange.send()
    }
    
    func removeSelectionPaths() throws -> Void {
        guard let selection = selection else {
            throw SelectionModifyError.noSelection
        }
        self.removePaths(selection)
        withAnimation { self.selection = nil }
    }
    
    func removePaths(_ removeSet: Set<UUID>) {
        for id in removeSet {
            self.currentPathState.paths.removeValue(forKey: id)
        }
        self.currentPathState.order = self.currentPathState.order.filter { !removeSet.contains($0)}
    }
    
    func startConversion(image: UIImage) async {
            let centerScreen = await self.canvas?.getCenterScreenCanvasPosition() ?? CGPoint(x: 0, y: 0)
            let conversion = ImageConversion(image: image, position: centerScreen)
            // Begin background conversion
            conversion.convert()
            self.imageConversion = conversion
            // Subscribe to this image conversion's updates
            self.imageCancellable = conversion.objectWillChange.sink(receiveValue: { _ in
                Task { @MainActor in
                    self.objectWillChange.send()
                }
            })
        Task { @MainActor in
            withAnimation { self.currentTool = .placePhoto }
        }
    }
    
    /// Adds the image conversion paths to the canvas
    func placeImage() {
        guard let imageConversion = imageConversion else { return }
        let imagePaths = imageConversion.getPaths()
        self.updatePaths(paths: imagePaths)
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


struct PhotoDrawPath: Identifiable {
    var id: UUID
    var path: Path
    var color: SemanticColor
    var transform: CGAffineTransform
    
    init(path: Path, color: UIColor) {
        self.id = UUID()
        self.path = path
        self.color = SemanticColor.colorToSemanticColor(color: color)
        self.transform = .identity
    }
    
    init(path: Path, semanticColor: SemanticColor) {
        self.id = UUID()
        self.path = path
        self.color = semanticColor
        self.transform = .identity
    }
    
    
    mutating func transform(_ newTransform: CGAffineTransform, commitTransform: Bool) {
        self.transform = newTransform
        if commitTransform {
            self.path = self.path.copy(using: newTransform)
            self.transform = .identity
        }
    }
    
    // Allow the path to be modified with a new path to fit to the new point data
    mutating func updatePath(newPath: Path) {
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
        
        
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        
        // Have only a few color match options to prevent incorrect conversions
        // Use colors that are independent of system theme, light or dark mode
        let red = #colorLiteral(red: 1, green: 0, blue: 0, alpha: 1)
        let green = #colorLiteral(red: 0, green: 1, blue: 0, alpha: 1)
        let blue = #colorLiteral(red: 0, green: 0, blue: 1, alpha: 1)
        let supportedColors: [(SemanticColor, UIColor)] = [(SemanticColor.red, red), (SemanticColor.green, green), (SemanticColor.blue, blue)]
        let closestColor: (SemanticColor, CGFloat)? = supportedColors.reduce(into: nil, { nearestColor, color in
            var colorR: CGFloat = 0.0
            var colorG: CGFloat = 0.0
            var colorB: CGFloat = 0.0
            
            color.1.getRed(&colorR, green: &colorG, blue: &colorB, alpha: nil)
            let crossProduct = r * colorR + g * colorG + b * colorB
            
            if let (semanticColor, similarity) = nearestColor {
                if crossProduct > similarity  {
                    nearestColor = (semanticColor, crossProduct)
                }
            } else {
                nearestColor = (color.0, crossProduct)
            }
        })
        
        if let closestColor = closestColor {
            let color = closestColor.0.color
            var colorR: CGFloat = 0.0
            var colorG: CGFloat = 0.0
            var colorB: CGFloat = 0.0
            
            color.getRed(&colorR, green: &colorG, blue: &colorB, alpha: nil)
            if max(abs(colorR - r), abs(colorG - g), abs(colorB - b)) < 0.3 {
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
        // Initially fit the image within a 400 point square
        let dimension: CGFloat = 400
        guard let cgImage = image.cgImage else { return .identity }
        let width = cgImage.width
        let height = cgImage.height
        let max: CGFloat = CGFloat(max(width, height))
        let scale = dimension / max
        let transform = CGAffineTransform.init(scaleX: scale, y: scale)
        return transform
    }()
    
    var translateTransform: CGAffineTransform
    
    var transform: CGAffineTransform {
        return scaleTransform.concatenating(translateTransform)
    }
    
    var isConversionFinished: Bool {
        paths != nil
    }
    
    init(image: UIImage, position: CGPoint) {
        self.image = image
        self.translateTransform = CGAffineTransform(translationX: position.x, y: position.y)
        let size = image.size
        // translate the image so that the image is centered on the canvas
        var rect: CGRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        rect = rect.applying(scaleTransform)
        self.translateTransform = translateTransform.translatedBy(x: -1 * CGFloat(rect.width) / 2, y: -1 * CGFloat(rect.height) / 2)
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
