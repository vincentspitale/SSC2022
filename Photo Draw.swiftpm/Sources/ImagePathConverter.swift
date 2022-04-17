//
//  ImagePathConverter.swift
//  
//
//  Created by Vincent Spitale on 4/12/22.
//

import Foundation
import UIKit
import SwiftUI
import simd

fileprivate struct Point: Hashable {
    let x,y: Int
}

/// Converts an image to paths for vector drawing using the process outlined by the paper
/// "A complete hand-drawn sketch vectorization framework" by L. Donati, S. Cesano, and A. Prati.
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
        
        let strokePixels: [Point] = [Point]() // TODO
        
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
                    if !Connectivity.instance.isRequiredForConnectivity(point: boundary, group: updatedGroup) {
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
            guard let initialPoint = centerLineSet.min(by: { (lhs, rhs) in
                return lhs.x + lhs.y < rhs.x + rhs.y
            }) else { return }
            
            // Breadth first search for the end of the path,
            // we're finding the nearest end of the line
            let deque = Deque<Point>()
            let findNeighbors: (Point) -> [Point] = { point in
                let up = Point(x: point.x, y: point.y - 1)
                let left = Point(x: point.x - 1, y: point.y)
                let right = Point(x: point.x + 1, y: point.y)
                let down = Point(x: point.x, y: point.y + 1)
                let topLeft = Point(x: point.x - 1, y: point.y - 1)
                let topRight = Point(x: point.x + 1, y: point.y - 1)
                let bottomLeft = Point(x: point.x - 1, y: point.y + 1)
                let bottomRight = Point(x: point.x + 1, y: point.y + 1)
                
                return [up, left, right, down, topLeft, topRight, bottomLeft, bottomRight].filter { neighbor in
                    centerLineSet.contains(neighbor)
                }
            }
            
            deque.addAtTail(initialPoint)
            var breadthVisited = Set<Point>()
            breadthVisited.insert(initialPoint)
            
            guard var currentPoint = deque.popFirst() else { return }
            while !Connectivity.instance.isEdge(point: currentPoint, group: centerLineSet) {
                let neighbors = findNeighbors(currentPoint).filter { !breadthVisited.contains($0) }
                for neighbor in neighbors {
                    deque.addAtTail(neighbor)
                }
                guard let nextPoint = deque.popFirst() else { break }
                currentPoint = nextPoint
                breadthVisited.insert(nextPoint)
            }
            // We found the starting point!
            // Now we have to search for paths from this point
            let startingPoint = currentPoint
            var depthVisited = Set<Point>()
            var stack: [Point] = []
            var currentDepth = startingPoint
            var currentPath: [Point] = [startingPoint]
            var centerLinePaths = [[Point]]()
            
            // Break paths into strokes
            while true {
                let neighbors = findNeighbors(currentDepth)
                stack.append(contentsOf: neighbors.filter { !depthVisited.contains($0) })
                guard let nextPoint = stack.popLast() else { break }
                // If there are more than two neighbors, we must split into two separate paths to have both paths be lines
                if neighbors.contains(nextPoint) && neighbors.count < 3 {
                    currentPath.append(nextPoint)
                    currentDepth = nextPoint
                    depthVisited.insert(nextPoint)
                } else {
                    centerLinePaths.append(currentPath)
                    currentPath = [nextPoint]
                    currentDepth = nextPoint
                    depthVisited.insert(nextPoint)
                }
            }
            centerLinePaths.append(currentPath)
            paths[index] = centerLinePaths
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


fileprivate class Connectivity {
    // We create a singleton so the matrices only have to be computed once
    static let instance = Connectivity()
    private let queue = DispatchQueue(label: "connectivity", qos: .userInitiated, autoreleaseFrequency: .workItem, target: nil)
    
    // These matrices are compared to a point's neighbors matrix. If any of these
    // matrices match the neighbors matrix, that point is an edge pixel of a path.
    //
    // Reading matrix values:
    // 0 means that there must not be a path pixel there.
    // 1 means that there must be a path pixel there.
    // -1 indicates that it does not matter if there is a path pixel there.
    private lazy var _edgeMasks: [simd_float3x3] = {
        let lastHorizontal: simd_float3x3 = {
            let col0 = simd_float3(0, 0, 0)
            let col1 = simd_float3(1, 1, 0)
            let col2 = simd_float3(0, 0, 0)
            return simd_float3x3(col0, col1, col2)
        }()
        
        return fourRotations(matrix: lastHorizontal)
    }()
    
    private var edgeMasks: [simd_float3x3] {
        // Prevent the variable from being accessed from a different thread before it's initialized
        queue.sync {
            return _edgeMasks
        }
    }
    
    private func fourRotations(matrix: simd_float3x3) -> [simd_float3x3] {
        func rotateMatrix(matrix: simd_float3x3) -> simd_float3x3 {
            let (col0, col1, col2) = matrix.columns
            let newCol0 = simd_float3(col0.z, col1.z, col2.z)
            let newCol1 = simd_float3(col0.y, col1.y, col2.y)
            let newCol2 = simd_float3(col0.x, col1.x, col2.x)
            return simd_float3x3(newCol0, newCol1, newCol2)
        }
        
        let rot0 = matrix
        let rot1 = rotateMatrix(matrix: matrix)
        let rot2 = rotateMatrix(matrix: rot1)
        let rot3 = rotateMatrix(matrix: rot2)
        return [rot0, rot1, rot2, rot3]
    }
    
    // These matrices are compared to a point's neighbors matrix. If any of these
    // matrices match the neighbors matrix, that point is required to maintain path
    // connectivity.
    //
    // Reading matrix values:
    // 0 means that there must not be a path pixel there.
    // 1 means that there must be a path pixel there.
    // -1 indicates that it does not matter if there is a path pixel there.
    private lazy var _hitMissMasks: [simd_float3x3] = {
        var masks = [simd_float3x3]()
        
        let horizontal: simd_float3x3 = {
            let col0 = simd_float3(0, 0, 0)
            let col1 = simd_float3(1, 1, 0)
            let col2 = simd_float3(0, 0, 0)
            return simd_float3x3(col0, col1, col2)
        }()
        
        let topLeft: simd_float3x3 = {
            let col0 = simd_float3(1, -1, -1)
            let col1 = simd_float3(-1, 1, 0)
            let col2 = simd_float3(-1, 0, 1)
            return simd_float3x3(col0, col1, col2)
        }()
        
        let topCenter: simd_float3x3 = {
            let col0 = simd_float3(-1, -1, -1)
            let col1 = simd_float3(1, 1, 0)
            let col2 = simd_float3(-1, 0, 1)
            return simd_float3x3(col0, col1, col2)
        }()
        
        let topRight: simd_float3x3 = {
            let col0 = simd_float3(-1, 0, 1)
            let col1 = simd_float3(1, 1, 0)
            let col2 = simd_float3(-1, -1, -1)
            return simd_float3x3(col0, col1, col2)
        }()
        
        let bottomLeft0: simd_float3x3 = {
            let col0 = simd_float3(-1, 0, -1)
            let col1 = simd_float3(1, 1, 1)
            let col2 = simd_float3(-1, 0, -1)
            return simd_float3x3(col0, col1, col2)
        }()
        
        let bottomLeft1: simd_float3x3 = {
            let col0 = simd_float3(-1, 1, -1)
            let col1 = simd_float3(0, 1, 0)
            let col2 = simd_float3(-1, 1, -1)
            return simd_float3x3(col0, col1, col2)
        }()
        
        let bottomMiddle: simd_float3x3 = {
            let col0 = simd_float3(-1, 0, 1)
            let col1 = simd_float3(-1, 1, 0)
            let col2 = simd_float3(-1, 0, 1)
            return simd_float3x3(col0, col1, col2)
        }()
        
        let bottomRight: simd_float3x3 = {
            let col0 = simd_float3(-1, 1, -1)
            let col1 = simd_float3(1, 1, 1)
            let col2 = simd_float3(-1, 1, -1)
            return simd_float3x3(col0, col1, col2)
        }()
        
        masks.append(contentsOf: fourRotations(matrix: horizontal))
        masks.append(contentsOf: fourRotations(matrix: topLeft))
        masks.append(contentsOf: fourRotations(matrix: topCenter))
        masks.append(contentsOf: fourRotations(matrix: topRight))
        masks.append(bottomLeft0)
        masks.append(bottomLeft1)
        masks.append(contentsOf: fourRotations(matrix: bottomMiddle))
        masks.append(bottomRight)
        
        return masks
    }()
    
    private var hitMissMasks: [simd_float3x3] {
        // Prevent the variable from being accessed from a different thread before it's initialized
        self.queue.sync {
            return _hitMissMasks
        }
    }
    
    private func isRequired(point: Point, group: Set<Point>) -> (simd_float3x3) -> Bool {
        let up = Point(x: point.x, y: point.y - 1)
        let left = Point(x: point.x - 1, y: point.y)
        let right = Point(x: point.x + 1, y: point.y)
        let down = Point(x: point.x, y: point.y + 1)
        let topLeft = Point(x: point.x - 1, y: point.y - 1)
        let topRight = Point(x: point.x + 1, y: point.y - 1)
        let bottomLeft = Point(x: point.x - 1, y: point.y + 1)
        let bottomRight = Point(x: point.x + 1, y: point.y + 1)
        
        let col0 = [topLeft, left, bottomLeft].map { group.contains($0) }.map { $0 ? Int(1) : Int(0)}
        let col1 = [up, point, down].map { group.contains($0) }.map { $0 ? Int(1) : Int(0)}
        let col2 = [topRight, right, bottomRight].map { group.contains($0) }.map { $0 ? Int(1) : Int(0)}
        let columns = [col0, col1, col2]
        
        // Closure compares a given matrix to the 3x3 grid of pixels surrounding a point
        let isRequired: (simd_float3x3) -> Bool = { matrix in
            let (hitCol0, hitCol1, hitCol2) = matrix.columns
            let hitColumns = [hitCol0, hitCol1, hitCol2]
            for (hit, col) in zip(hitColumns, columns) {
                let (x, y, z) = (hit.x, hit.y, hit.z)
                let hitArray = [Int(x), Int(y), Int(z)]
                for (hitNum, colNum) in zip(hitArray, col) {
                    guard hitNum >= 0 else { continue }
                    if hitNum != colNum {
                        return false
                    }
                }
            }
            return true
        }
        return isRequired
    }
    
    func isEdge(point: Point, group: Set<Point>) -> Bool {
        let isRequired = self.isRequired(point: point, group: group)
        return edgeMasks.contains { isRequired($0) }
    }
    
    func isRequiredForConnectivity(point: Point, group: Set<Point>) -> Bool {
        let isRequired = self.isRequired(point: point, group: group)
        return hitMissMasks.contains { isRequired($0) }
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
