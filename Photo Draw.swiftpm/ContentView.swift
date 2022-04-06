import SwiftUI

struct ContentView: View {
    @State var isShowingWelcome: Bool = true
    var body: some View {
        ZStack{
            if isShowingWelcome {
            WelcomeView(isContinued: $isShowingWelcome)
            }
            if !isShowingWelcome {
                Rectangle()
                    .foregroundColor(Color(uiColor: UIColor.systemBackground))
                    .transition(.opacity)
            }
        }
    }
}
