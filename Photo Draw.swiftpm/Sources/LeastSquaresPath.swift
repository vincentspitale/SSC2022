//
//  LeastSquaresPath.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/10/22.
//

import Algorithms
import BezierKit
import CoreGraphics
import Foundation

// Break-and-fit cubic bezier fitting strategy
class LeastSquaresPath {
    private static var errorThreshold: CGFloat = 7.0
    // Fits the point data to cubic bezier curves
    static func pathFromPoints(_ points: [CGPoint]) -> BezierKit.Path {
        #warning("Implement Smooth Bezier")
        /*
        var pathSoFar = [BezierKit.CubicCurve]()
        
        #warning("Implement")
        
        return BezierKit.Path(components: pathSoFar.map {
            PathComponent(curve: $0)
        })
         */
        let components = points.windows(ofCount: 2).compactMap { chunk -> LineSegment? in
            guard chunk.count == 2 else { return nil }
            var p0: CGPoint? = nil
            var p1: CGPoint? = nil
            _ = chunk.enumerated().map { index, point in
                if index == 0 {
                    p0 = point
                } else {
                    p1 = point
                }
            }
            guard let p0 = p0, let p1 = p1 else { return nil }
            return LineSegment(p0: p0, p1: p1)
        }.map {
            PathComponent(curve: $0)
        }
        return BezierKit.Path(components: components)
    }
}
