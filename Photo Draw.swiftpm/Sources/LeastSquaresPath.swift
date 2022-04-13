//
//  LeastSquaresPath.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/10/22.
//

import CoreGraphics
import Foundation

// Break-and-fit cubic bezier fitting strategy
class LeastSquaresPath {
    private static var errorThreshold: CGFloat = 7.0
    // Fits the point data to cubic bezier curves
    static func pathFromPoints(_ points: [CGPoint]) -> Path {
        #warning("Implement Smooth Bezier")
        /*
        var pathSoFar = [BezierKit.CubicCurve]()
        
        #warning("Implement")
        
        return BezierKit.Path(components: pathSoFar.map {
            PathComponent(curve: $0)
        })
         */
        var windows = [(p0: CGPoint, p1: CGPoint)]()
        _ = points.reduce(into: CGPoint?.none, { last, point in
            if let last = last, point != last {
                windows.append((p0: last, p1: point))
            }
            last = point
        })
        let components = windows.compactMap { (p0, p1) -> LineSegment? in
            return LineSegment(p0: p0, p1: p1)
        }.map {
            PathComponent(curve: $0)
        }
        return Path(components: components)
    }
}

