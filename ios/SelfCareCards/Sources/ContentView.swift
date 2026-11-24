import SwiftUI

struct RootView: View {
    @StateObject private var store = DeckStore()

    var body: some View {
        TabView {
            NavigationStack { DrawScreen() }
                .tabItem { Label("Draw", systemImage: "rectangle.stack") }
            NavigationStack { BrowseScreen() }
                .tabItem { Label("Areas", systemImage: "square.grid.2x2") }
            NavigationStack { SavedScreen() }
                .tabItem { Label("Saved", systemImage: "bookmark") }
            NavigationStack { SourceDecksScreen() }
                .tabItem { Label("Decks", systemImage: "books.vertical") }
            NavigationStack { AboutScreen() }
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .environmentObject(store)
        .tint(AppPalette.sage)
        .toolbarBackground(AppPalette.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(AppPalette.paper)
    }
}

struct DrawScreen: View {
    @EnvironmentObject private var store: DeckStore
    @State private var selectedArea = "All areas"
    @State private var selectedID: String?

    private var availableCards: [CardItem] {
        guard selectedArea != "All areas" else { return store.coreCards }
        return store.coreCards.filter { $0.category == selectedArea }
    }

    private var selectedCard: CardItem? {
        availableCards.first { $0.id == selectedID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A softer pause")
                        .font(.system(size: 29, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                    Text("Take one prompt, adapt it, or leave it for later.")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(AppPalette.muted)
                }

                Menu {
                    Button("All areas") { selectedArea = "All areas" }
                    ForEach(AreaInfo.all) { area in
                        Button(area.name.localizedCapitalized) { selectedArea = area.name }
                    }
                } label: {
                    Label(selectedArea == "All areas" ? "All five areas" : selectedArea.localizedCapitalized,
                          systemImage: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppPalette.sageDark)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 13)
                        .background(AppPalette.mist, in: Capsule())
                }
                .accessibilityLabel("Choose an area to draw from")

                if let card = selectedCard {
                    CardPanel(card: card)
                    HStack(spacing: 10) {
                        SaveCardButton(card: card)
                        ShareCardButton(card: card)
                    }
                } else if let message = store.loadError {
                    EmptyState(title: "Cards unavailable", message: message)
                } else {
                    EmptyState(title: "No cards found", message: "Choose another area and try again.")
                }

                Button(action: drawNext) {
                    Label("Draw a card", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityHint("Selects a random card from the chosen area")

                Text("No streaks, scores, or required order.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppPalette.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(AppPalette.paper.ignoresSafeArea())
        .navigationTitle("Draw")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if selectedID == nil { drawNext() } }
        .onChange(of: selectedArea) { _ in drawNext() }
    }

    private func drawNext() {
        let pool = availableCards
        guard !pool.isEmpty else { selectedID = nil; return }
        let choices = pool.filter { $0.id != selectedID }
        selectedID = (choices.randomElement() ?? pool.randomElement())?.id
    }
}

struct BrowseScreen: View {
    var body: some View {
        List {
            Section {
                ForEach(AreaInfo.all) { area in
                    NavigationLink {
                        AreaCardsScreen(area: area)
                    } label: {
                        AreaRow(area: area)
                    }
                    .listRowBackground(AppPalette.card)
                }
            } header: {
                Text("Choose what fits this moment")
                    .textCase(nil)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppPalette.paper)
        .navigationTitle("Browse areas")
    }
}

struct AreaRow: View {
    let area: AreaInfo

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: area.symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppPalette.sage)
                .frame(width: 38, height: 38)
                .background(AppPalette.mist, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(area.name.localizedCapitalized)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                Text(area.description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }
}

struct AreaCardsScreen: View {
    let area: AreaInfo
    @EnvironmentObject private var store: DeckStore

    private var cards: [CardItem] {
        store.coreCards.filter { $0.category == area.name }
    }

    var body: some View {
        List(cards) { card in
            NavigationLink {
                CardDetailScreen(card: card)
            } label: {
                CardRow(card: card)
            }
            .listRowBackground(AppPalette.card)
        }
        .scrollContentBackground(.hidden)
        .background(AppPalette.paper)
        .navigationTitle(area.name.localizedCapitalized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SourceDecksScreen: View {
    @EnvironmentObject private var store: DeckStore

    var body: some View {
        Group {
            if store.sourceDecks.isEmpty {
                EmptyState(
                    title: "No decks loaded",
                    message: store.sourceDecksLoadError ?? "No source decks are available right now."
                )
                .padding(20)
            } else {
                List(store.sourceDecks) { deck in
                    NavigationLink {
                        SourceDeckDetailScreen(deck: deck)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(deck.title)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppPalette.ink)
                            Text("\(deck.area) · \(deck.cards.count) prompts")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(AppPalette.muted)
                            Text(deck.author)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(AppPalette.sageDark)
                        }
                        .padding(.vertical, 5)
                    }
                    .listRowBackground(AppPalette.card)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppPalette.paper)
        .navigationTitle("Source decks")
    }
}

struct SourceDeckDetailScreen: View {
    let deck: SourceDeck
    @EnvironmentObject private var store: DeckStore

    var body: some View {
        List {
            Section {
                Text(deck.description)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .listRowBackground(AppPalette.card)
                Text("By \(deck.author)")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppPalette.muted)
                    .listRowBackground(AppPalette.card)
                if let url = URL(string: deck.source) {
                    Link("Open the original deck", destination: url)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .listRowBackground(AppPalette.card)
                }
            }
            Section("Prompts") {
                ForEach(store.cards(for: deck)) { card in
                    NavigationLink {
                        CardDetailScreen(card: card)
                    } label: {
                        CardRow(card: card)
                    }
                    .listRowBackground(AppPalette.card)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppPalette.paper)
        .navigationTitle(deck.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SavedScreen: View {
    @EnvironmentObject private var store: DeckStore

    private var savedCards: [CardItem] {
        store.allCards.filter { store.savedIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if savedCards.isEmpty {
                EmptyState(title: "Nothing saved yet", message: "Save a card to keep it close. Your saved list stays on this device.")
                    .padding(20)
            } else {
                List(savedCards) { card in
                    NavigationLink {
                        CardDetailScreen(card: card)
                    } label: {
                        CardRow(card: card)
                    }
                    .listRowBackground(AppPalette.card)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppPalette.paper)
        .navigationTitle("Saved cards")
    }
}

struct CardDetailScreen: View {
    let card: CardItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CardPanel(card: card)
                HStack(spacing: 10) {
                    SaveCardButton(card: card)
                    ShareCardButton(card: card)
                }
            }
            .padding(20)
        }
        .background(AppPalette.paper.ignoresSafeArea())
        .navigationTitle(card.category.localizedCapitalized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CardRow: View {
    let card: CardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppPalette.ink)
            Text(card.prompt)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppPalette.muted)
                .lineLimit(2)
        }
        .padding(.vertical, 5)
    }
}

struct CardPanel: View {
    let card: CardItem
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 25
    @ScaledMetric(relativeTo: .body) private var promptSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var reflectionSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var smallSize: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(card.category.localizedCapitalized)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(AppPalette.sage)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                Text(card.id.hasPrefix("source:") ? "SOURCE" : card.id)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppPalette.muted)
                    .fixedSize()
            }

            Text(card.title)
                .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.prompt)
                .font(.system(size: promptSize, weight: .regular, design: .rounded))
                .lineSpacing(5)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !card.reflection.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("OPTIONAL REFLECTION")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(AppPalette.sage)
                    Text(card.reflection)
                        .font(.system(size: reflectionSize, weight: .regular, design: .rounded))
                        .italic()
                        .lineSpacing(3)
                        .foregroundStyle(AppPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { AppPalette.line.frame(height: 1) }
            }

            if !card.small.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("SMALLER VERSION")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(AppPalette.sageDark)
                    Text(card.small)
                        .font(.system(size: smallSize, weight: .medium, design: .rounded))
                        .lineSpacing(3)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.mist, in: RoundedRectangle(cornerRadius: 16))
            }

            if let sourceCredit = card.sourceCredit {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Adapted from \(sourceCredit)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppPalette.muted)
                    if let sourceURL = card.sourceURL, let url = URL(string: sourceURL) {
                        Link("View the original source", destination: url)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppPalette.sageDark)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppPalette.line, lineWidth: 1))
    }
}

struct SaveCardButton: View {
    let card: CardItem
    @EnvironmentObject private var store: DeckStore

    var body: some View {
        Button {
            store.toggleSaved(card)
        } label: {
            Label(store.isSaved(card) ? "Saved" : "Save", systemImage: store.isSaved(card) ? "bookmark.fill" : "bookmark")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.sage)
        .accessibilityLabel(store.isSaved(card) ? "Remove card from saved cards" : "Save card")
    }
}

struct ShareCardButton: View {
    let card: CardItem
    @State private var showingShare = false
    @State private var activityItems: [Any] = []

    var body: some View {
        Button(action: prepareShare) {
            Label("Share", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.sage)
        .sheet(isPresented: $showingShare) {
            ActivityView(activityItems: activityItems)
                .presentationDetents([.medium, .large])
        }
    }

    private func prepareShare() {
        let renderer = ImageRenderer(content: ShareCardArtwork(card: card))
        renderer.scale = 3
        activityItems = [card.shareText]
        if let image = renderer.uiImage { activityItems.insert(image, at: 0) }
        showingShare = true
    }
}

struct ShareCardArtwork: View {
    let card: CardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SELF-CARE CARDS")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(AppPalette.sage)
            Text(card.category.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundStyle(AppPalette.muted)
                .padding(.top, 9)
            Spacer(minLength: 14)
            Text(card.title)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(card.prompt)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .lineSpacing(3)
                .foregroundStyle(AppPalette.ink)
                .padding(.top, 9)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            if !card.reflection.isEmpty {
                Text("OPTIONAL REFLECTION")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(AppPalette.sage)
                Text(card.reflection)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .italic()
                    .foregroundStyle(AppPalette.muted)
                    .padding(.top, 4)
            }
            if !card.small.isEmpty {
                Text("SMALLER VERSION · \(card.small)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppPalette.sageDark)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.mist, in: RoundedRectangle(cornerRadius: 11))
                    .padding(.top, 11)
            }
            Spacer(minLength: 12)
            Text(card.sourceCredit.map { "Adapted from \($0)" } ?? "Take what helps. Leave the rest.")
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(AppPalette.muted)
                .lineLimit(2)
        }
        .padding(25)
        .frame(width: 360, height: 450)
        .background(AppPalette.paper)
    }
}

struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(AppPalette.ink)
            Text(message)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(AppPalette.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .background(configuration.isPressed ? AppPalette.sageDark : AppPalette.sage,
                        in: RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct AboutScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AboutCard(title: "Use this gently") {
                    Text("Choose an action, try the smaller version, or skip it. There is no required order, streak, score, or productivity target.")
                    Text("Sensory needs and stims are useful information. Masking can be protective; this app never asks you to unmask or explore anything that does not feel safe.")
                }
                AboutCard(title: "Jungian ideas, used gently") {
                    Text("Individuation can mean noticing what fits your own life. Persona can describe roles that help us navigate. Shadow is used here for overlooked feelings or strengths, not as a label for something bad.")
                    Text("These are reflective prompts, not a fixed interpretation, diagnosis, or substitute for clinical care. You do not need to disclose or dig into painful memories.")
                }
                AboutCard(title: "A personal fit") {
                    Text("“The shoe that fits one person pinches another; there is no recipe for living that suits all cases.”")
                        .italic()
                    Text("C.G. Jung, Modern Man in Search of a Soul, “Problems of Modern Psychotherapy” (1933).")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppPalette.muted)
                }
                AboutCard(title: "Notice, don't force") {
                    Text("“One does not become enlightened by imagining figures of light, but by making the darkness conscious.”")
                        .italic()
                    Text("C.G. Jung, “The Philosophical Tree,” Collected Works, vol. 13, par. 335.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppPalette.muted)
                }
                AboutCard(title: "Credit and privacy") {
                    Text("The nine optional source decks are credited to Alora Young / NeuroScouts and link back to their original PDFs. The Care Quest PDF cover also credits SEHTLO WEBS MD.")
                    Text("Your saved cards stay on this device. The app does not use an account or send your saved-card list anywhere.")
                }
            }
            .padding(20)
        }
        .background(AppPalette.paper.ignoresSafeArea())
        .navigationTitle("About")
    }
}

struct AboutCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(AppPalette.ink)
            content
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppPalette.line, lineWidth: 1))
    }
}
