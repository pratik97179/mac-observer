import SwiftUI

struct AppBackground: View {
    var body: some View {
        ZStack {
            EnvironmentBackgroundImage()
            Color.black.opacity(0.28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct EnvironmentBackgroundImage: View {
    var body: some View {
        GeometryReader { proxy in
            AppImage.environmentBackdrop()
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
