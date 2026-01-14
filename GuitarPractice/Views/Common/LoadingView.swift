import SwiftUI

struct LoadingView: View {
    var body: some View {
        HSplitView {
            // Left: Skeleton library
            VStack(spacing: 0) {
                // Fake filter bar
                SkeletonFilterBar()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider()
                    .background(Color.white.opacity(0.1))

                // Skeleton rows
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(0..<12, id: \.self) { _ in
                            SkeletonLibraryRow()
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.09))
            .frame(minWidth: 300, idealWidth: 450)

            // Right: Skeleton selected items
            VStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.orange)
                Text("Loading from Notion...")
                    .font(.custom("SF Mono", size: 12))
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.07, green: 0.07, blue: 0.10))
            .frame(minWidth: 280, idealWidth: 450)
        }
    }
}
