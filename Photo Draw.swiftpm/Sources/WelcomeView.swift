//
//  WelcomeView.swift
//  Photo Draw
//
//  Created by Vincent Spitale on 4/6/22.
//

import Foundation
import SwiftUI

struct WelcomeView: View {
    @Binding var isContinued: Bool
    
    var body: some View {
        ZStack{
            ScrollView{
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
                        Text("Ever wished you could move and edit your writing on paper like you can with digital ink?\n")
                        
                        Text("Photo Draw lets you convert images with handwriting or line drawings to vector paths. These paths can then be manipulated exactly like they were drawn directly on your device. Perfect for those who prefer the feel of paper or students who want to digitize what's on the board!")
                    }
                    .lineSpacing(10)
                    .frame(maxWidth: 600)
                    .padding()
                    Spacer().frame(height: 200)
                    Spacer()
                }
            }
            VStack{
                Spacer()
                Button(action: {
                    withAnimation{$isContinued.wrappedValue.toggle()}}) {
                        Text("Let's Draw!")
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
