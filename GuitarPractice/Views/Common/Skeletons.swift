import SwiftUI

struct SkeletonFilterBar: View {
    var body: some View {
        VStack(spacing: 10) {
            // Search field skeleton
            ShimmerView()
                .frame(height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Filter buttons skeleton
            HStack(spacing: 12) {
                ShimmerView()
                    .frame(width: 60, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                ShimmerView()
                    .frame(width: 100, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Spacer()
            }
        }
    }
}

struct SkeletonLibraryRow: View {
    var body: some View {
        HStack(spacing: 12) {
            // Circle placeholder
            ShimmerView()
                .frame(width: 16, height: 16)
                .clipShape(Circle())

            // Icon placeholder
            ShimmerView()
                .frame(width: 20, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            // Name placeholder
            ShimmerView()
                .frame(width: CGFloat.random(in: 100...200), height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            // Artist placeholder (sometimes)
            if Bool.random() {
                ShimmerView()
                    .frame(width: CGFloat.random(in: 60...120), height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            Spacer()

            // Date placeholder
            ShimmerView()
                .frame(width: 50, height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct ShimmerView: View {
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            Color.white.opacity(0.05)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.6)
                )
                .clipped()
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}
