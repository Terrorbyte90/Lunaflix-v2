import SwiftUI

// MARK: - Poster Card (Standard)

struct PosterCard: View {
    let content: LunaContent
    var width: CGFloat = 120
    var height: CGFloat = 180

    @State private var pressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            posterImage
            Text(content.title)
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextSecondary)
                .lineLimit(1)
        }
        .frame(width: width)
        .scaleEffect(pressed ? 0.94 : 1.0)
        .animation(.lunaSnappy, value: pressed)
        ._onButtonGesture { pressing in
            pressed = pressing
        } perform: {}
    }

    private var posterImage: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(content.thumbnailGradient.gradient)
                .frame(width: width, height: height)
                .cornerRadius(10)

            // Decorative pattern
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: width * 0.8)
                .offset(x: -width * 0.2, y: -width * 0.2)

            // Title overlay
            VStack {
                Spacer()
                HStack {
                    Text(content.title)
                        .font(LunaFont.tag())
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .padding(8)
                    Spacer()
                }
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
            }

            // Badges
            HStack(spacing: 4) {
                if content.isNew {
                    badgeView("NY", color: .lunaAccent)
                }
                if content.isTrending {
                    badgeView("TREND", color: .lunaGold)
                }
            }
            .padding(6)

            // Continue progress
            if content.isContinuing {
                VStack {
                    Spacer()
                    ProgressView(value: content.continueProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .lunaAccentLight))
                        .scaleEffect(y: 1.5)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func badgeView(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundColor(.white)
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

    @State private var pressed = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(content.thumbnailGradient.gradient)
                .frame(width: width, height: height)

            // Decorative circles
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: width * 0.6)
                .offset(x: width * 0.4, y: -height * 0.1)

            Circle()
                .fill(.white.opacity(0.03))
                .frame(width: width * 0.4)
                .offset(x: -width * 0.1, y: height * 0.2)

            // Bottom overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(content.type.rawValue)
                        .font(LunaFont.tag())
                        .foregroundColor(content.thumbnailGradient.accentColor)

                    if content.isNew {
                        Text("NY")
                            .font(LunaFont.tag())
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.lunaAccent)
                            .cornerRadius(3)
                    }
                }

                Text(content.title)
                    .font(LunaFont.title3())
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(content.genreString)
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextSecondary)
            }
            .padding(12)

            if content.isContinuing {
                VStack {
                    Spacer()
                    ProgressView(value: content.continueProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .lunaAccentLight))
                        .scaleEffect(y: 1.5)
                }
                .padding(.horizontal, 1)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .scaleEffect(pressed ? 0.96 : 1.0)
        .animation(.lunaSnappy, value: pressed)
        ._onButtonGesture { pressing in pressed = pressing } perform: {}
    }
}

// MARK: - Top 10 Card

struct Top10Card: View {
    let content: LunaContent
    let rank: Int
    var width: CGFloat = 140

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PosterCard(content: content, width: width, height: width * 1.5)

            // Rank number
            HStack(alignment: .bottom, spacing: 0) {
                Text("\(rank)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white.opacity(0.9), Color.white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.8), radius: 4, x: -2, y: 0)
                    .offset(x: -10, y: 10)
                Spacer()
            }
        }
        .frame(width: width + 20)
    }
}

// MARK: - Featured Card

struct FeaturedCard: View {
    let content: LunaContent
    var width: CGFloat = 200

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(content.thumbnailGradient.gradient)
                .frame(width: width, height: width * 1.4)

            // Animated glow
            Circle()
                .fill(content.thumbnailGradient.accentColor.opacity(0.3))
                .frame(width: width * 0.8)
                .blur(radius: 30)
                .offset(y: -width * 0.2)

            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
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
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.lunaGold)
                        Text(content.formattedRating)
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaGold)
                    }
                }

                Text(content.title)
                    .font(LunaFont.title3())
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(content.genreString)
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextSecondary)
            }
            .padding(12)
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(content.thumbnailGradient.accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Continue Watching Card

struct ContinueWatchingCard: View {
    let content: LunaContent
    var width: CGFloat = 220

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(content.thumbnailGradient.gradient)
                .frame(width: width, height: 130)

            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(content.title)
                    .font(LunaFont.title3())
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    ProgressView(value: content.continueProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .lunaAccentLight))
                        .scaleEffect(y: 1.5)

                    Text("\(Int(content.continueProgress * 100))%")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextSecondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("Fortsätt")
                        .font(LunaFont.caption())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.lunaAccent)
                .cornerRadius(20)
            }
            .padding(10)
        }
        .frame(width: width, height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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
                .font(LunaFont.caption())
                .foregroundColor(.lunaGold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

// MARK: - Helpers

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    func _onButtonGesture(pressing: @escaping (Bool) -> Void, perform: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressing(true) }
                .onEnded { _ in pressing(false) }
        )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
