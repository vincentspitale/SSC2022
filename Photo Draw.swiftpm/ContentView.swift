import SwiftUI

struct ContentView: View {
    @State var isContinued: Bool = false
    var body: some View {
        ZStack{
            WelcomeView(isContinued: $isContinued)
            if isContinued {
                Rectangle()
                    .foregroundColor(Color(uiColor: UIColor.systemBackground))
                    .transition(.opacity)
            }
        }
    }
}
