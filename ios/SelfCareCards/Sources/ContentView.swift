import SwiftUI
import CoreGraphics
import CoreText
import AVFoundation

private enum BundledFonts {
    static let display = "ArchivoBlack-Regular"
    static let body = "SpaceGrotesk-Light"
    static let registration: Void = {
        register(name: "ArchivoBlack", extension: "b64")
        register(name: "SpaceGroteskVariable", extension: "b64")
    }()
    private static func register(name: String, extension fileExtension: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension),
              let encoded = try? String(contentsOf: url, encoding: .utf8),
              let data = Data(base64Encoded: encoded),
              let provider = CGDataProvider(data: data as CFData),
              let font = CGFont(provider) else {
            NSLog("Self-Care Cards: bundled font %@ could not be loaded.", name)
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            NSLog("Self-Care Cards: font %@ registration reported an existing registration or error.", name)
        }
    }
}

struct AppBackdrop: View {
    var body: some View {
        ZStack {
            AppPalette.paper.ignoresSafeArea()
            Canvas { context, size in
                var grid = Path()
                for x in stride(from: CGFloat.zero, through: size.width, by: 28) {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: CGFloat.zero, through: size.height, by: 28) {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.02)), lineWidth: 0.5)
            }
            RadialGradient(
                colors: [AppPalette.sage.opacity(0.06), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case draw, explore, jung, saved, about
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .draw: "rectangle.stack"
        case .explore: "square.grid.2x2"
        case .jung: "sparkle"
        case .saved: "bookmark"
        case .about: "info.circle"
        }
    }
}

struct AppTabBar: View {
    @Binding var selection: AppTab
    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol).font(.system(size: 18, weight: .semibold))
                        Text(tab.title).font(.system(size: 10, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selection == tab ? AppPalette.sage : AppPalette.muted)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(selection == tab ? AppPalette.mist : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(5)
        .background(AppPalette.card, in: Capsule())
        .overlay(Capsule().stroke(AppPalette.line, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 7)
        .padding(.bottom, 8)
        .background(AppPalette.paper.ignoresSafeArea(edges: .bottom))
    }
}

struct RootView: View {
    @StateObject private var store = DeckStore()
    @State private var selectedTab: AppTab = .draw

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { DrawScreen() }
                .tabItem { Label("Draw", systemImage: "rectangle.stack") }
                .tag(AppTab.draw)
            NavigationStack { BrowseScreen() }
                .tabItem { Label("Explore", systemImage: "square.grid.2x2") }
                .tag(AppTab.explore)
            NavigationStack { JungQuotesScreen() }
                .tabItem { Label("Jung", systemImage: "sparkle") }
                .tag(AppTab.jung)
            NavigationStack { SavedScreen() }
                .tabItem { Label("Saved", systemImage: "bookmark") }
                .tag(AppTab.saved)
            NavigationStack { AboutScreen() }
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(AppTab.about)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(selection: $selectedTab)
        }
        .environmentObject(store)
        .onAppear { _ = BundledFonts.registration }
        .tint(AppPalette.sage)
        .environment(\.colorScheme, .dark)
        .toolbarBackground(AppPalette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(AppBackdrop())
    }
}

struct PWAFilterChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.custom(BundledFonts.body, size: 17, relativeTo: .body).weight(.semibold))
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? AppPalette.paper : AppPalette.ink)
            .background(isSelected ? AppPalette.sage : AppPalette.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? AppPalette.sage : AppPalette.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private final class CardSpeechPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ card: CardItem, voiceID: String, rate: Double) {
        stop()
        let text = [card.title, card.prompt, card.small.isEmpty ? nil : "Smaller version: \(card.small)"]
            .compactMap { $0 }
            .joined(separator: ". ")
        let utterance = AVSpeechUtterance(string: text)
        if !voiceID.isEmpty { utterance.voice = AVSpeechSynthesisVoice.speechVoices().first { $0.identifier == voiceID } }
        utterance.rate = Float(min(1.25, max(0.75, rate))) * AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

struct ReadAloudControls: View {
    let card: CardItem?
    @AppStorage("careSpeechVoice") private var voiceID = ""
    @AppStorage("careSpeechRate") private var rate = 1.0
    @StateObject private var player = CardSpeechPlayer()

    private var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().sorted {
            ($0.language + $0.name).localizedCaseInsensitiveCompare($1.language + $1.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                guard let card else { return }
                if player.isSpeaking { player.stop() } else { player.speak(card, voiceID: voiceID, rate: rate) }
            } label: {
                Label(player.isSpeaking ? "Stop reading" : "Read card aloud",
                      systemImage: player.isSpeaking ? "stop.fill" : "speaker.wave.2")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.sage)
            .disabled(card == nil)
            .accessibilityHint("Reads the card, prompt, and smaller version aloud")

            Text("VOICE & SPEED")
                .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(AppPalette.muted)
            Picker("Voice", selection: $voiceID) {
                Text("System default").tag("")
                ForEach(voices, id: \.identifier) { voice in
                    Text("\(voice.name) · \(voice.language)").tag(voice.identifier)
                }
            }
            .pickerStyle(.menu)
            .tint(AppPalette.sage)
            .accessibilityLabel("Read-aloud voice")

            HStack(spacing: 10) {
                Text("Speed").foregroundStyle(AppPalette.muted)
                Slider(value: $rate, in: 0.75...1.25, step: 0.05).tint(AppPalette.sage)
                    .accessibilityLabel("Read-aloud speed")
                Text(String(format: "%.2f×", rate))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppPalette.ink).monospacedDigit()
            }
        }
        .font(.system(size: 13, design: .rounded))
        .onChange(of: card?.id) { _ in player.stop() }
        .onDisappear { player.stop() }
    }
}

