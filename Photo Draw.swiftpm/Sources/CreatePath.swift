//
//  CreatePath.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/10/22.
//

import CoreGraphics
import Foundation

class CreatePath {
    // Fits the point data to a path of line segments for simplicity
    // In the future, this could create smooth cubic Bezier curves
    // using the break-and-fit strategy
    static func pathFromPoints(_ points: [CGPoint]) -> Path {
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
    
    static func simplifiedPathFromPoints(_ points: [CGPoint]) -> Path {
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

