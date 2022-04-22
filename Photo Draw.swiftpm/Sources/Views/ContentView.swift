import SwiftUI

struct ContentView: View {
    // Each window scene has its own state and canvas
    @StateObject var windowState = WindowState()
    
    var isShowingWelcome: Bool {
        windowState.photoMode == .welcome
    }
    
    var body: some View {
        ZStack{
            DrawView(windowState: windowState)
                .disabled(isShowingWelcome)
                .accessibilityHidden(isShowingWelcome)
            if isShowingWelcome {
            Rectangle()
                .foregroundColor(Color(uiColor: UIColor.systemBackground))
                .ignoresSafeArea()
                WelcomeView(windowState: windowState)
            }
        }
    }
}
