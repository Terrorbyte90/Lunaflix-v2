import SwiftUI

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @State private var selectedContent: LunaContent? = nil
    @FocusState private var searchFocused: Bool

    // 2 columns for genre grid, 3 for results (wider posters)
    private let resultColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    private let genreColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            Color.lunaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                searchHeader

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        if vm.isEmptySearch {
                            trendingSection
                        } else {
                            if vm.results.isEmpty {
                                emptyState
                            } else {
                                resultsGrid
                            }
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
        }
        .sheet(item: $selectedContent) { content in
            ContentDetailView(content: content)
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Utforska")
                    .font(LunaFont.hero())
                    .foregroundColor(.lunaTextPrimary)
                Spacer()
                if !vm.isEmptySearch {
                    Button {
                        searchFocused = false
                        vm.clearFilters()
                    } label: {
                        Text("Avbryt")
                            .font(LunaFont.body())
                            .foregroundColor(.lunaAccentLight)
                    }
                    .buttonStyle(LunaPressStyle())
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .animation(.lunaSnappy, value: vm.isEmptySearch)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(searchFocused ? .lunaAccentLight : .lunaTextMuted)
                    .animation(.lunaSnappy, value: searchFocused)

                TextField("Sök bland Lunas klipp...", text: $vm.query)
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextPrimary)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .tint(.lunaAccentLight)
                    .onSubmit { searchFocused = false }

                if !vm.query.isEmpty {
                    Button {
                        withAnimation(.lunaSnappy) { vm.query = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.lunaTextMuted)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.lunaCard)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        searchFocused ? Color.lunaAccentLight.opacity(0.5) : Color.white.opacity(0.07),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 16)
            .animation(.lunaSnappy, value: searchFocused)

        }
        .padding(.bottom, 8)
        .background(Color.lunaBackground)
    }

    // MARK: - Genre Grid

    private var genreGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bläddra efter genre")
                .font(LunaFont.title3())
                .foregroundColor(.lunaTextPrimary)
                .padding(.horizontal, 16)

            LazyVGrid(columns: genreColumns, spacing: 10) {
                ForEach(vm.featuredGenres, id: \.rawValue) { genre in
                    GenreCard(
                        genre: genre,
                        isSelected: vm.selectedGenre == genre
                    ) {
                        LunaHaptic.selection()
                        withAnimation(.lunaSnappy) {
                            vm.selectedGenre = (vm.selectedGenre == genre) ? nil : genre
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Trending

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
                Text("Senaste videor")
                    .font(LunaFont.title3())
                    .foregroundColor(.lunaTextPrimary)
            }
            .padding(.horizontal, 16)

            // Horizontal scroll of wide cards for trending
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.trendingContent) { content in
                        Button {
                            LunaHaptic.light()
                            selectedContent = content
                        } label: {
                            WideCard(content: content, width: 250, height: 145)
                        }
                        .buttonStyle(LunaPressStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Results Grid

    private var resultsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.results.count) resultat")
                        .font(LunaFont.title3())
                        .foregroundColor(.lunaTextPrimary)
                    if !vm.query.isEmpty {
                        Text("för \"\(vm.query)\"")
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaTextMuted)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: resultColumns, spacing: 10) {
                ForEach(vm.results) { content in
                    Button {
                        LunaHaptic.light()
                        selectedContent = content
                    } label: {
                        // Fixed height posters in grid
                        PosterCard(content: content, width: 110, height: 160)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LunaPressStyle())
                }
            }
            .padding(.horizontal, 16)
            .animation(.lunaSnappy, value: vm.results.map(\.id))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 50)

            ZStack {
                Circle()
                    .fill(Color.lunaCard)
                    .frame(width: 90, height: 90)
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
            }
            .lunaGlow(color: .lunaAccent, radius: 15)

            VStack(spacing: 8) {
                Text("Inga resultat")
                    .font(LunaFont.title2())
                    .foregroundColor(.lunaTextPrimary)

                Text("Prova ett annat sökord\neller ändra dina filter")
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                LunaHaptic.light()
                vm.clearFilters()
            } label: {
                Text("Rensa filter")
                    .accentButton()
            }
            .buttonStyle(LunaPressStyle(scale: 0.97))
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Chips

    private func filterChip(_ text: String, icon: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(LunaFont.caption())
                .foregroundColor(.lunaAccentLight)
            Button(action: onRemove) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.lunaAccentLight)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.lunaAccent.opacity(0.18))
        .cornerRadius(20)
        .overlay(Capsule().stroke(Color.lunaAccentLight.opacity(0.35), lineWidth: 1))
    }

}

// MARK: - Genre Card

struct GenreCard: View {
    let genre: Genre
    var isSelected: Bool = false
    let onTap: () -> Void

    private let styleMap: [Genre: ThumbnailStyle] = [
        .action: .rose, .adventure: .amber, .animation: .violet, .comedy: .emerald,
        .crime: .crimson, .documentary: .teal, .drama: .blue, .fantasy: .purple,
        .horror: .crimson, .mystery: .ocean, .romance: .rose, .scifi: .indigo, .thriller: .indigo
    ]

    var body: some View {
        Button(action: onTap) {
            ZStack {
                let style = styleMap[genre] ?? .purple

                Rectangle()
                    .fill(style.gradient)
                    .cornerRadius(12)

                // Decorative blob
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 70)
                    .offset(x: 36, y: -24)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: genreIcon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                        Text(genre.displayName)
                            .font(LunaFont.title3())
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(14)

                // Selected checkmark
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(style.accentColor.opacity(0.8))
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 90)
        }
        .buttonStyle(LunaPressStyle())
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 2)
        )
        .animation(.lunaSnappy, value: isSelected)
    }

    private var genreIcon: String {
        switch genre {
        case .action: return "bolt.fill"
        case .adventure: return "map.fill"
        case .animation: return "wand.and.stars"
        case .comedy: return "face.smiling.fill"
        case .crime: return "magnifyingglass.circle.fill"
        case .documentary: return "camera.fill"
        case .drama: return "theatermasks.fill"
        case .fantasy: return "sparkles"
        case .horror: return "moon.fill"
        case .mystery: return "questionmark.circle.fill"
        case .romance: return "heart.fill"
        case .scifi: return "antenna.radiowaves.left.and.right"
        case .thriller: return "eye.fill"
        }
    }
}
