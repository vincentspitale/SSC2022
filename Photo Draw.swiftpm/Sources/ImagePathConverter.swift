//
//  ImagePathConverter.swift
//  
//
//  Created by Vincent Spitale on 4/12/22.
//

import Foundation
import UIKit
import MetalKit
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
        
        // Use covariance kernel to find lines in the image
        guard let device = MTLCreateSystemDefaultDevice(), let cgImage = image.cgImage,         let library = device.makeDefaultLibrary() else { return [] }
        let textureManager = TextureManager(device: device)
        guard let covarianceFilter = try? CovarianceKernel(cgImage: cgImage, library: library, textureManger: textureManager), let outputImage = try? covarianceFilter.applyKernel() else { return [] }
        
        // Find how many white pixels are in the resulting image
        // Create a buffer that can hold as many points as there are white pixels
        
        // Copy the point locations using the gpu.
        // This parallelizes detecting if a pixel should be added,
        // making things much faster!
        guard let streamCompaction = try? ImageStreamCompaction(cgImage: outputImage, library: library, textureManager: textureManager) else { return [] }
        
        let strokePixels: [Point] = streamCompaction.getWhitePoints()
        let strokesSet: Set<Point> = Set<Point>(strokePixels)
        
        // Iterate through points to separate into connected stroke components
        // with depth first search
        var groups = [Set<Point>]()
        var visited = Set<Point>()
        for point in strokePixels {
            guard !visited.contains(point) else { continue }
            var stroke = Set<Point>()
            stroke.insert(point)
            var searchPoints = [point]
            while !searchPoints.isEmpty {
                guard let searchPoint = searchPoints.popLast() else { break }
                // Neighboring pixels we're interested in
                let up = Point(x: searchPoint.x, y: searchPoint.y - 1)
                let left = Point(x: searchPoint.x - 1, y: searchPoint.y)
                let right = Point(x: searchPoint.x + 1, y: searchPoint.y)
                let down = Point(x: searchPoint.x, y: searchPoint.y + 1)
                let newPoints = [up, left, right, down].filter { neighbor in
                    strokesSet.contains(neighbor) && !visited.contains(neighbor)
                }
                searchPoints.append(contentsOf: newPoints)
                stroke.insert(searchPoint)
                visited.insert(searchPoint)
            }
            groups.append(stroke)
        }
        
        return groups
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


fileprivate class TextureManager {
    enum TextureErrors: Error {
        case cgImageConversionFailed
        case textureCreationFailed
    }
    
    private let textureLoader: MTKTextureLoader
    
    init(device: MTLDevice) {
        self.textureLoader = MTKTextureLoader(device: device)
    }
    
    func texture(cgImage: CGImage, usage: MTLTextureUsage = [.shaderRead, .shaderWrite]) throws -> MTLTexture {
        let options: [MTKTextureLoader.Option : Any] = [
            .textureUsage: NSNumber(value: usage.rawValue),
            .generateMipmaps: NSNumber(value: false),
            .SRGB: NSNumber(value: false)
        ]
        return try self.textureLoader.newTexture(cgImage: cgImage, options: options)
    }
    
    func cgImage(texture: MTLTexture) throws -> CGImage {
        let bytesPerRow = texture.width * 4 // r,g,b,a
        let bytesLength = bytesPerRow * texture.height
        let rgbaBytes = UnsafeMutableRawPointer.allocate(byteCount: bytesLength, alignment: MemoryLayout<UInt8>.alignment)
        defer { rgbaBytes.deallocate() }
        
        let region = MTLRegion(origin: .init(x: 0, y: 0, z: 0), size: .init(width: texture.width, height: texture.height, depth: texture.depth))
        
        texture.getBytes(rgbaBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitMapInfo = CGBitmapInfo(rawValue: CGImageByteOrderInfo.order32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        guard let data = CFDataCreate(nil, rgbaBytes.assumingMemoryBound(to: UInt8.self), bytesLength),
              let dataProvider = CGDataProvider(data: data),
              let cgImage = CGImage(width: texture.width, height: texture.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitMapInfo, provider: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            throw TextureErrors.cgImageConversionFailed
        }
        return cgImage
    }
    
    func createMatchingTexture(texture: MTLTexture) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.width = texture.width
        descriptor.height = texture.height
        descriptor.pixelFormat = texture.pixelFormat
        descriptor.storageMode = texture.storageMode
        descriptor.usage = texture.usage
        
        guard let matchingTexture = self.textureLoader.device.makeTexture(descriptor: descriptor) else { throw TextureErrors.textureCreationFailed }
        return matchingTexture
    }
}

fileprivate final class CovarianceKernel {
    private let device: MTLDevice
    
    private let textureManager: TextureManager
    private let imageTexture: MTLTexture
    private let outputTexture: MTLTexture
    
    private let pipelineState: MTLComputePipelineState
    
    
    init(cgImage: CGImage, library: MTLLibrary, textureManger: TextureManager) throws {
        self.device = library.device
        let function = try library.makeFunction(name: "covariance_filter", constantValues: MTLFunctionConstantValues())
        self.pipelineState = try library.device.makeComputePipelineState(function: function)
        self.textureManager = textureManger
        let inputTexture = try textureManger.texture(cgImage: cgImage)
        self.imageTexture = inputTexture
        self.outputTexture = try textureManger.createMatchingTexture(texture: inputTexture)
    }
    
    private func encode(source: MTLTexture, destination: MTLTexture, in commandBuffer: MTLCommandBuffer) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        
        encoder.setComputePipelineState(self.pipelineState)
        encoder.endEncoding()
    }
    
    func applyKernel() throws -> CGImage {
        #warning("implement")
        return try textureManager.cgImage(texture: outputTexture)
    }
    
}

fileprivate final class ImageStreamCompaction {
    private let device: MTLDevice
    private let textureManager: TextureManager
    private let inputTexture: MTLTexture
    private let outputBuffer: MTLBuffer
    
    init(cgImage: CGImage, library: MTLLibrary, textureManager: TextureManager) throws {
        self.device = library.device
        self.textureManager = textureManager
        self.inputTexture = try textureManager.texture(cgImage: cgImage)
        // stream compaction function
        
    }
    
    func getWhitePoints() -> [Point] {
        #warning("implement")
        let data = outputBuffer.contents().assumingMemoryBound(to: Float32.self)
        return []
    }
}
