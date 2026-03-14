import SwiftUI

struct ContentRowView: View {
    let category: ContentCategory
    let onTap: (LunaContent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            rowHeader
            rowContent
        }
        .padding(.top, 16)
    }

    // MARK: - Header

    private var rowHeader: some View {
        HStack(alignment: .bottom) {
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
                // See all
            } label: {
                Text("Se alla")
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaAccentLight)
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
                    .buttonStyle(.plain)
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
                    .buttonStyle(.plain)
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
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var featuredRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(category.contents) { content in
                    Button { onTap(content) } label: {
                        FeaturedCard(content: content)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var continueWatchingRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(category.contents) { content in
                    Button { onTap(content) } label: {
                        ContinueWatchingCard(content: content)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
