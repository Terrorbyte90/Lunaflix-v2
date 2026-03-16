import SwiftUI

struct MuxSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = MuxSettingsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lunaBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header info card
                        infoCard
                            .padding(.top, 8)

                        // Credentials card
                        credentialsCard

                        // Connection status
                        if vm.connectionStatus != .idle {
                            statusCard
                        }

                        // Connected — show library stats
                        if case .connected = vm.connectionStatus {
                            connectedCard
                        }

                        // Disconnect button
                        if KeychainService.hasMuxCredentials {
                            disconnectButton
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Mux-inställningar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") { dismiss() }
                        .foregroundColor(.lunaAccentLight)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear { vm.loadSavedCredentials() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lunaAccent.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: "cloud.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Mux Video Backend")
                    .font(LunaFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(.lunaTextPrimary)
                Text("Streama och hantera dina videor via Mux API.")
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextMuted)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lunaCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Credentials Card

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("API-nycklar")
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            VStack(spacing: 12) {
                // Token ID
                VStack(alignment: .leading, spacing: 6) {
                    Text("Token ID")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextSecondary)
                    SecureInputField(
                        placeholder: "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
                        text: $vm.tokenID
                    )
                }

                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)

                // Token Secret
                VStack(alignment: .leading, spacing: 6) {
                    Text("Token Secret")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextSecondary)
                    SecureInputField(
                        placeholder: "••••••••••••••••••••••••••••••••",
                        text: $vm.tokenSecret,
                        isSecure: true
                    )
                }
            }

            // Test / Save button
            Button {
                LunaHaptic.medium()
                Task { await vm.saveAndTest() }
            } label: {
                HStack(spacing: 8) {
                    if vm.isTesting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 14))
                    }
                    Text(vm.isTesting ? "Testar anslutning..." : "Spara och testa")
                        .font(LunaFont.body())
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient.lunaAccentGradient
                        .opacity(vm.canSave ? 1 : 0.4)
                )
                .cornerRadius(14)
            }
            .buttonStyle(LunaPressStyle(scale: 0.97))
            .disabled(!vm.canSave || vm.isTesting)
        }
        .padding(16)
        .background(Color.lunaCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Status Card

    @ViewBuilder
    private var statusCard: some View {
        HStack(spacing: 12) {
            switch vm.connectionStatus {
            case .testing:
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.85)
                    .tint(.lunaAccentLight)
                Text("Testar anslutning...")
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextSecondary)

            case .connected(let assetCount):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "10B981"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ansluten till Mux")
                        .font(LunaFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.lunaTextPrimary)
                    Text("\(assetCount) videor i biblioteket")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)
                }

            case .failed(let message):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                Text(message)
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextPrimary)
                    .lineLimit(3)

            case .idle:
                EmptyView()
            }

            Spacer()
        }
        .padding(16)
        .background(statusBackground)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(statusBorderColor, lineWidth: 1))
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.lunaSnappy, value: vm.connectionStatus.id)
    }

    private var statusBackground: Color {
        switch vm.connectionStatus {
        case .connected: return Color(hex: "10B981").opacity(0.1)
        case .failed:    return Color.red.opacity(0.1)
        default:         return Color.lunaCard
        }
    }

    private var statusBorderColor: Color {
        switch vm.connectionStatus {
        case .connected: return Color(hex: "10B981").opacity(0.3)
        case .failed:    return Color.red.opacity(0.3)
        default:         return Color.white.opacity(0.06)
        }
    }

    // MARK: - Connected Info

    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Snabblänkar")
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(spacing: 10) {
                quickLinkButton("Ladda upp video", icon: "arrow.up.circle.fill") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .openUploadSheet, object: nil)
                    }
                }
                quickLinkButton("Mux Dashboard", icon: "safari.fill") {
                    if let url = URL(string: "https://dashboard.mux.com") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.lunaCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func quickLinkButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.lunaAccentLight)
                Text(label)
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.lunaElevated)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(LunaPressStyle())
    }

    // MARK: - Disconnect

    private var disconnectButton: some View {
        Button {
            LunaHaptic.medium()
            vm.disconnect()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13))
                Text("Ta bort API-nycklar")
                    .font(LunaFont.body())
            }
            .foregroundColor(.red.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.1))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(LunaPressStyle(scale: 0.97))
    }
}

// MARK: - Secure Input Field

private struct SecureInputField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @State private var showPlain = false

    var body: some View {
        HStack {
            if isSecure && !showPlain {
                SecureField(placeholder, text: $text)
                    .font(LunaFont.mono(14))
                    .foregroundColor(.lunaTextPrimary)
                    .tint(.lunaAccentLight)
            } else {
                TextField(placeholder, text: $text)
                    .font(LunaFont.mono(14))
                    .foregroundColor(.lunaTextPrimary)
                    .tint(.lunaAccentLight)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            if isSecure {
                Button {
                    showPlain.toggle()
                } label: {
                    Image(systemName: showPlain ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundColor(.lunaTextMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.lunaElevated)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }
}

// MARK: - Settings ViewModel

@MainActor
final class MuxSettingsViewModel: ObservableObject {
    @Published var tokenID = ""
    @Published var tokenSecret = ""
    @Published var isTesting = false
    @Published var connectionStatus: ConnectionStatus = .idle

    enum ConnectionStatus: Equatable {
        case idle
        case testing
        case connected(Int)
        case failed(String)

        var id: String {
            switch self {
            case .idle:           return "idle"
            case .testing:        return "testing"
            case .connected(let n): return "connected-\(n)"
            case .failed(let e):  return "failed-\(e)"
            }
        }
    }

    var canSave: Bool {
        tokenID.count > 8 && tokenSecret.count > 8
    }

    func loadSavedCredentials() {
        tokenID = KeychainService.muxTokenID
        tokenSecret = KeychainService.muxTokenSecret
        if KeychainService.hasMuxCredentials {
            Task { await testCurrentCredentials() }
        }
    }

    func saveAndTest() async {
        isTesting = true
        connectionStatus = .testing

        do {
            try await MuxService.shared.testConnection(tokenID: tokenID, tokenSecret: tokenSecret)

            // Save to keychain on success
            KeychainService.muxTokenID = tokenID
            KeychainService.muxTokenSecret = tokenSecret

            // Get asset count
            let assets = try await MuxService.shared.listAssets()
            connectionStatus = .connected(assets.count)
        } catch {
            connectionStatus = .failed(error.localizedDescription)
        }

        isTesting = false
    }

    func disconnect() {
        KeychainService.clearMuxCredentials()
        tokenID = ""
        tokenSecret = ""
        connectionStatus = .idle
    }

    private func testCurrentCredentials() async {
        do {
            let assets = try await MuxService.shared.listAssets()
            connectionStatus = .connected(assets.count)
        } catch {
            connectionStatus = .failed(error.localizedDescription)
        }
    }
}
