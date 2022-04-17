//
//  ImagePathConverter.swift
//  
//
//  Created by Vincent Spitale on 4/12/22.
//

import Foundation
import UIKit
import SwiftUI

fileprivate struct Point: Hashable {
    let x,y: Int
    
    func isRequiredForConnectivity(group: Set<Point>) -> Bool {
        #warning("Implement")
    }
}

/// Converts an image to paths for vector drawing
class ImagePathConverter {
    struct Pixel {
        let x, y: Int
        let r, g, b, a: UInt8
    }

    let image: UIImage
    
    private lazy var groupedConnectedPixels: [Set<Point>] = {
        self.findGroupedConnectedPixels()
    }()
    
    private lazy var centerLines: [Set<Point>] = {
        self.findCenterLines()
    }()
    
    private lazy var rgbaPixelData: [UInt8]? = {
        image.rgbaPixelData()
    }()
    
    init(image: UIImage) {
        self.image = image
    }
    
    /// Converts the provided image to paths with each path's average color
    public func findPaths() -> [(Path, UIColor)] {
        let centerLinePaths = self.findCenterLinePaths()
        // Paths converted to bezier curves by least squares
        var pathColors = [[(Path, UIColor)]](repeating: [], count: centerLinePaths.count)
        
        DispatchQueue.concurrentPerform(iterations: centerLinePaths.count) { index in
            let path = centerLinePaths[index]
            let color: UIColor = averageColor(path: path)
            let pointData = path.map { CGPoint(x:CGFloat($0.x), y: CGFloat($0.y))}
            pathColors[index] = [(LeastSquaresPath.pathFromPoints(pointData), color)]
        }
        
        return pathColors.flatMap { $0 }
    }
    
    private func pixelAtPoint(_ p: Point) -> Pixel? {
        let imageIndex: Int = (p.y * Int(image.size.width)) + p.x
        guard let pixelData = rgbaPixelData, imageIndex >= 0 && imageIndex < Int(image.size.width * image.size.height) else {
            return nil
        }
        let r = pixelData[imageIndex * 4]
        let g = pixelData[imageIndex * 4 + 1]
        let b = pixelData[imageIndex * 4 + 2]
        let a = pixelData[imageIndex * 4 + 3]
        return Pixel(x: p.x, y: p.y, r: r, g: g, b: b, a: a)
    }
    
    private func findGroupedConnectedPixels() -> [Set<Point>] {
        
        #warning("Implement")
        // Use covariance kernel to find lines in the image
        
        // Find how many white pixels are in the resulting image
        
        // Create a buffer that can hold as many points as there are white pixels
        
        // Copy the point locations using the gpu.
        // This parallelizes detecting if a pixel should be added,
        // making things much faster!
        
        let strokePixels: [Point] = [Point]() // TO DO
        
        // Iterate through points to separate into groups with union-find
        var groupMap = [Point : Point]()
        for point in strokePixels {
            groupMap[point] = point
        }
        // The top-leftmost pixel in the stroke should be the starting point of the stroke
        for point in strokePixels {
            // Neighboring pixels we're interested in
            let topLeft = Point(x: point.x - 1, y: point.y - 1)
            let topMiddle = Point(x: point.x, y: point.y - 1)
            let topRight = Point(x: point.x + 1, y: point.y - 1)
            let left = Point(x: point.x - 1, y: point.y)
            if let newPoint = [topLeft, topMiddle, topRight, left].compactMap({ neighbor -> Point? in
                guard groupMap[neighbor] != nil else { return nil }
                var start = point
                while groupMap[start] != start {
                    if let newStart = groupMap[start] {
                        start = newStart
                    }
                }
                return start
            }).sorted(by: { (lhs, rhs) in
                // we want to find the top-leftmost pixel
                if lhs.x == rhs.x {
                    return lhs.y < rhs.y
                }
                return lhs.x < rhs.x
            }).first {
                // update where this pixel points to
                groupMap[point] = newPoint
                // update neighbors pointers as well
                if let topLeftPoint = groupMap[topLeft] {
                    groupMap[topLeftPoint] = newPoint
                    groupMap[topLeft] = newPoint
                }
                if let topMiddlePoint = groupMap[topMiddle] {
                    groupMap[topMiddlePoint] = newPoint
                    groupMap[topMiddle] = newPoint
                }
                if let topRightPoint = groupMap[topRight] {
                    groupMap[topRightPoint] = newPoint
                    groupMap[topRight] = newPoint
                }
                if groupMap[left] != nil {
                    groupMap[left] = newPoint
                }
            }
        }
        var groups = [Point: Set<Point>]()
        for point in strokePixels {
            if let referencedPoint = groupMap[point] {
                var start = referencedPoint
                while groupMap[start] != start {
                    if let newStart = groupMap[start] {
                        start = newStart
                    }
                }
                groups[start, default: Set<Point>()].insert(point)
            }
        }
        
        return Array(groups.values)
    }
    
