import SwiftUI
import PhotosUI

struct UploadView: View {
    @ObservedObject private var um = UploadManager.shared
    @State private var pickerItems: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lunaBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if !KeychainService.hasMuxCredentials {
                        noCredentialsCard
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    } else {
                        VStack(spacing: 14) {
                            // Pick button — always visible
                            pickerButton
                                .padding(.horizontal, 16)

                            if um.jobs.isEmpty {
                                emptyHint
                            } else {
                                jobsList
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Ladda upp")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Stäng") { dismiss() }
                        .foregroundColor(.lunaTextSecondary)
                }
                if um.jobs.contains(where: {
                    if case .done = $0.phase { return true }
                    if case .failed = $0.phase { return true }
                    return false
                }) {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Rensa klara") {
                            LunaHaptic.light()
                            um.clearFinished()
                        }
                        .foregroundColor(.lunaAccentLight)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            LunaHaptic.light()
            um.enqueue(items: newItems)
            pickerItems = []
        }
    }

    // MARK: - Picker Button

    private var pickerButton: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: 10,
            matching: .videos
        ) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Välj videor att ladda upp")
                    .font(LunaFont.body())
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(LinearGradient.lunaAccentGradient)
            .cornerRadius(14)
        }
        .buttonStyle(LunaPressStyle(scale: 0.97))
    }

    // MARK: - Jobs List

    private var jobsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(um.jobs) { job in
                    UploadJobCard(job: job) {
                        LunaHaptic.light()
                        um.remove(job)
                    } onPause: {
                        if job.phase.canPause {
                            um.pause(job)
                        } else if job.phase.canResume {
                            um.resume(job)
                        }
                    } onRetry: {
                        um.retry(job)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Empty Hint

    private var emptyHint: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 48)

            ZStack {
                Circle()
                    .fill(Color.lunaAccent.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "film.stack")
                    .font(.system(size: 44))
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
                    .opacity(0.7)
            }
            .modifier(PulseModifier())

            VStack(spacing: 8) {
                Text("Välj videor att ladda upp")
                    .font(LunaFont.title3())
                    .foregroundColor(.lunaTextPrimary)

                Text("Tryck på knappen ovan för att välja\nvideor från ditt bibliotek")
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Tips
            VStack(alignment: .leading, spacing: 10) {
                tipRow(icon: "arrow.up.circle", text: "Stödjer MP4, MOV och M4V")
                tipRow(icon: "clock", text: "Stora filer tar längre tid")
                tipRow(icon: "arrow.clockwise", text: "Du kan pausa och återuppta")
            }
            .padding(.top, 8)
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.lunaAccentLight)
                .frame(width: 20)

            Text(text)
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)
        }
    }

    // MARK: - No Credentials

    private var noCredentialsCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.lunaCard)
                    .frame(width: 80, height: 80)
                Image(systemName: "key.slash.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
            }
            .padding(.top, 20)

            VStack(spacing: 8) {
                Text("Mux ej konfigurerat")
                    .font(LunaFont.title2())
                    .foregroundColor(.lunaTextPrimary)
                Text("Gå till Profil → Mux-inställningar och\nange dina API-nycklar för att ladda upp videor.")
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.lunaCard)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

}

// MARK: - Pulse Animation Modifier

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Upload Job Card

struct UploadJobCard: View {
    @ObservedObject var job: UploadJob
    let onRemove: () -> Void
    let onPause: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                jobIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(job.displayName)
                        .font(LunaFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.lunaTextPrimary)
                        .lineLimit(1)

                    if let date = job.recordingDate {
                        HStack(spacing: 4) {
                            Text("🌙")
                                .font(.system(size: 11))
                            Text(LunaAge.ageLabel(at: date))
                                .font(LunaFont.caption())
                                .foregroundColor(.lunaAccentLight)
                        }
                    }

