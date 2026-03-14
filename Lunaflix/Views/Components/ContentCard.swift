import SwiftUI

// MARK: - Poster Card (Standard)

struct PosterCard: View {
    let content: LunaContent
    var width: CGFloat = 120
    var height: CGFloat = 180

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background gradient
            Rectangle()
                .fill(content.thumbnailGradient.gradient)
                .frame(width: width, height: height)

            // Decorative circle
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: width * 0.75)
                .offset(x: -width * 0.15, y: -width * 0.15)

            // Bottom info overlay
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height * 0.45)
                .overlay(
                    VStack(alignment: .leading, spacing: 3) {
                        Spacer()
                        Text(content.title)
                            .font(LunaFont.tag())
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(content.genreString)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8),
                    alignment: .bottomLeading
                )
            }

            // Badges row
            if content.isNew || content.isTrending {
                HStack(spacing: 3) {
                    if content.isNew {
                        badgeView("NY", color: .lunaAccent)
                    }
                    if content.isTrending {
                        badgeView("🔥", color: .clear, textColor: .lunaGold)
                    }
                }
                .padding(5)
            }

            // Continue progress bar
            if content.isContinuing {
                VStack {
                    Spacer()
                    LunaProgressBar(progress: content.continueProgress, height: 3)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 5)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }

    private func badgeView(_ text: String, color: Color, textColor: Color = .white) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundColor(textColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }
}

// MARK: - Wide Card (Landscape)

struct WideCard: View {
    let content: LunaContent
    var width: CGFloat = 280
    var height: CGFloat = 158

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(content.thumbnailGradient.gradient)
                .frame(width: width, height: height)

            // Decorative circles
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: width * 0.55)
                .offset(x: width * 0.45, y: -height * 0.12)

            // Bottom overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .init(x: 0, y: 0.3),
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(content.type.rawValue.uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(content.thumbnailGradient.accentColor)
                        .tracking(1)

                    if content.isNew {
                        Text("NY")
                            .font(LunaFont.tag())
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.lunaAccent)
                            .cornerRadius(3)
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.lunaGold)
                        Text(content.formattedRating)
                            .font(LunaFont.mono(10))
                            .foregroundColor(.lunaGold)
                    }
                }

                Text(content.title)
                    .font(LunaFont.title3())
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Show Luna's age at recording for Mux library clips
                if let date = content.recordingDate {
                    HStack(spacing: 4) {
                        Text("🌙")
                            .font(.system(size: 10))
                        Text(LunaAge.ageShort(at: date))
                            .font(LunaFont.tag())
                            .foregroundColor(.lunaAccentLight)
                    }
                } else {
                    Text(content.genreString)
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextSecondary)
                }
            }
            .padding(12)

            // Progress bar pinned to bottom
            if content.isContinuing {
                VStack {
                    Spacer()
                    LunaProgressBar(progress: content.continueProgress, height: 3)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Top 10 Card

struct Top10Card: View {
    let content: LunaContent
    let rank: Int
    var width: CGFloat = 130

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Poster
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(content.thumbnailGradient.gradient)
                    .frame(width: width, height: width * 1.45)

                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: width * 0.7)
                    .offset(x: -width * 0.1, y: -width * 0.1)

                // Content name at bottom
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: width * 0.5)
                    .overlay(
                        Text(content.title)
                            .font(LunaFont.tag())
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8),
                        alignment: .bottomLeading
                    )
                }
            }
            .frame(width: width, height: width * 1.45)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))

            // Large rank number — positioned to overlap left side
            Text("\(rank)")
                .font(.system(size: 88, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.9), radius: 2, x: -1, y: 0)
                .offset(x: -22, y: 12)
        }
        .frame(width: width + 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Featured Card

struct FeaturedCard: View {
    let content: LunaContent
    var width: CGFloat = 190

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(content.thumbnailGradient.gradient)
                .frame(width: width, height: width * 1.4)

            // Soft glow blob
            Circle()
                .fill(content.thumbnailGradient.accentColor.opacity(0.25))
                .frame(width: width * 0.9)
                .blur(radius: 28)
                .offset(y: -width * 0.25)
                .allowsHitTesting(false)

            LinearGradient(
                colors: [.clear, .black.opacity(0.9)],
                startPoint: .init(x: 0, y: 0.35),
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    if content.isNew {
                        Text("NY")
                            .font(LunaFont.tag())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.lunaAccent)
                            .cornerRadius(4)
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.lunaGold)
                        Text(content.formattedRating)
                            .font(LunaFont.mono(10))
                            .foregroundColor(.lunaGold)
                    }
                }

                Text(content.title)
                    .font(LunaFont.title3())
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(content.genreString)
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextSecondary.opacity(0.8))
            }
            .padding(12)
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(content.thumbnailGradient.accentColor.opacity(0.18), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Continue Watching Card

struct ContinueWatchingCard: View {
    let content: LunaContent
    var width: CGFloat = 230

    var body: some View {
        ZStack(alignment: .bottom) {
            // Thumbnail
            Rectangle()
                .fill(content.thumbnailGradient.gradient)
                .frame(width: width, height: 140)

            // Decorative
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: width * 0.5)
                .offset(x: width * 0.25, y: -20)

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .init(x: 0, y: 0.25),
                endPoint: .bottom
            )

            // Content info
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(content.title)
                            .font(LunaFont.title3())
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("\(Int(content.continueProgress * 100))% sett")
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaTextSecondary)
                    }
                    Spacer()
                    // Play button
                    ZStack {
                        Circle()
                            .fill(Color.lunaAccent)
                            .frame(width: 34, height: 34)
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }
                    .lunaGlow(color: .lunaAccent, radius: 10)
                }

                // Progress bar
                LunaProgressBar(progress: content.continueProgress, height: 3)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(width: width, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 13))
    }
}

// MARK: - Rating Badge

struct RatingBadge: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(.lunaGold)
            Text(String(format: "%.1f", rating))
                .font(LunaFont.mono(11))
                .foregroundColor(.lunaGold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}
