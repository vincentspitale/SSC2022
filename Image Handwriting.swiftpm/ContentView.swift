import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("With this app you can convert images of handwriting to vector paths. These paths can then be manipulated exactly like those drawn directly on this device. For the best editing experience consider using an Apple Pencil.")
                .frame(maxWidth: 600)
        }.padding()
    }
}
