import SwiftUI
import PhotosUI

struct UploadView: View {
    @ObservedObject private var um = UploadManager.shared
    @State private var pickerItems: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss

    private var reviewJobs: [UploadJob] {
        um.jobs.filter { if case .review = $0.phase { return true }; return false }
    }

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

                // "Ladda upp alla" toolbar button when multiple jobs in review
                if reviewJobs.count > 1 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            LunaHaptic.medium()
                            um.beginAllReview()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Ladda upp alla")
                            }
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaAccentLight)
                        }
                    }
                } else if um.jobs.contains(where: {
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
            LazyVStack(spacing: 12) {
                ForEach(um.jobs) { job in
                    UploadJobCard(job: job) {
                        LunaHaptic.light()
                        um.remove(job)
                    } onBeginUpload: {
                        LunaHaptic.medium()
                        um.beginUpload(job)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Empty Hint

    private var emptyHint: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 48)
            Image(systemName: "film.stack")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient.lunaAccentGradient)
                .opacity(0.55)
            Text("Välj en eller flera videor\natt ladda upp till Mux")
                .font(LunaFont.body())
                .foregroundColor(.lunaTextMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
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

// MARK: - Upload Job Card

struct UploadJobCard: View {
    @ObservedObject var job: UploadJob
    let onRemove: () -> Void
    let onBeginUpload: () -> Void

    var body: some View {
        Group {
            if case .review = job.phase {
                ReviewCard(job: job, onRemove: onRemove, onBeginUpload: onBeginUpload)
            } else {
                ProgressCard(job: job, onRemove: onRemove)
            }
        }
        .animation(.lunaSnappy, value: job.phase == .uploading)
    }
}

// MARK: - Review Card (title + date editing before upload)

struct ReviewCard: View {
    @ObservedObject var job: UploadJob
    let onRemove: () -> Void
    let onBeginUpload: () -> Void

    @State private var showDatePicker = false
    @FocusState private var titleFocused: Bool

    // Deterministic gradient from job id
    private var gradientStyle: ThumbnailStyle {
        let styles: [ThumbnailStyle] = [.purple, .blue, .teal, .rose, .amber, .indigo, .emerald, .violet, .ocean]
        return styles[abs(job.id.hashValue) % styles.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient + Luna age overlay
            ZStack(alignment: .bottomLeading) {
                gradientStyle.gradient
                    .frame(height: 72)

                // Grain texture overlay
                Rectangle()
                    .fill(.black.opacity(0.15))
                    .frame(height: 72)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let date = job.recordingDate {
                            HStack(spacing: 5) {
                                Text("🌙")
                                    .font(.system(size: 13))
                                Text(LunaAge.ageLabel(at: date))
                                    .font(LunaFont.caption())
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            }
                        } else {
                            HStack(spacing: 5) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Inget inspelningsdatum hittades")
                                    .font(LunaFont.caption())
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    Spacer()

                    // Remove button
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 26, height: 26)
                            .background(.black.opacity(0.3))
                            .cornerRadius(13)
                    }
                    .buttonStyle(LunaPressStyle())
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))

            // Editable form
            VStack(spacing: 12) {

                // Title field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Titel")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)

                    TextField(job.suggestedTitle.isEmpty ? "Ange titel" : job.suggestedTitle,
                              text: $job.customTitle)
                        .font(LunaFont.body())
                        .foregroundColor(.lunaTextPrimary)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { titleFocused = false }
                        .tint(.lunaAccentLight)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.lunaElevated)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    titleFocused ? Color.lunaAccentLight.opacity(0.5) : Color.white.opacity(0.07),
                                    lineWidth: 1
                                )
                        )
                }

                // Recording date
                VStack(alignment: .leading, spacing: 6) {
                    Text("Inspelningsdatum")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)

                    Button {
                        titleFocused = false
                        showDatePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.lunaAccentLight)
                                .frame(width: 20)

                            if let date = job.recordingDate {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(LunaAge.formatted(date))
                                        .font(LunaFont.body())
                                        .foregroundColor(.lunaTextPrimary)
                                    Text(LunaAge.ageShort(at: date))
                                        .font(LunaFont.caption())
                                        .foregroundColor(.lunaAccentLight)
                                }
                            } else {
                                Text("Välj datum")
                                    .font(LunaFont.body())
                                    .foregroundColor(.lunaTextMuted)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.lunaTextMuted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.lunaElevated)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.07), lineWidth: 1))
                    }
                    .buttonStyle(LunaPressStyle(scale: 0.98))
                }

                // Upload button
                Button {
                    onBeginUpload()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 17))
                        Text("Ladda upp")
                            .fontWeight(.bold)
                    }
                    .font(LunaFont.body())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(LinearGradient.lunaAccentGradient)
                    .cornerRadius(12)
                    .shadow(color: Color.lunaAccent.opacity(0.4), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(LunaPressStyle(scale: 0.97))
                .lunaGlow(color: .lunaAccent, radius: 8)
            }
            .padding(14)
            .background(Color.lunaCard)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14))
        }
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(
                date: Binding(
                    get: { job.recordingDate ?? Date() },
                    set: { job.recordingDate = $0 }
                ),
                hasDate: Binding(
                    get: { job.recordingDate != nil },
                    set: { if !$0 { job.recordingDate = nil } }
                )
            )
        }
    }
}

