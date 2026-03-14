import SwiftUI

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @State private var selectedContent: LunaContent? = nil
    @FocusState private var searchFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            Color.lunaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                searchHeader

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if vm.isEmptySearch {
                            // Default: genre grid + trending
                            genreGrid
                            trendingSection
                        } else {
                            // Active search/filter results
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
        VStack(spacing: 12) {
            HStack {
                Text("Utforska")
                    .font(LunaFont.hero())
                    .foregroundColor(.lunaTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(searchFocused ? .lunaAccentLight : .lunaTextMuted)

                TextField("Sök filmer, serier...", text: $vm.query)
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextPrimary)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .tint(.lunaAccentLight)

                if !vm.query.isEmpty {
                    Button {
                        withAnimation(.lunaSnappy) {
                            vm.query = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.lunaTextMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.lunaCard)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(searchFocused ? Color.lunaAccentLight.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .animation(.lunaSnappy, value: searchFocused)

            // Filter chips
            if vm.hasActiveFilter {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let genre = vm.selectedGenre {
                            filterChip(genre.displayName) { vm.selectedGenre = nil }
                        }
                        if let type = vm.selectedType {
                            filterChip(type.rawValue) { vm.selectedType = nil }
                        }
                        Button {
                            vm.clearFilters()
                        } label: {
                            Text("Rensa")
                                .font(LunaFont.caption())
                                .foregroundColor(.lunaTextMuted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Type filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    typeChip(nil, label: "Alla")
                    ForEach(vm.allTypes, id: \.rawValue) { type in
                        typeChip(type, label: type.rawValue)
                    }
                }
                .padding(.horizontal, 16)
            }
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

            let gridCols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

            LazyVGrid(columns: gridCols, spacing: 12) {
                ForEach(vm.featuredGenres, id: \.rawValue) { genre in
                    GenreCard(genre: genre) {
                        withAnimation(.lunaSnappy) {
                            vm.selectedGenre = (vm.selectedGenre == genre) ? nil : genre
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.lunaAccentLight, lineWidth: vm.selectedGenre == genre ? 2 : 0)
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Trending

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.lunaGold)
                Text("Trending nu")
                    .font(LunaFont.title3())
                    .foregroundColor(.lunaTextPrimary)
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.trendingContent) { content in
                    GeometryReader { geo in
                        Button { selectedContent = content } label: {
                            PosterCard(content: content, width: geo.size.width, height: 160)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 200)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Results Grid

    private var resultsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(vm.results.count) resultat")
                    .font(LunaFont.title3())
                    .foregroundColor(.lunaTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(vm.results) { content in
                    GeometryReader { geo in
                        Button { selectedContent = content } label: {
                            PosterCard(content: content, width: geo.size.width, height: 160)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 200)
                }
            }
            .padding(.horizontal, 16)
            .animation(.lunaSnappy, value: vm.results.map(\.id))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)

            ZStack {
                Circle()
                    .fill(Color.lunaCard)
                    .frame(width: 80, height: 80)
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
            }

            Text("Inga resultat")
                .font(LunaFont.title2())
                .foregroundColor(.lunaTextPrimary)

            Text("Prova att söka på ett annat sätt\neller ändra dina filter")
                .font(LunaFont.body())
                .foregroundColor(.lunaTextMuted)
                .multilineTextAlignment(.center)

            Button { vm.clearFilters() } label: {
                Text("Rensa filter")
                    .accentButton()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Chips

    private func filterChip(_ text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(LunaFont.caption())
                .foregroundColor(.lunaAccentLight)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.lunaAccentLight)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.lunaAccent.opacity(0.2))
        .cornerRadius(20)
        .overlay(Capsule().stroke(Color.lunaAccentLight.opacity(0.4), lineWidth: 1))
    }

    private func typeChip(_ type: ContentType?, label: String) -> some View {
        let isSelected = vm.selectedType == type
        return Button {
            withAnimation(.lunaSnappy) {
                vm.selectedType = isSelected ? nil : type
            }
        } label: {
            Text(label)
                .font(LunaFont.caption())
                .foregroundColor(isSelected ? .white : .lunaTextSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.lunaAccent : Color.lunaCard)
                .cornerRadius(20)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Genre Card

struct GenreCard: View {
    let genre: Genre
    let onTap: () -> Void

    private let gradients: [Genre: ThumbnailStyle] = [
        .action: .rose, .adventure: .amber, .animation: .violet, .comedy: .emerald,
        .crime: .crimson, .documentary: .teal, .drama: .blue, .fantasy: .purple,
        .horror: .crimson, .mystery: .ocean, .romance: .rose, .scifi: .indigo, .thriller: .indigo
    ]

    var body: some View {
        Button(action: onTap) {
            ZStack {
                let style = gradients[genre] ?? .purple
                Rectangle()
                    .fill(style.gradient)
                    .cornerRadius(12)

                // Decorative circles
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 60)
                    .offset(x: 30, y: -20)

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
            }
            .frame(height: 90)
        }
        .buttonStyle(.plain)
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