struct NeedOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let categories: [String]
}

struct CardFocusScreen: View {
    let card: CardItem
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    CardPanel(card: card)
                    HStack(spacing: 10) { SaveCardButton(card: card); ShareCardButton(card: card) }
                }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .background(AppBackdrop())
            .navigationTitle("Focus card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.keyboardShortcut(.escape, modifiers: []).tint(AppPalette.sage) } }
        }
        .environment(\.colorScheme, .dark)
    }
}

struct DrawScreen: View {
    @EnvironmentObject private var store: DeckStore
    @State private var selectedFilter = "All cards"
    @State private var selectedNeed: String?
    @State private var selectedID: String?
    @State private var previousDraws: [(id: String, filter: String, need: String?)] = []
    @State private var seenIDs = Set<String>()
    @State private var focusCard: CardItem?
    @State private var areaPickerExpanded = false
    @State private var accessibilityExpanded = true

    private let filterLabels = [
        "All cards", "Sensory reset", "Low-energy care", "Music + movement",
        "Thoughts + big feelings", "Social recovery"
    ]
    private let categoryByFilter = [
        "Sensory reset": "SENSORY RESET",
        "Low-energy care": "LOW-ENERGY CARE",
        "Music + movement": "MUSIC + MOVEMENT",
        "Thoughts + big feelings": "THOUGHTS + BIG FEELINGS",
        "Social recovery": "SOCIAL RECOVERY + SELF-ACCEPTANCE"
    ]
    private let needs = [
        NeedOption(id: "settle", title: "Settle", subtitle: "Sensory reset", categories: ["SENSORY RESET"]),
        NeedOption(id: "start", title: "Start small", subtitle: "Low energy · movement", categories: ["LOW-ENERGY CARE", "MUSIC + MOVEMENT"]),
        NeedOption(id: "untangle", title: "Untangle", subtitle: "Thoughts · big feelings", categories: ["THOUGHTS + BIG FEELINGS"]),
        NeedOption(id: "recover", title: "Recover", subtitle: "Social recovery", categories: ["SOCIAL RECOVERY + SELF-ACCEPTANCE"])
    ]