                    statusLine
                }

                Spacer()

                rightAction
            }
            .padding(14)

            // Progress bar during upload
            if job.phase.isActive || job.phase == .paused {
                progressSection
            }
        }
        .background(Color.lunaCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1))
        .animation(.lunaSnappy, value: job.progress)
        .animation(.lunaSnappy, value: job.phase)
    }

    private var borderColor: Color {
        switch job.phase {
        case .done: return Color(hex: "10B981").opacity(0.3)
        case .failed: return Color.red.opacity(0.3)
        case .paused: return Color.lunaGold.opacity(0.3)
        default: return Color.white.opacity(0.06)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 8) {
            LunaProgressBar(progress: job.progress, height: 4, color: progressColor)
                .padding(.horizontal, 14)

            HStack {
                // Progress percentage
                Text("\(Int(job.progress * 100))%")
                    .font(LunaFont.mono(11))
                    .foregroundColor(.lunaTextMuted)
                    .monospacedDigit()

                Spacer()

                // Speed
                if !job.speedString.isEmpty && job.phase == .uploading {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10))
                        Text(job.speedString)
                            .font(LunaFont.mono(11))
                    }
                    .foregroundColor(.lunaAccentLight)
                }

                // ETA
                if let eta = job.estimatedTimeRemaining, job.phase == .uploading {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(eta)
                            .font(LunaFont.mono(11))
                    }
                    .foregroundColor(.lunaTextMuted)
                }

                // Paused indicator
                if job.phase == .paused {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10))
                        Text("Pausad")
                            .font(LunaFont.mono(11))
                    }
                    .foregroundColor(.lunaGold)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    private var progressColor: Color {
        switch job.phase {
        case .paused: return .lunaGold
        case .processing: return .lunaCyan
        default: return .lunaAccentLight
        }
    }

    // MARK: - Icon

    private var jobIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(iconBg)
                .frame(width: 44, height: 44)
            iconContent
        }
    }

    private var iconBg: Color {
        switch job.phase {
        case .done:   return Color(hex: "10B981").opacity(0.15)
        case .failed: return Color.red.opacity(0.15)
        case .paused: return Color.lunaGold.opacity(0.15)
        default:      return Color.lunaAccent.opacity(0.15)
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        switch job.phase {
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.lunaAccentLight)
                .scaleEffect(0.75)

        case .uploading:
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 2.5)
                    .frame(width: 26, height: 26)
                Circle()
                    .trim(from: 0, to: job.progress)
                    .stroke(Color.lunaAccentLight,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: job.progress)
            }

        case .processing:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.lunaCyan)
                .scaleEffect(0.75)

        case .paused:
            Image(systemName: "pause.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.lunaGold)

        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "10B981"))

        case .failed:
            Image(systemName: "exclamationmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.red)
        }
    }

    // MARK: - Status Line

    @ViewBuilder
    private var statusLine: some View {
        switch job.phase {
        case .loading:
            Text("Hämtar från biblioteket...")
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)

        case .uploading:
            HStack(spacing: 6) {
                Text("Laddar upp...")
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextMuted)
            }

        case .processing:
            HStack(spacing: 6) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.lunaCyan)
                    .scaleEffect(0.6)
                Text("Bearbetar på Mux...")
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextMuted)
            }

        case .paused:
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.lunaGold)
                    .frame(width: 5, height: 5)
                Text("Uppladdning pausad")
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaGold)
            }

        case .done:
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: "10B981"))
                    .frame(width: 5, height: 5)
                Text("Uppladdning lyckades")
                    .font(LunaFont.caption())
                    .foregroundColor(Color(hex: "10B981"))
            }

        case .failed(let msg):
            VStack(alignment: .leading, spacing: 4) {
                Text(msg)
                    .font(LunaFont.caption())
                    .foregroundColor(.red)
                    .lineLimit(2)

                if job.canRetry {
                    Text(job.retryLabel)
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)
                }
            }
        }
    }

    // MARK: - Right Action

    @ViewBuilder
    private var rightAction: some View {
        HStack(spacing: 8) {
            // Pause/Resume button
            if job.phase.canPause || job.phase.canResume {
                Button(action: onPause) {
                    Image(systemName: job.phase.canPause ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.lunaTextMuted)
                        .frame(width: 30, height: 30)
                        .background(Color.lunaElevated)
                        .cornerRadius(8)
                }
                .buttonStyle(LunaPressStyle())
            }

            // Retry button
            if job.phase.canRetry && job.canRetry {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.lunaAccentLight)
                        .frame(width: 30, height: 30)
                        .background(Color.lunaAccent.opacity(0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(LunaPressStyle())
            }

            // Remove button (done/failed)
            if job.phase == .done || job.phase == .failed || job.phase == .paused {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.lunaTextMuted)
                        .frame(width: 30, height: 30)
                        .background(Color.lunaElevated)
                        .cornerRadius(8)
                }
                .buttonStyle(LunaPressStyle())
            }
        }
    }
}