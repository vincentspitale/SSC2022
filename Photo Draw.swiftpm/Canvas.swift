//
//  Canvas.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/6/22.
//

import Foundation
import UIKit

class Canvas: UIViewController {
    var state: CanvasState
    
    init(state: CanvasState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