    private var activeNeed: NeedOption? { needs.first { $0.id == selectedNeed } }
    private var availableCards: [CardItem] {
        if let need = activeNeed { return store.coreCards.filter { need.categories.contains($0.category) } }
        guard let category = categoryByFilter[selectedFilter] else { return store.coreCards }
        return store.coreCards.filter { $0.category == category }
    }
    private var selectedCard: CardItem? { availableCards.first { $0.id == selectedID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SELF-CARE CARDS")
                        .font(.custom(BundledFonts.display, size: 27)).tracking(-0.4).foregroundStyle(AppPalette.ink)
                    Text("A neurodivergent-first deck")
                        .font(.custom(BundledFonts.body, size: 16, relativeTo: .subheadline).weight(.semibold))
                        .foregroundStyle(AppPalette.sage)
                    Text("One small prompt for this moment. Skip, adapt, or stop whenever you want.")
                        .font(.custom(BundledFonts.body, size: 14, relativeTo: .body).weight(.regular))
                        .lineSpacing(2).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Image(systemName: "iphone.and.arrow.forward").foregroundStyle(AppPalette.sage)
                    Text("OFFLINE READY · CONTENT ON DEVICE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.7).foregroundStyle(AppPalette.muted)
                    Spacer(minLength: 4)
                    Circle().fill(AppPalette.sage).frame(width: 7, height: 7)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Offline ready. Cards and collections are stored on this device.")

                VStack(alignment: .leading, spacing: 8) {
                    Text("WHAT DO YOU NEED RIGHT NOW?")
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.1).foregroundStyle(AppPalette.muted)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(needs) { need in
                            Button {
                                selectNeed(need.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(need.title).font(.custom(BundledFonts.body, size: 17, relativeTo: .body).weight(.semibold))
                                    Text(need.subtitle).font(.custom(BundledFonts.body, size: 12, relativeTo: .caption).weight(.regular))
                                        .foregroundStyle(selectedNeed == need.id ? AppPalette.paper.opacity(0.78) : AppPalette.muted)
                                }
                                .foregroundStyle(selectedNeed == need.id ? AppPalette.paper : AppPalette.ink)
                                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                .padding(.horizontal, 12)
                                .background(selectedNeed == need.id ? AppPalette.sage : AppPalette.card, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedNeed == need.id ? AppPalette.sage : AppPalette.line, lineWidth: 1))
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(need.title), \(need.subtitle)")
                            .accessibilityAddTraits(selectedNeed == need.id ? .isSelected : [])
                        }
                    }
                }

                DisclosureGroup(isExpanded: $areaPickerExpanded) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(filterLabels, id: \.self) { label in
                            Button {
                                selectFilter(label)
                            } label: {
                                PWAFilterChip(title: label, isSelected: selectedNeed == nil && selectedFilter == label)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Filter: \(label)")
                        }
                    }.padding(.top, 9)
                } label: {
                    Text("Choose a specific area")
                        .font(.custom(BundledFonts.body, size: 17, relativeTo: .body).weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sage)
                .padding(13)
                .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppPalette.line, lineWidth: 1))

                DisclosureGroup(isExpanded: $accessibilityExpanded) {
                    ReadAloudControls(card: selectedCard)
                        .padding(.top, 10)
                } label: {
                    HStack {
                        Text("Accessibility").font(.custom(BundledFonts.body, size: 16, relativeTo: .body).weight(.semibold))
                        Spacer()
                        Text("Read-aloud options").font(.system(size: 11, design: .rounded)).foregroundStyle(AppPalette.muted)
                    }.foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sage)
                .padding(13)
                .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppPalette.line, lineWidth: 1))

                HStack(spacing: 8) {
                    Button { drawNext() } label: {
                        Label("Draw a card", systemImage: "arrow.clockwise").frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint("Selects a random card from the chosen category")
                    .keyboardShortcut(".", modifiers: [])

                    Button { drawNext() } label: {
                        Text("Not this one").font(.custom(BundledFonts.body, size: 14, relativeTo: .body).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .foregroundStyle(AppPalette.ink).background(AppPalette.card, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppPalette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Skips this prompt and draws another")
                }

                if let card = selectedCard {
                    if !previousDraws.isEmpty {
                        Button(action: showPrevious) {
                            Label("Previous card", systemImage: "arrow.uturn.backward")
                                .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(AppPalette.sage)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(",", modifiers: [])
                    }
                    CardPanel(card: card)
                    HStack(spacing: 8) {
                        SaveCardButton(card: card)
                        ShareCardButton(card: card)
                        Button { focusCard = card } label: {
                            Label("Focus", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 13, weight: .semibold, design: .rounded)).frame(maxWidth: .infinity, minHeight: 42)
                        }.buttonStyle(.bordered).tint(AppPalette.sage).accessibilityLabel("Focus card")
                    }
                    Button(action: drawSimilar) {
                        Label("Another like this", systemImage: "sparkles")
                            .font(.system(size: 14, weight: .semibold, design: .rounded)).frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.bordered).tint(AppPalette.sage)
                } else if let message = store.loadError {
                    EmptyState(title: "Cards unavailable", message: message)
                } else {
                    EmptyState(title: "No cards found", message: "Choose another category and try again.")
                }

                Text("100 cards · 20 in each area · no streaks, scores, or required order.")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(AppPalette.muted)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }
            .padding(.top, 14).padding(.bottom, 24)
            .frame(maxWidth: 620, alignment: .leading).frame(maxWidth: .infinity).padding(.horizontal, 16)
        }
        .background(AppBackdrop())
        .navigationTitle("Draw").navigationBarTitleDisplayMode(.inline)
        .onAppear { if selectedID == nil { drawNext(recordPrevious: false) } }
        .fullScreenCover(item: $focusCard) { CardFocusScreen(card: $0) }
    }

    private func selectNeed(_ needID: String) {
        recordCurrent()
        selectedNeed = needID
        selectedFilter = "All cards"
        drawNext(recordPrevious: false)
    }

    private func selectFilter(_ filter: String) {
        recordCurrent()
        selectedNeed = nil
        selectedFilter = filter
        drawNext(recordPrevious: false)
        areaPickerExpanded = false
    }

    private func recordCurrent() {
        if let selectedID { previousDraws.append((selectedID, selectedFilter, selectedNeed)) }
    }

    private func drawNext(recordPrevious: Bool = true) {
        let pool = availableCards
        guard !pool.isEmpty else { selectedID = nil; return }
        if recordPrevious { recordCurrent() }
        var choices = pool.filter { !seenIDs.contains($0.id) }
        if choices.isEmpty {
            seenIDs.subtract(pool.map(\.id))
            choices = pool
        }
        guard let next = choices.randomElement() else { return }
        selectedID = next.id
        seenIDs.insert(next.id)
    }

    private func showPrevious() {
        guard let previous = previousDraws.popLast() else { return }
        selectedFilter = previous.filter
        selectedNeed = previous.need
        selectedID = previous.id
    }

    private func drawSimilar() {
        guard let card = selectedCard else { return }
        recordCurrent()
        let pool = store.coreCards.filter { $0.category == card.category && $0.id != card.id }
        guard !pool.isEmpty else { return }
        selectedNeed = nil
        selectedFilter = filterLabels.first { categoryByFilter[$0] == card.category } ?? "All cards"
        let choices = pool.filter { !seenIDs.contains($0.id) }
        let next = (choices.isEmpty ? pool : choices).randomElement()!
        selectedID = next.id
        seenIDs.insert(next.id)
    }
}

