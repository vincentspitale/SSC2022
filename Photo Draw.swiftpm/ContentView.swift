import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image("Icon")
            .resizable()
            .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 200, maxHeight: 200)
                .mask {
                    RoundedRectangle(cornerRadius: 40,
                                                             style: .continuous)
                }
                .padding()
            
            VStack(alignment: .leading) {
                Text("Photo Draw").font(.largeTitle)
                    .bold()
                    .padding(.bottom)
            Text("Photo Draw lets you convert images of handwriting to vector paths. These paths can then be manipulated exactly like those drawn directly on your device. For the best editing experience consider using an Apple Pencil.")
                .frame(maxWidth: 600)
            }
        }.padding()
        
    }
}
