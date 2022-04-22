//
//  SelectPhotoView.swift
//  
//
//  Created by Vincent Spitale on 4/13/22.
//

import SwiftUI

struct SelectPhotoView: View {
    @ObservedObject var windowState: WindowState
    
    var body: some View {
        VStack{
            Spacer().frame(height: 100)
            HStack{
                Spacer()
            }
            VStack {
                Spacer()
                VStack(alignment: .leading) {
                    Text("First we need a photo").font(.title)
                        .bold()
                        .padding(.bottom)
                    
                    HStack {
                        Spacer()
                    }
                }
                .lineSpacing(10)
                .frame(maxWidth: 600)
                .padding()
                VStack {
                    Button(action: { withAnimation{ self.windowState.photoMode = .cameraScan }}) {
                        HStack {
                            Image(systemName: "viewfinder").font(.largeTitle)
                                .frame(width: 50)
                                .padding(.trailing, 5)
                            VStack(alignment: .leading) {
                                Text("Camera Scan")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 2)
                                Text("Use your camera to scan a document, notebook, or board")
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background {
                            Color(uiColor: .systemGray6)
                        }
                        .cornerRadius(10)
                    }
                    .accessibilityLabel(Text("Camera Scan"))
                    .padding(.vertical, 5)
                    Button(action: { withAnimation{self.windowState.photoMode = .library }}) {
                        HStack(alignment: .center) {
                            Image(systemName: "photo.fill").font(.largeTitle)
                                .frame(width: 50)
                                .padding(.trailing, 5)
                            VStack(alignment: .leading) {
                                Text("Photo Library")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 2)
                                Text("Select a photo from your library")
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background {
                            Color(uiColor: .systemGray6)
                        }
                        .cornerRadius(10)
                    }
                    .accessibilityLabel(Text("Photo Library"))
                    .padding(.vertical, 5)
                    Button(action: { withAnimation{self.windowState.photoMode = .example }}) {
                        
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled").font(.largeTitle)
                                .frame(width: 50)
                                .padding(.trailing, 5)
                            VStack(alignment: .leading) {
                                Text("Example Photos")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 2)
                                Text("Choose from one of the provided photos")
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background {
                            Color(uiColor: .systemGray6)
                        }
                        .cornerRadius(10)
                    }
                    .accessibilityLabel(Text("Example Photos"))
                    .padding(.vertical, 5)
                }
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
        SelectPhotoView(windowState: WindowState())
            .preferredColorScheme(.dark)
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