struct BrowseScreen: View {
    @EnvironmentObject private var store: DeckStore
    @State private var searchText = ""
    private var filteredDecks: [SourceDeck] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return store.sourceDecks }
        return store.sourceDecks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.area.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SOURCE LIBRARY · \(store.sourceDecks.count) COLLECTIONS").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.7).foregroundStyle(AppPalette.sage)
                    Text("Explore by collection").font(.system(size: 28, weight: .bold, design: .rounded)).tracking(-0.6).foregroundStyle(AppPalette.ink)
                    Text("Choose a collection to open its cards. Draw one at a time, and return here whenever you like.")
                        .font(.system(size: 15, design: .rounded)).lineSpacing(3).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppPalette.muted)
                    TextField("Search collections", text: $searchText).textInputAutocapitalization(.never).autocorrectionDisabled().foregroundStyle(AppPalette.ink)
                    if !searchText.isEmpty { Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(AppPalette.muted) }.accessibilityLabel("Clear search") }
                }.padding(12).background(AppPalette.card, in: RoundedRectangle(cornerRadius: 12))
                if store.sourceDecks.isEmpty {
                    EmptyState(title: "Collections unavailable", message: store.sourceDecksLoadError ?? "The optional reference collections are not available in this build.")
                } else if filteredDecks.isEmpty {
                    EmptyState(title: "No matching collections", message: "Try another title, area, or keyword.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(filteredDecks) { deck in
                            NavigationLink { SourceDeckDetailScreen(deck: deck) } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(deck.title).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
                                        Text("\(deck.area) · \(deck.cards.count) cards").font(.system(size: 12, design: .rounded)).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 8)
                                    Text("OPEN ›").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(AppPalette.sage)
                                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(AppPalette.line, lineWidth: 1))
                            }.buttonStyle(.plain).accessibilityLabel("\(deck.title), \(deck.cards.count) cards. Open collection")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("SOURCE NOTES").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(AppPalette.sage)
                    Text("Some collections are adapted with permission from Alora Young’s NeuroScouts resources. Each draw links back to its original source.")
                        .font(.system(size: 13, design: .rounded)).lineSpacing(3).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
                    if let url = URL(string: "https://alorayoung.org/free-tools.html#decks") {
                        Link("Open the original free-tools page", destination: url).font(.system(size: 13, weight: .medium, design: .rounded)).tint(AppPalette.sage)
                    }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(AppPalette.line, lineWidth: 1))
            }.padding(.vertical, 20).frame(maxWidth: 620, alignment: .leading).frame(maxWidth: .infinity).padding(.horizontal, 20)
        }.background(AppBackdrop()).navigationTitle("Explore").navigationBarTitleDisplayMode(.inline)
    }
}

