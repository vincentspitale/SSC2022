import SwiftUI

struct ContentView: View {
    @State var isShowingWelcome: Bool = true
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
