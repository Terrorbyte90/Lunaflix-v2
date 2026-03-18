import SwiftUI

struct ContentRowView: View {
    let category: ContentCategory
    let onTap: (LunaContent) -> Void
    @State private var showAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            rowHeader
            rowContent
        }
        .padding(.top, 16)
        .sheet(isPresented: $showAll) {
            AllVideosView(category: category, onTap: onTap)
        }
    }

    // MARK: - Header

    private var rowHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(LunaFont.title3())
                    .foregroundColor(.lunaTextPrimary)

                if let subtitle = category.subtitle {
                    Text(subtitle)
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)
                }
            }
            Spacer()
            Button {
                LunaHaptic.light()
                showAll = true
            } label: {
                HStack(spacing: 3) {
                    Text("Se alla")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaAccentLight)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.lunaAccentLight)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Row Content

    @ViewBuilder
    private var rowContent: some View {
        switch category.style {
        case .continueWatching:
            continueWatchingRow
        case .top10:
            top10Row
        case .featured:
            featuredRow
        case .wideCard:
            wideRow
        case .standard:
            standardRow
        }
    }

    private var standardRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(category.contents) { content in
                    Button { onTap(content) } label: {
                        PosterCard(content: content)
                    }
                    .buttonStyle(LunaPressStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var wideRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(category.contents) { content in
                    Button { onTap(content) } label: {
                        WideCard(content: content)
                    }
                    .buttonStyle(LunaPressStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var top10Row: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(category.contents.enumerated()), id: \.element.id) { index, content in
                    Button { onTap(content) } label: {
                        Top10Card(content: content, rank: index + 1)
                    }
                    .buttonStyle(LunaPressStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var featuredRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(category.contents) { content in
                    Button { onTap(content) } label: {
                        FeaturedCard(content: content)
                    }
                    .buttonStyle(LunaPressStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var continueWatchingRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(category.contents) { content in
                    Button {
                        LunaHaptic.light()
                        onTap(content)
                    } label: {
                        ContinueWatchingCard(content: content)
                    }
                    .buttonStyle(LunaPressStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - All Videos View

struct AllVideosView: View {
    let category: ContentCategory
    let onTap: (LunaContent) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedContent: LunaContent? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var sortedContents: [LunaContent] {
        category.contents.sorted {
            ($0.recordingDate ?? Date.distantPast) > ($1.recordingDate ?? Date.distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lunaBackground.ignoresSafeArea()

                if category.contents.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(sortedContents) { content in
                                Button {
                                    LunaHaptic.light()
                                    selectedContent = content
                                } label: {
                                    videoCell(content)
                                }
                                .buttonStyle(LunaPressStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") { dismiss() }
                        .foregroundColor(.lunaAccentLight)
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedContent) { content in
            ContentDetailView(content: content)
        }
    }

    private func videoCell(_ content: LunaContent) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w * (9.0 / 16.0)

            ZStack(alignment: .bottomLeading) {
                // Real Mux thumbnail with shimmer and gradient fallback
                MuxThumbnailImage(
                    playbackID: content.muxPlaybackID,
                    fallbackGradient: content.thumbnailGradient,
                    width: w,
                    height: h
                )

                // Overlay gradient
                LinearGradient(
                    colors: [.clear, .black.opacity(0.80)],
                    startPoint: .init(x: 0, y: 0.35),
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(content.title)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let date = content.recordingDate {
                        HStack(spacing: 3) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 7))
                                .foregroundColor(.lunaWarm)
                            Text(LunaAge.ageShort(at: date))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(.lunaWarm)
                        }
                    } else {
                        Text(content.duration)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 7)
                .padding(.bottom, 7)

                if content.isNew {
                    VStack {
                        HStack {
                            Text("NY")
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.lunaAccent)
                                .cornerRadius(3)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(5)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .aspectRatio(16/9, contentMode: .fit)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 44))
                .foregroundStyle(LinearGradient.lunaAccentGradient)
                .opacity(0.5)
            Text("Inga videor här")
                .font(LunaFont.title2())
                .foregroundColor(.lunaTextPrimary)
        }
    }
}
