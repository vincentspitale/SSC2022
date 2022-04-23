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
import PencilKit

class WindowState: ObservableObject {
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
    
    // Store the indices of the selected strokes in the drawing's strokes array
    @Published var selection: Set<Int>? = nil {
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
    
    @Published var finalizeImage: UIImage? = nil
    var imageConversion: ImageConversion? = nil
    // Notify when the image conversion has completed
    var imageCancellable: AnyCancellable? = nil
    
    // Used to know where to place the image
    weak var canvas: Canvas? = nil
    
    var hasSelection: Bool {
        self.selection != nil
    }
    
    var isShowingPopover: Bool {
        isShowingPenColorPicker || isShowingSelectionColorPicker
    }
    
    var selectedStrokes: [PKStroke] {
        guard let selection = selection else { return [] }
        return []
    }
    
    var selectionColors: Set<UIColor> {
        return self.selectedStrokes.reduce(into: Set<UIColor>(), { colorSet, path in
            colorSet.insert(path.ink.color)
        })
    }
    
    var paths: [PKStroke] {
        []
    }
    
    enum SelectionModifyError: Error {
        case noSelection
    }
    
    func updatePaths(paths: [PKStroke]) {
  
    }
    
    func pathsForIdentifiers(_ ids: Set<UUID>) -> [PKStroke] {
        return []
    }
    
    func recolorSelection(newColor: SemanticColor) throws -> Void {
    
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
    
    func removePaths(_ removeSet: Set<Int>) {
        
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
    
    private var _color: UIColor {
        switch self {
        case .primary:
            return #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        case .gray:
            return #colorLiteral(red: 0.4197611213, green: 0.4559625387, blue: 0.5046361685, alpha: 1)
        case .red:
            return #colorLiteral(red: 0.7824426293, green: 0.03705377877, blue: 0.0794525817, alpha: 1)
        case .orange:
            return #colorLiteral(red: 0.972686708, green: 0.4337486923, blue: 0, alpha: 1)
        case .yellow:
            return #colorLiteral(red: 0.7707784772, green: 0.5830464363, blue: 0, alpha: 1)
        case .green:
            return #colorLiteral(red: 0.1315832138, green: 0.6066541672, blue: 0.2917357981, alpha: 1)
        case .blue:
            return #colorLiteral(red: 0.1193856075, green: 0.3272579312, blue: 0.9138609767, alpha: 1)
        case .purple:
            return #colorLiteral(red: 0.4117100239, green: 0.2406530976, blue: 0.7068317533, alpha: 1)
        }
    }
    
    public var color: UIColor {
        let lightMode = self._color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
    
        lightMode.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        lightMode.getRed(&red, green: &green, blue: &blue, alpha: nil)
        
        let inverted = UIColor(red: 1 - red, green: 1 - green, blue: 1 - blue, alpha: alpha)
        var invertedBrightness: CGFloat = 0
        inverted.getHue(nil, saturation: nil, brightness: &invertedBrightness, alpha: nil)
        
        let darkMode = UIColor(hue: hue, saturation: saturation, brightness: invertedBrightness, alpha: alpha)
        
        let provider: (UITraitCollection) -> UIColor = { traits in
            if traits.userInterfaceStyle == .dark {
                return darkMode
            } else {
                return lightMode
            }
        }
        return UIColor(dynamicProvider: provider)
    }
    
    public var pencilKitColor: UIColor {
        self._color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
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
    
    /// Find the closest color that adapts to light and dark mode for the given color
    public static func colorToSemanticColor(color: UIColor) -> SemanticColor {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        
        
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        
        // Using colors that are independent of the system theme, light or dark mode
        let red = #colorLiteral(red: 1, green: 0, blue: 0, alpha: 1)
        let green = #colorLiteral(red: 0, green: 1, blue: 0, alpha: 1)
        let blue = #colorLiteral(red: 0, green: 0, blue: 1, alpha: 1)
        // Have only a few color match options to prevent incorrect conversions
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
    @Published var paths: [PKStroke]? = nil
    
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
            self.paths = convertedPaths.map { (path, color) -> PKStroke in
                return PKStroke(ink: .init(.pen, color: color), path: path)
            }
        }
    }
    
    func getPaths() -> [PKStroke] {
        guard let paths = self.paths else { return [] }
        return paths.map { path in
            return PKStroke(ink: path.ink, path: path.path, transform: transform, mask: nil)
        }
    }
}
