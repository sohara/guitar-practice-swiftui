import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Settings")
                .font(.custom("SF Mono", size: 20))
                .fontWeight(.bold)
                .foregroundColor(.white)

            Divider()
                .background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 12) {
                Text("NOTION CONNECTION")
                    .font(.custom("SF Mono", size: 10))
                    .foregroundColor(.gray)
                    .tracking(2)

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Connected")
                        .font(.custom("SF Mono", size: 14))
                        .foregroundColor(.white)

                    Spacer()

                    Button("Disconnect") {
                        showingClearConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.03))
                )
            }
            .frame(maxWidth: 400)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray)
        }
        .padding(24)
        .frame(width: 500, height: 300)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
        .confirmationDialog(
            "Disconnect from Notion?",
            isPresented: $showingClearConfirmation
        ) {
            Button("Disconnect", role: .destructive) {
                try? appState.clearAPIKey()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your API key from Keychain.")
        }
    }
}
