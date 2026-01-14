import SwiftUI

struct APIKeySetupView: View {
    @ObservedObject var appState: AppState
    @State private var apiKey: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Notion API Key Required")
                .font(.custom("SF Mono", size: 20))
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Enter your Notion integration API key to connect.")
                .font(.custom("SF Mono", size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                SecureField("ntn_...", text: $apiKey)
                    .font(.custom("SF Mono", size: 14))
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .frame(width: 400)

                if let error = errorMessage {
                    Text(error)
                        .font(.custom("SF Mono", size: 11))
                        .foregroundColor(.red)
                }
            }

            Button("Connect to Notion") {
                saveAPIKey()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(apiKey.isEmpty)

            Spacer()

            Text("Your API key is stored securely in Keychain")
                .font(.custom("SF Mono", size: 10))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom, 20)
        }
        .padding(40)
    }

    private func saveAPIKey() {
        do {
            try appState.setAPIKey(apiKey)
            Task { await appState.loadData() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
