//
//  LeastSquaresPath.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/10/22.
//

import BezierKit
import CoreGraphics
import Foundation

class LeastSquaresPath {
    private static var errorThreshold: CGFloat = 7.0
    // Fits the point data to cubic bezier curves
    static func pathFromPoints(_ points: [CGPoint]) -> BezierKit.Path {
        var pathSoFar = [BezierKit.CubicCurve]()
        
        
        
        return BezierKit.Path(components: pathSoFar.map {
            PathComponent(curve: $0)
        })
    }
}
