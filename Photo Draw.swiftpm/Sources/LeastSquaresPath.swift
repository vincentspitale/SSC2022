//
//  LeastSquaresPath.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/10/22.
//

import BezierKit
import CoreGraphics
import Foundation

// Break-and-fit cubic bezier fitting strategy
class LeastSquaresPath {
    private static var errorThreshold: CGFloat = 7.0
    // Fits the point data to cubic bezier curves
    static func pathFromPoints(_ points: [CGPoint]) -> BezierKit.Path {
        var pathSoFar = [BezierKit.CubicCurve]()
        
        #warning("Implement")
        
        return BezierKit.Path(components: pathSoFar.map {
            PathComponent(curve: $0)
        })
    }
}