    private func findCenterLines() -> [Set<Point>] {
        var centerLines = [Set<Point>](repeating: Set<Point>(), count: groupedConnectedPixels.count)
        DispatchQueue.concurrentPerform(iterations: groupedConnectedPixels.count) { index in
            let group = groupedConnectedPixels[index]
            var boundaries = Set<Point>()
            for point in group {
                let up = Point(x: point.x, y: point.y - 1)
                let left = Point(x: point.x - 1, y: point.y)
                let right = Point(x: point.x + 1, y: point.y)
                let down = Point(x: point.x, y: point.y + 1)
                // if any direct neighbors are not in the group, this is a boundary pixel
                if [up, left, right, down].contains(where: { !group.contains($0) }) {
                    boundaries.insert(point)
                }
            }
            var updatedBoundaries = boundaries
            var updatedGroup = group
            var didChange: Bool = true
            while didChange {
                didChange = false
                let currentBoundaries = updatedBoundaries
                for boundary in currentBoundaries {
                    guard updatedBoundaries.contains(boundary) else { continue }
                    if !boundary.isRequiredForConnectivity(group: updatedGroup) {
                        didChange = true
                        
                        let up = Point(x: boundary.x, y: boundary.y - 1)
                        let left = Point(x: boundary.x - 1, y: boundary.y)
                        let right = Point(x: boundary.x + 1, y: boundary.y)
                        let down = Point(x: boundary.x, y: boundary.y + 1)
                        let topLeft = Point(x: boundary.x - 1, y: boundary.y - 1)
                        let topRight = Point(x: boundary.x + 1, y: boundary.y - 1)
                        let downLeft = Point(x: boundary.x - 1, y: boundary.y + 1)
                        let downRight = Point(x: boundary.x + 1, y: boundary.y + 1)
                        
                        for neighbor in [up, left, right, down, topLeft, topRight, downLeft, downRight] {
                            if updatedGroup.contains(neighbor) {
                                updatedBoundaries.insert(neighbor)
                            }
                        }
                        updatedBoundaries.remove(boundary)
                        updatedGroup.remove(boundary)
                    }
                }
            }
            
            centerLines[index] = updatedGroup
        }
        
        return centerLines
    }
    
    private func findCenterLinePaths() -> [[Point]] {
        // Allow an arbitrary number of paths to be generated from each center line
        var paths = [[[Point]]](repeating: [], count: centerLines.count)
        DispatchQueue.concurrentPerform(iterations: centerLines.count) { index in
            let centerLineSet = centerLines[index]
            guard let startingPoint = centerLineSet.min(by: { (lhs, rhs) in
                return lhs.x + lhs.y < rhs.x + rhs.y
            }) else { return }
            
            // depth first search for the end of the path
            var startStack = [Point]()
            
        
        }
        return paths.flatMap { $0 }
    }
    

    
    private func averageColor(path: [Point]) -> UIColor {
        let numSamplePoints = min(10, path.count)
        var sampleIndices = [Int]()
        // Select random sample points along the center line path
        for _ in 0..<numSamplePoints {
            let randomIndex = Int.random(in: 0..<path.count)
            sampleIndices.append(randomIndex)
        }
        // Use the image data to get the color at each point
        let sampleColors = sampleIndices.compactMap { index -> (r: CGFloat, g: CGFloat, b: CGFloat)? in
            let samplePoint = path[index]
            guard let pixel = pixelAtPoint(samplePoint) else { return nil }
            return (CGFloat(pixel.r) / 255.0, CGFloat(pixel.g) / 255.0 , CGFloat(pixel.b) / 255.0 )
        }
        // Add all of the sample colors
        let sumColors = sampleColors.reduce(into: (r: 0.0, g: 0.0, b: 0.0), { colorSum, color in
            colorSum = (colorSum.r + color.r, colorSum.g + color.g, colorSum.b + color.b)
        })
        // Find the average color
        let averageColor = UIColor(red: sumColors.r / CGFloat(numSamplePoints), green: sumColors.g / CGFloat(numSamplePoints), blue: sumColors.b / CGFloat(numSamplePoints), alpha: 1.0)
        return averageColor
    }
}

fileprivate extension UIImage {
    // Use core graphics to quickly fill an array with pixel data the cpu can access
    func rgbaPixelData() -> [UInt8]? {
        let size = self.size
        var pixelData = [UInt8](repeating: 0, count: Int(size.width * size.height * 4))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData, width: Int(size.width), height: Int(size.height),
                                bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgImage = self.cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return pixelData
    }
}

fileprivate class CovarianceKernel {
    private let image: UIImage
    
    //private let imageTexture: MTLTexture
    //private let outputTexture: MTLTexture
    //private let device: MTLDevice
    
    
    init(image: UIImage) {
        self.image = image
    }
    
}
