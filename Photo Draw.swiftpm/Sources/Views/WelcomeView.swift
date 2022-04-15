//
//  WelcomeView.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/6/22.
//

import Foundation
import SwiftUI

enum WelcomeState {
    case welcomeMessage
    case learnTools
    case selectPhoto
}

struct WelcomeView: View {
    @ObservedObject var windowState: CanvasState
    @State var welcomeState: WelcomeState = .welcomeMessage
    
    var body: some View {
        ZStack{
            ScrollView {
                switch welcomeState {
                case .welcomeMessage:
                    WelcomeMessageView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading).combined(with: .opacity)))
                case .learnTools:
                    LearnToolsView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading).combined(with: .opacity)))
                case .selectPhoto:
                    SelectPhotoView(windowState: windowState)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
            if welcomeState != .selectPhoto {
                VStack{
                    Spacer()
                    Button(action: { self.buttonAction() }) {
                            Text(self.buttonMessage())
                                .font(.headline)
                                .bold()
                                .foregroundColor(Color(uiColor: UIColor.systemBackground))
                                .padding()
                                .frame(width: 200)
                                .background(Color.accentColor)
                                .cornerRadius(15)
                        }
                        .padding(.bottom, 40)
                        .padding(.horizontal)
                }
            }
            
        }
    }
    
    func buttonAction() {
        switch welcomeState {
        case .welcomeMessage:
            withAnimation { self.welcomeState = .learnTools }
        case .learnTools:
            withAnimation { self.welcomeState = .selectPhoto }
        case .selectPhoto:
            break
        }
    }
    
    func buttonMessage() -> String {
        switch welcomeState {
        case .welcomeMessage:
            return "Learn Tools"
        case .learnTools:
            return "Let's Draw!"
        case .selectPhoto:
            return ""
        }
    }
}



struct WelcomeMessageView: View {
    var body: some View {
        VStack {
            HStack{
                Spacer()
            }
            VStack {
                Spacer()
                Image("Icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .mask {
                        RoundedRectangle(cornerRadius: 40,
                                         style: .continuous)
                    }
                    .accessibilityLabel(Text("App Icon"))
                    .padding()
                    .padding(.vertical, 40)
                
                VStack(alignment: .leading) {
                    Text("Photo Draw").font(.largeTitle)
                        .bold()
                        .padding(.bottom)
                    
                    Text("Ever wished you could move and edit your strokes on paper like you can with digital ink?\n")
                    
                    Text("'Photo Draw' is a neat little drawing app with an amazing trick up its sleeve. It allows you to convert images with handwriting or line drawings to vector paths. These paths can then be manipulated exactly like they were drawn directly on your device. It's perfect for those who prefer the feel of paper or students who want to digitize what's on the board in the classroom!")
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

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WelcomeView(windowState: CanvasState())
                .previewInterfaceOrientation(.landscapeLeft)
            WelcomeView(windowState: CanvasState())
                .preferredColorScheme(.dark)
                .previewInterfaceOrientation(.landscapeLeft)
        }
    }
}
