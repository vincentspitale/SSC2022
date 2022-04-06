import SwiftUI

struct ContentView: View {
    @State var isShowingWelcome: Bool = true
    @ObservedObject var windowState = CanvasState()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        ZStack{
            if isShowingWelcome {
            WelcomeView(isContinued: $isShowingWelcome)
            }
            if !isShowingWelcome {
                ZStack{
                Rectangle()
                    .foregroundColor(Color(uiColor: UIColor.systemGray6))
                    .transition(.opacity)
                    .ignoresSafeArea()
                    VStack{
                        if horizontalSizeClass == .compact {
                        Spacer()
                        }
                        ZStack {
                        RoundedRectangle(cornerRadius: .greatestFiniteMagnitude, style: .continuous)
                        .foregroundColor(Color(uiColor: UIColor.systemGray5))
                            HStack {
                                self.controls()
                                Button(action: {windowState.currentTool = .selection}) {
                                    Image(systemName: "lasso")
                                        .font(.largeTitle)
                                        .foregroundColor(windowState.currentTool == .selection ? .primary : .secondary)
                                    
                                        .frame(width: 50)
                                }
                                Spacer()
                            }
                        }
                        
                        .frame(minWidth: nil, idealWidth: 400, maxWidth: 400, minHeight: nil, idealHeight: 70, maxHeight: 70, alignment: .center)
                        .padding(.horizontal)
                        if horizontalSizeClass != .compact {
                        Spacer()
                        }
                    }
                    
                
                }
            }
        }
    }
    
    @ViewBuilder func controls() -> some View {
        Spacer()
        Button(action: {windowState.currentTool = .touch}) {
        Image(systemName: "hand.point.up")
            .font(.largeTitle)
            .foregroundColor(windowState.currentTool == .touch ? .primary : .secondary)
            .frame(width: 50)
        }
        Spacer()
        Button(action: {windowState.currentTool = .pen}) {
            ZStack {
                Image(systemName: "pencil.tip")
                    .font(.largeTitle)
                    .foregroundColor(windowState.currentTool == .pen ? .primary : .secondary)
                Image(systemName: "pencil.tip")
                    .font(.largeTitle)
                    .foregroundColor(Color(uiColor: windowState.currentColor.color))
                    .mask(VStack{
                        Rectangle()
                            .foregroundColor(.white)
                            .frame(height: 15)
                        Spacer()
                    })
                    .opacity(windowState.currentTool == .pen ? 100 : 0)
            }
            .frame(width: 50)
        }
        Spacer()
        Button(action: {}) {
        Image(systemName: "photo")
            .font(.largeTitle)
            .foregroundColor(.accentColor)
        
            .frame(width: 50)
        }
        Spacer()
        Button(action: {windowState.currentTool = .eraser}) {
            ZStack{
            Image(systemName: "scribble")
                .font(.largeTitle)
                .foregroundColor(windowState.currentTool == .eraser ? .primary : .secondary)
            Image(systemName: "line.diagonal")
                .font(.largeTitle)
                .foregroundColor(windowState.currentTool == .eraser ? Color.red : .secondary)
                
            }
            .frame(width: 50)
        }
        Spacer()
    }
}
