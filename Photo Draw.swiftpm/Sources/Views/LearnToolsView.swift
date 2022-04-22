//
//  LearnToolsView.swift
//  
//
//  Created by Vincent Spitale on 4/13/22.
//

import SwiftUI

struct LearnToolsView: View {
    let toolFont: Font = {
        Font.system(size: 80)
    }()
    
    let toolColumns = [
        GridItem(.adaptive(minimum: 150))
    ]
    
    var body: some View {
        VStack{
            Spacer().frame(height: 100)
            HStack{
                Spacer()
            }
            VStack {
                Spacer()
                VStack(alignment: .leading) {
                    Text("Your Drawing Tools").font(.title)
                        .bold()
                        .padding(.bottom, 40)
                    LazyVGrid(columns: toolColumns, alignment: .leading, spacing: 5) {
                    VStack(alignment: .leading) {
                        Image(systemName: "hand.point.up").font(toolFont)
                            .foregroundColor(.secondary)
                            .frame(width: 100)
                            .padding(.bottom, 20)
                                Text("Touch")
                                .font(.title2).bold()
                                    .foregroundColor(.accentColor)
                                    .padding(.bottom, 3)
                                Text("Move around the canvas")
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.primary)
                        }
                        .padding(.bottom, 40)
                        VStack(alignment: .leading) {
                        ZStack {
                            Image(systemName: "pencil.tip")
                                .font(toolFont)
                                .foregroundColor(.secondary)
                            // Overlay example color
                            Image(systemName: "pencil.tip")
                                .font(toolFont)
                                .foregroundColor(Color(uiColor: SemanticColor.purple.color))
                                .mask(VStack{
                                    Rectangle()
                                        .foregroundColor(.white)
                                        .frame(height: 34)
                                    Spacer()
                                })
                        }
                        .frame(width: 100)
                        .padding(.bottom, 20)
                                Text("Pen")
                                .font(.title2).bold()
                                    .foregroundColor(.accentColor)
                                    .padding(.bottom, 3)
                                Text("Tap the pen to reveal color options")
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.primary)
                        }
                        .padding(.bottom, 40)
                        VStack(alignment: .leading) {
                        Image(systemName: "photo").font(toolFont)
                            .foregroundColor(.secondary)
                            .frame(width: 100)
                            .padding(.bottom, 20)
                                Text("Add Photo")
                                .font(.title2).bold()
                                    .foregroundColor(.accentColor)
                                    .padding(.bottom, 3)
                                Text("Convert a photo to digital ink")
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.primary)
                        }
                            .padding(.bottom, 40)
                        VStack(alignment: .leading) {
                        ZStack{
                            Image(systemName: "scribble")
                                .font(toolFont)
                                .foregroundColor(.secondary)
                            Image(systemName: "line.diagonal")
                                .font(toolFont)
                                .foregroundColor(Color.red)
                        }
                        .frame(width: 100)
                        .padding(.bottom, 20)
                            Text("Remove")
                            .font(.title2).bold()
                                .foregroundColor(.accentColor)
                                .padding(.bottom, 3)
                            Text("Remove strokes from the canvas")
                                .multilineTextAlignment(.leading)
                                .foregroundColor(.primary)
                        }
                            .padding(.bottom, 40)
                        VStack(alignment: .leading) {
                        Image(systemName: "lasso").font(toolFont)
                            .foregroundColor(.secondary)
                            .frame(width: 100)
                            .padding(.bottom, 20)
                                Text("Select")
                                .font(.title2).bold()
                                    .foregroundColor(.accentColor)
                                    .padding(.bottom, 3)
                                Text("Select strokes to recolor, move, or delete")
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.primary)
                        }
                            .padding(.bottom, 40)
                    
                    }
                }
                .lineSpacing(10)
                .frame(maxWidth: 600)
                .padding()
                Spacer().frame(height: 200)
                Spacer()
            }
        }
        
        
    }
}

struct LearnToolsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LearnToolsView()
                .previewInterfaceOrientation(.landscapeLeft)
            LearnToolsView()
                .preferredColorScheme(.dark)
                .previewInterfaceOrientation(.landscapeLeft)
        }
    }
}
