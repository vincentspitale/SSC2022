//
//  SelectPhotoView.swift
//  
//
//  Created by Vincent Spitale on 4/13/22.
//

import SwiftUI

struct SelectPhotoView: View {
    @ObservedObject var windowState: CanvasState
    
    var body: some View {
        VStack{
            Spacer().frame(height: 200)
            HStack{
                Spacer()
            }
            VStack {
                Spacer()
                VStack(alignment: .leading) {
                    Text("First select a photo").font(.title)
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

struct SelectPhotoView_Previews: PreviewProvider {
    static var previews: some View {
        SelectPhotoView(windowState: CanvasState())
    }
}
