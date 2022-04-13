//
//  LearnToolsView.swift
//  
//
//  Created by Vincent Spitale on 4/13/22.
//

import SwiftUI

struct LearnToolsView: View {
    var body: some View {
        VStack{
            Spacer().frame(height: 200)
            HStack{
                Spacer()
            }
            VStack {
                Spacer()
                VStack(alignment: .leading) {
                    Text("Your Drawing Tools").font(.title)
                        .bold()
                        .padding(.bottom)
                    
                    Text("")
                    
                    HStack {
                        Spacer()
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
