//
//  Path+VectorBoolean.swift
//  BezierKit
//
//  Created by Holmes Futrell on 2/8/21.
//  Copyright © 2021 Holmes Futrell. All rights reserved.
//

#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

public extension Path {

    func subtract(_ other: Path, accuracy: CGFloat=defaultIntersectionAccuracy) -> Path {
        return self.performBooleanOperation(.subtract, with: other.reversed(), accuracy: accuracy)
    }

    func `union`(_ other: Path, accuracy: CGFloat=defaultIntersectionAccuracy) -> Path {
        guard self.isEmpty == false else {
            return other
        }
        guard other.isEmpty == false else {
            return self
        }
        return self.performBooleanOperation(.union, with: other, accuracy: accuracy)
    }

    func intersect(_ other: Path, accuracy: CGFloat=defaultIntersectionAccuracy) -> Path {
        return self.performBooleanOperation(.intersect, with: other, accuracy: accuracy)
    }

    func crossingsRemoved(accuracy: CGFloat=defaultIntersectionAccuracy) -> Path {
        let intersections = self.selfIntersections(accuracy: accuracy)
        let augmentedGraph = AugmentedGraph(path1: self, path2: self, intersections: intersections, operation: .removeCrossings)
        return augmentedGraph.performOperation()
    }
}

private extension Path {
    func performBooleanOperation(_ operation: BooleanPathOperation, with other: Path, accuracy: CGFloat) -> Path {
        let intersections = self.intersections(with: other, accuracy: accuracy)
        let augmentedGraph = AugmentedGraph(path1: self, path2: other, intersections: intersections, operation: operation)
        return augmentedGraph.performOperation()
    }
}
