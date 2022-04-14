import SwiftUI

struct ContentView: View {
    // Each window scene has its own canvas
    @StateObject var windowState = CanvasState()
    
    var isShowingWelcome: Bool {
        windowState.photoMode == .welcome
    }
    
    var body: some View {
        ZStack{
            if isShowingWelcome {
                WelcomeView(windowState: windowState)
            }
            if !isShowingWelcome {
                DrawView(windowState: windowState)
            }
        }
    }
}