struct JungQuotesScreen: View {
    @EnvironmentObject private var store: DeckStore
    @State private var selectedEntryID: String?
    private var currentEntry: JungEntry? {
        if let selectedEntryID, let entry = store.jungEntries.first(where: { $0.id == selectedEntryID }) { return entry }
        return store.jungEntries.first
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Jung // signal").font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(2).foregroundStyle(AppPalette.sage)
                Text("A thought to sit with").font(.system(size: 25, weight: .semibold, design: .rounded)).foregroundStyle(AppPalette.ink)
                Text("Take what fits. Leave the rest. Randomise another entry whenever you want.")
                    .font(.system(size: 15, design: .rounded)).lineSpacing(3).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
                if let entry = currentEntry {
                    VStack(alignment: .leading, spacing: 15) {
                        Text(entry.kindLabel).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(AppPalette.sage)
                        Text("“").font(.system(size: 54, weight: .medium, design: .serif)).foregroundStyle(AppPalette.sage).accessibilityHidden(true)
                        Text(entry.text).font(.custom(BundledFonts.body, size: 24, relativeTo: .title).weight(.medium)).lineSpacing(5).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
                        Rectangle().fill(AppPalette.line).frame(height: 1)
                        Text(entry.citation).font(.custom(BundledFonts.body, size: 13, relativeTo: .body)).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
                        if let url = URL(string: entry.url) {
                            Link(entry.label ?? "Open source notes", destination: url).font(.system(size: 13, weight: .medium, design: .rounded)).tint(AppPalette.sage)
                        }
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppPalette.line, lineWidth: 1))
                    HStack(spacing: 8) {
                        SaveJungEntryButton(entry: entry)
                        QuoteShareButton(quote: entry)
                    }
                    Button(action: drawAnother) {
                        Label("Randomise quote", systemImage: "arrow.clockwise").frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(PrimaryButtonStyle())
                } else {
                    EmptyState(title: "No Jung entries loaded", message: store.jungQuotesLoadError ?? store.jungReflectionsLoadError ?? "The Jung // signal collection is not available in this build.")
                }
                Text("A mix of sourced quotations and original paraphrases inspired by Jungian psychology. Paraphrases are not Jung’s exact words or clinical interpretations.")
                    .font(.system(size: 12, design: .rounded)).lineSpacing(3).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 20).frame(maxWidth: 620, alignment: .leading).frame(maxWidth: .infinity).padding(.horizontal, 20)
        }
        .background(AppBackdrop()).navigationTitle("Jung").navigationBarTitleDisplayMode(.inline)
        .onAppear { if selectedEntryID == nil { selectedEntryID = store.jungEntries.randomElement()?.id } }
    }
    private func drawAnother() {
        let entries = store.jungEntries
        let alternatives = entries.filter { $0.id != currentEntry?.id }
        selectedEntryID = (alternatives.isEmpty ? entries : alternatives).randomElement()?.id
    }
}

struct SaveJungEntryButton: View {
    let entry: JungEntry
    @EnvironmentObject private var store: DeckStore

