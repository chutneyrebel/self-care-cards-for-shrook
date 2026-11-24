import Foundation
import SwiftUI

struct CoreCard: Codable, Hashable, Identifiable {
    let id: String
    let category: String
    let title: String
    let prompt: String
    let reflection: String
    let small: String
}

struct SourcePrompt: Codable, Hashable {
    let title: String
    let prompt: String
}

struct SourceDeck: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let author: String
    let source: String
    let area: String
    let description: String
    let cards: [SourcePrompt]
}

struct JungQuote: Codable, Hashable, Identifiable {
    let id: String
    let text: String
    let source: String

    var shareText: String {
        "“\(text)”\n\n\(source)\n\nSHROOK · Jung Quotes"
    }
}

struct CardItem: Hashable, Identifiable {
    let id: String
    let category: String
    let title: String
    let prompt: String
    let reflection: String
    let small: String
    let sourceCredit: String?
    let sourceURL: String?

    init(core: CoreCard) {
        id = core.id
        category = core.category
        title = core.title
        prompt = core.prompt
        reflection = core.reflection
        small = core.small
        sourceCredit = nil
        sourceURL = nil
    }

    init(source card: SourcePrompt, deck: SourceDeck, index: Int) {
        id = "source:\(deck.id):\(index + 1)"
        category = deck.area
        title = card.title
        prompt = card.prompt
        reflection = ""
        small = ""
        sourceCredit = "\(deck.title) by \(deck.author)"
        sourceURL = deck.source
    }

    var shareText: String {
        var parts = ["\(title)\n\n\(prompt)"]
        if !small.isEmpty { parts.append("Smaller version: \(small)") }
        if !reflection.isEmpty { parts.append("Optional reflection: \(reflection)") }
        if let sourceCredit {
            let link = sourceURL.map { "\n\($0)" } ?? ""
            parts.append("Adapted from \(sourceCredit)\(link)")
        }
        parts.append("SHROOK · Self-Care Cards · \(category) · \(id)")
        return parts.joined(separator: "\n\n")
    }
}

struct AreaInfo: Hashable, Identifiable {
    let name: String
    let description: String
    let symbol: String

    var id: String { name }

    static let all: [AreaInfo] = [
        AreaInfo(name: "SENSORY RESET", description: "Lower one input, find a steady point, or make a little more room.", symbol: "ear.and.waveform"),
        AreaInfo(name: "LOW-ENERGY CARE", description: "Start with the need that would make the next few minutes easier.", symbol: "cup.and.saucer"),
        AreaInfo(name: "MUSIC + MOVEMENT", description: "Explore sound or movement without turning it into a test.", symbol: "music.note"),
        AreaInfo(name: "THOUGHTS + BIG FEELINGS", description: "Make room around rumination, emotional overload, and the social sting.", symbol: "cloud"),
        AreaInfo(name: "SOCIAL RECOVERY + SELF-ACCEPTANCE", description: "Recover, set a limit, or stay connected in your own way.", symbol: "person.2")
    ]
}

enum AppPalette {
    static let paper = Color(red: 0.063, green: 0.067, blue: 0.055)
    static let card = Color(red: 0.098, green: 0.106, blue: 0.082)
    static let sage = Color(red: 0.890, green: 0.988, blue: 0.282)
    static let sageDark = Color(red: 0.784, green: 0.894, blue: 0.231)
    static let mist = Color(red: 0.133, green: 0.141, blue: 0.110)
    static let ink = Color(red: 0.949, green: 0.953, blue: 0.918)
    static let muted = Color(red: 0.678, green: 0.698, blue: 0.643)
    static let line = Color(red: 0.235, green: 0.251, blue: 0.200)
}

@MainActor
final class DeckStore: ObservableObject {
    @Published private(set) var coreCards: [CardItem] = []
    @Published private(set) var sourceDecks: [SourceDeck] = []
    @Published private(set) var jungQuotes: [JungQuote] = []
    @Published var savedIDs: Set<String>
    @Published private(set) var loadError: String?
    @Published private(set) var sourceDecksLoadError: String?
    @Published private(set) var jungQuotesLoadError: String?

    init() {
        savedIDs = Set(UserDefaults.standard.stringArray(forKey: "savedCardIDs") ?? [])
        do {
            let core: [CoreCard] = try Self.load("cards")
            coreCards = core.map { CardItem(core: $0) }
        } catch {
            NSLog("Self-Care Cards: could not load card collection: %@", String(describing: error))
            loadError = "The card data is missing or damaged in this app build. Install the latest build to restore the collection."
        }
        do {
            sourceDecks = try Self.load("source-decks")
        } catch {
            NSLog("Self-Care Cards: could not load source decks: %@", String(describing: error))
            sourceDecksLoadError = "The source decks are missing or damaged in this app build. Install the latest build to restore them."
        }
        do {
            jungQuotes = try Self.load("jung-quotes")
        } catch {
            NSLog("Self-Care Cards: could not load Jung quotes: %@", String(describing: error))
            jungQuotesLoadError = "The quote collection is missing or damaged in this app build. Install the latest build to restore it."
        }
    }

    var allCards: [CardItem] {
        coreCards + sourceDecks.flatMap { cards(for: $0) }
    }

    func cards(for deck: SourceDeck) -> [CardItem] {
        deck.cards.enumerated().map { index, card in
            CardItem(source: card, deck: deck, index: index)
        }
    }

    func isSaved(_ card: CardItem) -> Bool {
        savedIDs.contains(card.id)
    }

    func toggleSaved(_ card: CardItem) {
        if savedIDs.contains(card.id) {
            savedIDs.remove(card.id)
        } else {
            savedIDs.insert(card.id)
        }
        UserDefaults.standard.set(Array(savedIDs), forKey: "savedCardIDs")
    }

    private static func load<Value: Decodable>(_ name: String) throws -> Value {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }
}
