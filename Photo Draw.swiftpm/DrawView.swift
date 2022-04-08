//
//  File.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/6/22.
//

import Foundation
import SwiftUI

struct DrawView: View {
    @ObservedObject var windowState: CanvasState
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    
    let columns = [
        GridItem(.adaptive(minimum: 30))
    ]
    
    
    var body: some View {
        ZStack{
            Rectangle()
                .foregroundColor(Color(uiColor: UIColor.systemGray6))
                .transition(.opacity)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation{ self.windowState.isShowingColorPicker = false }
                }
            VStack{
                if horizontalSizeClass == .compact {
                    Spacer()
                    self.colorPicker()
                        .padding()
                }
                ZStack {
                    RoundedRectangle(cornerRadius: .greatestFiniteMagnitude, style: .continuous)
                        .foregroundColor(Color(uiColor: UIColor.systemGray5))
                    HStack {
                        Spacer()
                        if windowState.selection == nil {
                            self.controls()
                        }
                        Button(action: {windowState.currentTool = .selection}) {
                            Image(systemName: "lasso")
                                .font(.largeTitle)
                                .foregroundColor(windowState.currentTool == .selection ? .primary : .secondary)
                            
                                .frame(width: 50)
                        }
                        .accessibilityLabel("Select")
                        .accessibility(addTraits: self.windowState.currentTool == .selection ? .isSelected : [])
                        Spacer()
                    }
                }
                .frame(minWidth: nil, idealWidth: 400, maxWidth: 400, minHeight: nil, idealHeight: 70, maxHeight: 70, alignment: .center)
                .padding(.horizontal)
                if horizontalSizeClass != .compact {
                    self.colorPicker()
                        .padding()
                    Spacer()
                }
            }
            
            
        }
    }
    
    @ViewBuilder func controls() -> some View {
        Button(action: {windowState.currentTool = .touch}) {
            Image(systemName: "hand.point.up")
                .font(.largeTitle)
                .foregroundColor(windowState.currentTool == .touch ? .primary : .secondary)
                .frame(width: 50)
        }
        .accessibilityLabel("Touch")
        .accessibility(addTraits: self.windowState.currentTool == .touch ? .isSelected : [])
        Spacer()
        Button(action: {penAction()}) {
            ZStack {
                Image(systemName: "pencil.tip")
                    .font(.largeTitle)
                    .foregroundColor(windowState.currentTool == .pen ? .primary : .secondary)
                Image(systemName: "pencil.tip")
                    .font(.largeTitle)
                    .foregroundColor(Color(uiColor: windowState.currentColor.color))
                    .mask(VStack{
                        Rectangle()
                            .foregroundColor(.white)
                            .frame(height: 15)
                        Spacer()
                    })
                    .opacity(windowState.currentTool == .pen ? 100 : 0)
            }
            .frame(width: 50)
        }
        .accessibilityLabel("Pen")
        .accessibilityValue(Text(windowState.currentColor.name(isDark: colorScheme == .dark)))
        .accessibility(addTraits: self.windowState.currentTool == .pen ? .isSelected : [])
        Spacer()
        Button(action: {}) {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(.accentColor)
            
                .frame(width: 50)
        }
        .accessibilityLabel("Add Photo")
        Spacer()
        Button(action: {windowState.currentTool = .remove}) {
            ZStack{
                Image(systemName: "scribble")
                    .font(.largeTitle)
                    .foregroundColor(windowState.currentTool == .remove ? .primary : .secondary)
                Image(systemName: "line.diagonal")
                    .font(.largeTitle)
                    .foregroundColor(windowState.currentTool == .remove ? Color.red : Color(uiColor: UIColor.systemGray3))
                
            }
            .frame(width: 50)
        }
        .accessibilityLabel("Remove")
        .accessibility(addTraits: self.windowState.currentTool == .remove ? .isSelected : [])
        Spacer()
    }
    
    @ViewBuilder func colorPicker() -> some View {
        
        if self.windowState.isShowingColorPicker {
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(SemanticColor.allCases, id: \.self) { color in
                    Button(action: { self.windowState.currentColor = color  }) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .foregroundColor(Color(uiColor: color.color))
                            .frame(width: 30, height: 30)
                            .overlay{
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color.accentColor, lineWidth: self.windowState.currentColor == color ? 3 : 0)
                            }
                    }
                    .accessibilityLabel(Text(color.name(isDark: colorScheme == .dark)))
                    .accessibility(addTraits: self.windowState.currentColor == color ? .isSelected : [])
                }
            }
            .padding()
            .background{
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .foregroundColor(Color(uiColor: .systemGray5))
            }
            .frame(minWidth: nil, idealWidth: 200, maxWidth: 200, alignment: .center)
            .transition(.scale.combined(with: .opacity).combined(with: .move(edge: self.horizontalSizeClass == .compact ? .bottom : .top)))
        }
    }
    
    func penAction() -> Void {
        if windowState.currentTool == .pen {
            withAnimation{windowState.isShowingColorPicker.toggle()}
        } else {
            windowState.currentTool = .pen
        }
    }
}