    var body: some View {
        Button {
            store.toggleSavedID(entry.id)
        } label: {
            Label(store.savedIDs.contains(entry.id) ? "Saved" : "Save",
                  systemImage: store.savedIDs.contains(entry.id) ? "bookmark.fill" : "bookmark")
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.sage)
        .accessibilityLabel(store.savedIDs.contains(entry.id) ? "Remove reflection from saved items" : "Save reflection")
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

struct SourceDeckDetailScreen: View {
    let deck: SourceDeck
    @EnvironmentObject private var store: DeckStore
    @Environment(\.dismiss) private var dismiss
    @State private var currentCardID: String?
    @State private var previousIDs: [String] = []
    @State private var seenIDs = Set<String>()
    @State private var focusCard: CardItem?
    @State private var accessibilityExpanded = true
    private var deckCards: [CardItem] { store.cards(for: deck) }
    private var currentCard: CardItem? { deckCards.first { $0.id == currentCardID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Button { dismiss() } label: {
                    Label("All collections", systemImage: "chevron.left").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(AppPalette.sage)
                }.buttonStyle(.plain).accessibilityHint("Returns to the collection list")
                Text("SOURCE LIBRARY · \(deck.area.uppercased()) · \(deck.cards.count) CARDS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.3).foregroundStyle(AppPalette.sage).fixedSize(horizontal: false, vertical: true)
                Text(deck.title).font(.custom(BundledFonts.body, size: 27, relativeTo: .title).weight(.semibold)).tracking(-0.5).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
                Text(deck.description).font(.custom(BundledFonts.body, size: 15, relativeTo: .body)).lineSpacing(3).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
                Text("By \(deck.author)").font(.system(size: 13, design: .rounded)).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
                if let url = URL(string: deck.source) { Link("Open the original collection", destination: url).font(.system(size: 13, weight: .medium, design: .rounded)).tint(AppPalette.sage) }

                DisclosureGroup(isExpanded: $accessibilityExpanded) {
                    ReadAloudControls(card: currentCard).padding(.top, 10)
                } label: {
                    HStack {
                        Text("Accessibility").font(.custom(BundledFonts.body, size: 16, relativeTo: .body).weight(.semibold))
                        Spacer()
                        Text("Read-aloud options").font(.system(size: 11, design: .rounded)).foregroundStyle(AppPalette.muted)
                    }.foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sage).padding(13)
                .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppPalette.line, lineWidth: 1))

                HStack(spacing: 8) {
                    Button { drawFromDeck() } label: {
                        Label("Draw from this deck", systemImage: "arrow.clockwise").frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(".", modifiers: []).accessibilityHint("Draws one random card from \(deck.title)")
                    Button { drawFromDeck() } label: {
                        Text("Not this one").font(.custom(BundledFonts.body, size: 14, relativeTo: .body).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .foregroundStyle(AppPalette.ink).background(AppPalette.card, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppPalette.line, lineWidth: 1))
                    }.buttonStyle(.plain).accessibilityLabel("Not this one. Draw another card.")
                }
                Button { drawFromDeck() } label: {
                    Label("Another like this", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).frame(maxWidth: .infinity, minHeight: 42)
                }.buttonStyle(.bordered).tint(AppPalette.sage)

                if let card = currentCard {
                    if !previousIDs.isEmpty {
                        Button(action: showPrevious) {
                            Label("Previous card", systemImage: "arrow.uturn.backward").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(AppPalette.sage)
                        }.buttonStyle(.plain).keyboardShortcut(",", modifiers: [])
                    }
                    CardPanel(card: card)
                    HStack(spacing: 8) {
                        SaveCardButton(card: card); ShareCardButton(card: card)
                        Button { focusCard = card } label: {
                            Label("Focus", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 13, weight: .semibold, design: .rounded)).frame(maxWidth: .infinity, minHeight: 42)
                        }.buttonStyle(.bordered).tint(AppPalette.sage).accessibilityLabel("Focus card")
                    }
                } else if !deckCards.isEmpty {
                    EmptyState(title: "Choose a card", message: "Tap “Draw from this deck” to draw a prompt.")
                } else {
                    EmptyState(title: "No cards in this collection", message: "Return to the collection list and choose another deck.")
                }
                Text("Draw one at a time. Skip freely, or return to all collections whenever you want.")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
            }.padding(.vertical, 16).frame(maxWidth: 620, alignment: .leading).frame(maxWidth: .infinity).padding(.horizontal, 16)
        }
        .background(AppBackdrop()).navigationTitle(deck.title).navigationBarTitleDisplayMode(.inline)
        .onAppear { if currentCardID == nil { drawFromDeck(recordPrevious: false) } }
        .fullScreenCover(item: $focusCard) { CardFocusScreen(card: $0) }
    }

    private func drawFromDeck(recordPrevious: Bool = true) {
        if recordPrevious, let currentCardID { previousIDs.append(currentCardID) }
        var choices = deckCards.filter { !seenIDs.contains($0.id) && $0.id != currentCardID }
        if choices.isEmpty {
            seenIDs.subtract(deckCards.map(\.id))
            choices = deckCards.filter { $0.id != currentCardID }
        }
        guard let card = choices.randomElement() else {
            if let card = deckCards.first { currentCardID = card.id }
            return
        }
        currentCardID = card.id
        seenIDs.insert(card.id)
    }
    private func showPrevious() {
        guard let previous = previousIDs.popLast() else { return }
        currentCardID = previous
    }
}

struct PrivateCardNoteEditor: View {
    let cardID: String
    @State private var note: String

    init(cardID: String) {
        self.cardID = cardID
        _note = State(initialValue: UserDefaults.standard.string(forKey: "careNote.\(cardID)") ?? "")
    }

    private var hasNote: Bool { !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var body: some View {
        DisclosureGroup {
            TextEditor(text: $note)
                .frame(minHeight: 88)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppPalette.line, lineWidth: 1))
                .onChange(of: note) { value in
                    let limited = String(value.prefix(1200))
                    if limited != value { note = limited }
                    let key = "careNote.\(cardID)"
                    if limited.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        UserDefaults.standard.removeObject(forKey: key)
                    } else {
                        UserDefaults.standard.set(limited, forKey: key)
                    }
                }
            Text("Stored locally on this device.")
                .font(.system(size: 11, design: .rounded)).foregroundStyle(AppPalette.muted)
        } label: {
            Text(hasNote ? "Edit private note" : "Add a private note")
                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(AppPalette.sage)
        }
        .tint(AppPalette.sage)
        .font(.system(size: 12, design: .rounded))
        .padding(.top, 3)
    }
}

