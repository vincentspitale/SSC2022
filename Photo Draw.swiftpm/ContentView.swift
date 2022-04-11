import SwiftUI

struct ContentView: View {
    @State var isShowingWelcome: Bool = false
    // Each window scene has its own canvas
    @StateObject var windowState = CanvasState()
    
    var body: some View {
        ZStack{
            if isShowingWelcome {
            WelcomeView(isContinued: $isShowingWelcome)
            }
            if !isShowingWelcome {
                DrawView(windowState: windowState)
            }
        }
    }
}
