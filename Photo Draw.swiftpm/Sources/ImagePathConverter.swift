//
//  ImagePathConverter.swift
//  
//
//  Created by Vincent Spitale on 4/12/22.
//

import Foundation
import UIKit

fileprivate struct Point: Hashable {
    let x,y: Int
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
        return centerLinePaths.map { path in
            let color: UIColor = averageColor(path: path)
            let pointData = path.map { CGPoint(x:CGFloat($0.x), y: CGFloat($0.y))}
            return (LeastSquaresPath.pathFromPoints(pointData), color)
        }
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
        
        // Create set of points from the buffer
        
        // Iterate through points to separate into groups with DFS
        
        
        return []
    }
    
    private func findCenterLinePaths() -> [[Point]] {
        #warning("Implement")
        return []
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