struct SavedScreen: View {
    @EnvironmentObject private var store: DeckStore
    @State private var searchText = ""

    private var savedCards: [CardItem] {
        let cards = store.allCards.filter { store.savedIDs.contains($0.id) }
        let jungItems = store.jungEntries.filter { store.savedIDs.contains($0.id) }.map { CardItem(jung: $0) }
        let all = cards + jungItems
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.prompt.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            ($0.sourceCredit?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(AppPalette.muted)
                TextField("Search saved cards", text: $searchText).textInputAutocapitalization(.never).autocorrectionDisabled().foregroundStyle(AppPalette.ink)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(AppPalette.muted) }
                        .accessibilityLabel("Clear search")
                }
            }.padding(12).background(AppPalette.card, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16).padding(.top, 12)

            if savedCards.isEmpty {
                EmptyState(
                    title: store.savedIDs.isEmpty ? "Nothing saved yet" : "No matching saved items",
                    message: store.savedIDs.isEmpty
                        ? "Save a card or Jung reflection to keep it close. Your saved items stay on this device."
                        : "Try another title, prompt, category, or source."
                ).padding(20).frame(maxHeight: .infinity, alignment: .top)
            } else {
                List(savedCards) { card in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            NavigationLink { CardDetailScreen(card: card) } label: { CardRow(card: card) }
                                .buttonStyle(.plain)
                            Button {
                                store.toggleSaved(card)
                            } label: {
                                Image(systemName: "bookmark.slash").foregroundStyle(AppPalette.muted)
                                    .frame(width: 38, height: 38)
                            }.buttonStyle(.plain).accessibilityLabel("Remove from saved items")
                        }
                        PrivateCardNoteEditor(cardID: card.id)
                    }
                    .listRowBackground(AppPalette.card)
                }.scrollContentBackground(.hidden)
            }
        }.background(AppBackdrop()).navigationTitle("Saved cards")
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
                PrivateCardNoteEditor(cardID: card.id)
                    .padding(14)
                    .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(16)
        }
        .background(AppBackdrop())
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
    @AppStorage("careTextScale") private var careTextScale = 1.0

    private var scale: CGFloat { CGFloat(min(1.4, max(0.8, careTextScale))) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(card.category.localizedCapitalized).font(.system(size: 12, weight: .bold, design: .rounded)).tracking(1.1).foregroundStyle(AppPalette.sage)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true).layoutPriority(1)
                Spacer(minLength: 4)
                Text(card.id.hasPrefix("source:") ? "SOURCE" : card.id).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(AppPalette.muted).fixedSize()
            }
            Text(card.title).font(.custom(BundledFonts.body, size: 25 * scale, relativeTo: .title).weight(.semibold)).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
            Text(card.prompt).font(.custom(BundledFonts.body, size: 18 * scale, relativeTo: .body).weight(.regular)).lineSpacing(5).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)

            if !card.reflection.isEmpty {
                DisclosureGroup {
                    Text(card.reflection).font(.custom(BundledFonts.body, size: 16 * scale, relativeTo: .body).weight(.regular)).italic().lineSpacing(3)
                        .foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true).padding(.top, 6)
                } label: {
                    Text("OPTIONAL REFLECTION").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(AppPalette.sage)
                }
                .tint(AppPalette.sage).padding(.top, 12)
                .overlay(alignment: .top) { AppPalette.line.frame(height: 1) }
            }
            if !card.small.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("SMALLER VERSION").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(AppPalette.sageDark)
                    Text(card.small).font(.custom(BundledFonts.body, size: 15 * scale, relativeTo: .body).weight(.medium)).lineSpacing(3).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
                }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(AppPalette.mist, in: RoundedRectangle(cornerRadius: 16))
            }
            if let sourceCredit = card.sourceCredit {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Adapted from \(sourceCredit)").font(.system(size: 12, design: .rounded)).foregroundStyle(AppPalette.muted)
                    if let sourceURL = card.sourceURL, let url = URL(string: sourceURL) {
                        Link("View the original source", destination: url).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(AppPalette.sageDark)
                    }
                }.padding(.top, 2)
            }
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
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

