import SwiftUI

struct AppBackground: View {
    var body: some View {
        EnvironmentBackgroundImage()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct EnvironmentBackgroundImage: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * 0.9
            let height = proxy.size.height * 0.9

            AppImage.environmentBackdrop()
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .mask {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.00),
                                    .init(color: .black, location: 0.06),
                                    .init(color: .black, location: 0.94),
                                    .init(color: .clear, location: 1.00)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.00),
                                    .init(color: .black, location: 0.08),
                                    .init(color: .black, location: 0.88),
                                    .init(color: .clear, location: 1.00)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                }
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .center
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
