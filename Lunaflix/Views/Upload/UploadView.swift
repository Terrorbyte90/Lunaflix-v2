import SwiftUI
import PhotosUI

struct UploadView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = MuxViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lunaBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // No credentials warning
                        if !KeychainService.hasMuxCredentials {
                            noCredentialsCard
                        } else {
                            uploadForm
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Ladda upp video")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }
                        .foregroundColor(.lunaTextSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: vm.selectedVideoItem) { newItem in
            Task { await vm.handlePickedItem(newItem) }
        }
    }

    // MARK: - No Credentials Warning

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

    // MARK: - Upload Form

    private var uploadForm: some View {
        VStack(spacing: 16) {
            // Video picker zone
            videoPicker

            // Title input
            if vm.selectedVideoURL != nil {
                titleInput
            }

            // Luna age preview card (shown when recording date was extracted)
            if let date = vm.extractedRecordingDate {
                lunaAgePreview(date: date)
            } else if vm.selectedVideoURL != nil && vm.uploadPhase == .idle {
                noDateCard
            }

            // Upload button
            if vm.selectedVideoURL != nil && vm.uploadPhase == .idle {
                uploadButton
            }

            // Progress view
            if vm.uploadPhase.isActive {
                progressCard
            }

            // Done state
            if case .done(let asset) = vm.uploadPhase {
                doneCard(asset: asset)
            }

            // Error
            if case .failed(let message) = vm.uploadPhase {
                errorCard(message: message)
            }
        }
    }

    // MARK: - Video Picker

    private var videoPicker: some View {
        PhotosPicker(
            selection: $vm.selectedVideoItem,
            matching: .videos
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.lunaCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1.5, dash: [6])
                            )
                            .foregroundColor(
                                vm.selectedVideoURL != nil
                                    ? Color.lunaAccentLight.opacity(0.5)
                                    : Color.white.opacity(0.12)
                            )
                    )

                if let url = vm.selectedVideoURL {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lunaAccent.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: "film.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(LinearGradient.lunaAccentGradient)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(url.lastPathComponent)
                                .font(LunaFont.body())
                                .fontWeight(.semibold)
                                .foregroundColor(.lunaTextPrimary)
                                .lineLimit(1)
                            Text("Tryck för att byta video")
                                .font(LunaFont.caption())
                                .foregroundColor(.lunaTextMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.lunaTextMuted)
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.lunaAccent.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(LinearGradient.lunaAccentGradient)
                        }
                        VStack(spacing: 6) {
                            Text("Välj video")
                                .font(LunaFont.title3())
                                .foregroundColor(.lunaTextPrimary)
                            Text("MP4, MOV, M4V upp till ~4 GB")
                                .font(LunaFont.caption())
                                .foregroundColor(.lunaTextMuted)
                        }
                    }
                    .padding(.vertical, 36)
                }
            }
            .frame(minHeight: vm.selectedVideoURL == nil ? 180 : 86)
        }
        .buttonStyle(LunaPressStyle(scale: 0.98))
    }

    // MARK: - Title Input

    private var titleInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Titel (valfri)")
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack {
                Image(systemName: "textformat")
                    .font(.system(size: 14))
                    .foregroundColor(.lunaTextMuted)
                TextField("Ge videon ett namn...", text: $vm.videoTitle)
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextPrimary)
                    .tint(.lunaAccentLight)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.lunaCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
    }

    // MARK: - Luna Age Preview

    private func lunaAgePreview(date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Inspelningsinformation")
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lunaAccent.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Text("🌙")
                        .font(.system(size: 26))
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.lunaTextMuted)
                        Text(LunaAge.formatted(date))
                            .font(LunaFont.body())
                            .foregroundColor(.lunaTextPrimary)
                    }
                    Text(LunaAge.ageLabel(at: date))
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaAccentLight)
                        .fontWeight(.semibold)
                }
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "10B981"))
            }
        }
        .padding(16)
        .background(Color.lunaAccent.opacity(0.07))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lunaAccentLight.opacity(0.2), lineWidth: 1))
    }

    private var noDateCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 18))
                .foregroundColor(.lunaTextMuted)
            VStack(alignment: .leading, spacing: 3) {
                Text("Inget inspelningsdatum hittades")
                    .font(LunaFont.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(.lunaTextSecondary)
                Text("Datumet hittades inte i videofilen. Du kan ange titeln manuellt.")
                    .font(.system(size: 11))
                    .foregroundColor(.lunaTextMuted)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(Color.lunaCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Upload Button

    private var uploadButton: some View {
        Button {
            LunaHaptic.medium()
            Task { await vm.startUpload() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                Text("Starta uppladdning")
                    .font(LunaFont.body())
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient.lunaAccentGradient)
            .cornerRadius(16)
        }
        .buttonStyle(LunaPressStyle(scale: 0.97))
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.uploadPhase.label)
                        .font(LunaFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.lunaTextPrimary)

                    if vm.uploadPhase == .uploading {
                        Text("\(Int(vm.uploadProgress * 100))%")
                            .font(LunaFont.mono(13))
                            .foregroundColor(.lunaAccentLight)
                    }
                }

                Spacer()

                if vm.uploadPhase == .processing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.9)
                        .tint(.lunaAccentLight)
                }
            }

            if vm.uploadPhase == .uploading {
                LunaProgressBar(
                    progress: vm.uploadProgress,
                    height: 6,
                    color: .lunaAccentLight
                )
            } else if vm.uploadPhase == .processing {
                // Indeterminate
                LunaProgressBar(progress: 0.7, height: 6, color: .lunaAccentLight)
                    .opacity(0.5)
            }
        }
        .padding(16)
        .background(Color.lunaCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lunaAccentLight.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Done Card

    private func doneCard(asset: MuxAsset) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "10B981").opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "10B981"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Uppladdning lyckades!")
                        .font(LunaFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.lunaTextPrimary)
                    Text(asset.displayTitle)
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    LunaHaptic.light()
                    vm.resetUpload()
                } label: {
                    Text("Ladda upp fler")
                        .font(LunaFont.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(.lunaAccentLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.lunaAccent.opacity(0.15))
                        .cornerRadius(12)
                }
                .buttonStyle(LunaPressStyle())

                Button {
                    LunaHaptic.light()
                    dismiss()
                } label: {
                    Text("Klar")
                        .font(LunaFont.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LinearGradient.lunaAccentGradient)
                        .cornerRadius(12)
                }
                .buttonStyle(LunaPressStyle())
            }
        }
        .padding(16)
        .background(Color(hex: "10B981").opacity(0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "10B981").opacity(0.25), lineWidth: 1))
    }

    // MARK: - Error Card

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                Text("Fel vid uppladdning")
                    .font(LunaFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(.lunaTextPrimary)
            }
            Text(message)
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)
                .lineSpacing(2)

            Button {
                LunaHaptic.light()
                vm.uploadPhase = .idle
                vm.uploadError = nil
            } label: {
                Text("Försök igen")
                    .font(LunaFont.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
            }
            .buttonStyle(LunaPressStyle())
        }
        .padding(16)
        .background(Color.red.opacity(0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.25), lineWidth: 1))
    }
}
