import SwiftUI

struct SocialView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedSegment = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            GeometryReader { geo in
                ZStack {
                    Image(themeManager.currentBackgroundImage)
                        .resizable()
                        .scaledToFill()
                        .grayscale(1.0)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.67),
                            Color.black.opacity(0.47),
                            Color.black.opacity(0.72)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Segment picker
                Picker("", selection: $selectedSegment) {
                    Text("Groups").tag(0)
                    Text("Friends").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Content — each child has its own NavigationStack
                TabView(selection: $selectedSegment) {
                    GroupListView()
                        .tag(0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    FriendsTabView()
                        .tag(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: selectedSegment)
            }
        }
    }
}
