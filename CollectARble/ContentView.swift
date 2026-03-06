import SwiftUI

struct ContentView: View {
    @State private var showARExperience: Bool = false

    var body: some View {
        HomeView(showARExperience: $showARExperience)
            .fullScreenCover(isPresented: $showARExperience) {
                ARExperienceView(isPresented: $showARExperience)
            }
    }
}
