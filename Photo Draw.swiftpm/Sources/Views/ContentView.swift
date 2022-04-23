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
                .opacity(isShowingWelcome ? 0 : 1)
            if isShowingWelcome {
                Rectangle()
                    .foregroundColor(Color(uiColor: UIColor.systemBackground))
                    .ignoresSafeArea()
                    .opacity(isShowingWelcome ? 0 : 1)
                WelcomeView(windowState: windowState)
            }
        }
    }
}
