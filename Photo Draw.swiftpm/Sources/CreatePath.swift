//
//  CreatePath.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/10/22.
//

import Foundation
import CoreGraphics
import PencilKit

class CreatePath {
    // Fits the point data to a cubic b-spline path
    static func pathFromPoints(_ points: [CGPoint]) -> PKStrokePath {
        // TODO
        let controlPoints = points.map { point in
            PKStrokePoint(location: point, timeOffset: 0, size: CGSize(width: 3, height: 3), opacity: 1, force: 2, azimuth: 0, altitude: 0)
        }
        return PKStrokePath(controlPoints: controlPoints, creationDate: Date())
    }
}