struct QuoteShareButton: View {
    let quote: JungEntry
    @State private var showingShare = false
    @State private var activityItems: [Any] = []
    var body: some View {
        Button(action: prepareShare) {
            Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered).tint(AppPalette.sage)
        .sheet(isPresented: $showingShare) {
            ActivityView(activityItems: activityItems).presentationDetents([.medium, .large])
        }
    }
    private func prepareShare() {
        let renderer = ImageRenderer(content: QuoteShareArtwork(quote: quote))
        renderer.scale = 3
        activityItems = [quote.shareText]
        if let image = renderer.uiImage { activityItems.insert(image, at: 0) }
        showingShare = true
    }
}
struct QuoteShareArtwork: View {
    let quote: JungEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("SHROOK · JUNG // SIGNAL").font(.custom(BundledFonts.display, size: 13)).tracking(1.5).foregroundStyle(AppPalette.sage)
            Text(quote.kindLabel).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(AppPalette.sage)
            Text("“").font(.system(size: 46, weight: .medium, design: .serif)).foregroundStyle(AppPalette.sage)
            Text(quote.text).font(.system(size: 21, weight: .medium, design: .rounded)).lineSpacing(4).foregroundStyle(AppPalette.ink).fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(AppPalette.line).frame(height: 1)
            Text(quote.citation).font(.system(size: 11, design: .rounded)).foregroundStyle(AppPalette.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(28).frame(width: 360, alignment: .leading).background(AppPalette.paper)
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
            Text("SHROOK · CARE CARDS")
                .font(.custom(BundledFonts.display, size: 14))
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
            .foregroundStyle(AppPalette.paper)
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
                AboutCard(title: "Reading size") {
                    ReadingSizeControls()
                }
                AboutCard(title: "Keyboard controls") {
                    Text("On a hardware keyboard, press period to draw another card, comma to return to the previous card, or Escape to close Focus card. These shortcuts are also available in source collections.")
                }
                AboutCard(title: "Use this gently") {
                    Text("Choose an action, try the smaller version, or skip it. There is no required order, streak, score, or productivity target.")
                    Text("Sensory needs and stims are useful information. Masking can be protective; this app never asks you to unmask or explore anything that does not feel safe.")
                }
                AboutCard(title: "Jungian ideas, used gently") {
                    Text("Individuation can mean noticing what fits your own life. Persona can describe roles that help us navigate. Shadow is used here for overlooked feelings or strengths, not as a label for something bad.")
                    Text("These are reflective prompts, not a fixed interpretation, diagnosis, or substitute for clinical care. You do not need to disclose or dig into painful memories.")
                }
                AboutCard(title: "About the Jung quotes") {
                    Text("Jung // signal combines six sourced quotations with 20 original Jungian-inspired paraphrases. Each entry is labeled, and sourced quotations link to their references.")
                }
                AboutCard(title: "Credit and privacy") {
                    Text("Optional reference prompts are adapted with permission from tools by Alora Young / NeuroScouts. Each collection links back to its source. The Care Quest PDF cover also credits SEHTLO WEBS MD.")
                    if let url = URL(string: "https://alorayoung.org/free-tools.html#decks") {
                        Link("Visit the original free-tools page", destination: url)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .tint(AppPalette.sage)
                    }
                    Text("Your saved cards, Jung reflections, private notes, voice choice, and reading speed stay on this device. The app works offline with its bundled cards and collections, uses no account, and does not send your saved items anywhere.")
                }
            }
            .padding(20)
        }
        .background(AppBackdrop())
        .navigationTitle("About")
    }
}

struct ReadingSizeControls: View {
    @AppStorage("careTextScale") private var scale = 1.0
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adjust card text to a comfortable size. Your choice stays on this device.")
            HStack(spacing: 10) {
                Button { scale = max(0.8, scale - 0.1) } label: { Text("A−").frame(maxWidth: .infinity, minHeight: 42) }
                    .buttonStyle(.bordered).tint(AppPalette.sage).accessibilityLabel("Decrease card text size")
                Text("\(Int((scale * 100).rounded()))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(AppPalette.ink).frame(minWidth: 48)
                    .accessibilityLabel("Card text size \(Int((scale * 100).rounded())) percent")
                Button { scale = min(1.4, scale + 0.1) } label: { Text("A+").frame(maxWidth: .infinity, minHeight: 42) }
                    .buttonStyle(.bordered).tint(AppPalette.sage).accessibilityLabel("Increase card text size")
                Button("Reset") { scale = 1.0 }.font(.system(size: 13, weight: .medium, design: .rounded)).tint(AppPalette.sage)
            }
        }
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
