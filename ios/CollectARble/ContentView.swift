import SwiftUI

struct ContentView: View {
    @State private var showARExperience: Bool = false
    @State private var showSplash: Bool = true
    @State private var selectedCreatureId: String = ""
    @State private var startInThrowMode: Bool = false

    var body: some View {
        ZStack {
            HomeView(
                showARExperience: $showARExperience,
                selectedCreatureId: $selectedCreatureId,
                startInThrowMode: $startInThrowMode
            )
                .fullScreenCover(isPresented: $showARExperience) {
                    ARExperienceView(
                        isPresented: $showARExperience,
                        initialCreatureId: selectedCreatureId,
                        startInThrowMode: startInThrowMode
                    )
                }
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashScreenView {
                    showSplash = false
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.5), value: showSplash)
    }
}
