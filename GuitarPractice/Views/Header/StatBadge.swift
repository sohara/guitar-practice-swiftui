import SwiftUI

struct StatBadge: View {
    let icon: String
    let value: String
    var total: Int? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            if let total = total, value != "\(total)" {
                Text("\(value)/\(total)")
                    .font(.custom("SF Mono", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            } else {
                Text(value)
                    .font(.custom("SF Mono", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