// MARK: - Progress Card (loading / uploading / processing / done / failed)

struct ProgressCard: View {
    @ObservedObject var job: UploadJob
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                jobIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(job.effectiveTitle)
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
            if case .uploading = job.phase {
                LunaProgressBar(progress: job.progress, height: 3, color: .lunaAccentLight)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.lunaCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .animation(.lunaSnappy, value: job.progress)
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

        case .review:
            Image(systemName: "checkmark.circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.lunaAccentLight)

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
                .tint(.lunaAccentLight)
                .scaleEffect(0.75)

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

        case .review:
            Text("Klart att ladda upp")
                .font(LunaFont.caption())
                .foregroundColor(.lunaAccentLight)

        case .uploading:
            HStack(spacing: 6) {
                Text("\(Int(job.progress * 100))%")
                    .font(LunaFont.mono(12))
                    .foregroundColor(.lunaAccentLight)
                    .animation(nil, value: job.progress)
                if !job.speedString.isEmpty {
                    Text("·")
                        .foregroundColor(.lunaTextMuted)
                        .font(LunaFont.caption())
                    Text(job.speedString)
                        .font(LunaFont.mono(12))
                        .foregroundColor(.lunaAccentLight)
                }
            }

        case .processing:
            Text("Bearbetar på Mux...")
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)

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
            Text(msg)
                .font(LunaFont.caption())
                .foregroundColor(.red)
                .lineLimit(2)
        }
    }

    // MARK: - Right Action

    @ViewBuilder
    private var rightAction: some View {
        switch job.phase {
        case .done, .failed:
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.lunaTextMuted)
                    .frame(width: 30, height: 30)
                    .background(Color.lunaElevated)
                    .cornerRadius(8)
            }
            .buttonStyle(LunaPressStyle())

        default:
            EmptyView()
        }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var date: Date
    @Binding var hasDate: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lunaBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Luna age preview
                    if hasDate {
                        HStack(spacing: 10) {
                            Text("🌙")
                                .font(.system(size: 22))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LunaAge.ageLabel(at: date))
                                    .font(LunaFont.body())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.lunaTextPrimary)
                                Text("Inspelat \(LunaAge.formatted(date))")
                                    .font(LunaFont.caption())
                                    .foregroundColor(.lunaTextMuted)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.lunaAccent.opacity(0.07))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lunaAccentLight.opacity(0.15), lineWidth: 1))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    DatePicker(
                        "Inspelningsdatum",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(.lunaAccentLight)
                    .padding(.horizontal, 8)
                    .onChange(of: date) { _, _ in
                        if !hasDate { hasDate = true }
                    }

                    // "Inget datum" option
                    Button {
                        withAnimation(.lunaSnappy) {
                            hasDate = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.minus")
                                .foregroundColor(.lunaTextMuted)
                            Text("Ta bort datum")
                                .foregroundColor(.lunaTextMuted)
                        }
                        .font(LunaFont.body())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.lunaCard)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(LunaPressStyle(scale: 0.98))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .animation(.lunaSnappy, value: hasDate)
            }
            .navigationTitle("Välj inspelningsdatum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .foregroundColor(.lunaAccentLight)
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
