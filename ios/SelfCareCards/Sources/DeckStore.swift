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

struct JungEntry: Codable, Hashable, Identifiable {
    let id: String
    let kind: String
    let text: String
    let citation: String
    let url: String
    let label: String?
    var kindLabel: String { kind == "quote" ? "VERIFIED QUOTE" : "JUNGIAN-INSPIRED PARAPHRASE" }
    var shareText: String { "\(kindLabel)\n\n“\(text)”\n\n\(citation)\n\(url)\n\nSHROOK · Jung // signal" }
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
        title = Self.clean(core.title)
        prompt = Self.clean(core.prompt)
        reflection = Self.clean(core.reflection)
        small = Self.clean(core.small)
        sourceCredit = nil
        sourceURL = nil
    }

    init(source card: SourcePrompt, deck: SourceDeck, index: Int) {
        id = "source:\(deck.id):\(index + 1)"
        category = deck.area
        title = Self.clean(card.title)
        prompt = Self.clean(card.prompt)
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
    
    private static func clean(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
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
    static let paper = Color(red: 0.0667, green: 0.0706, blue: 0.0627) // #111210
    static let card = Color(red: 0.0980, green: 0.1020, blue: 0.0902) // #191A17
    static let sage = Color(red: 0.8745, green: 1.0000, blue: 0.2627) // #DFFF43
    static let sageDark = Color(red: 0.7686, green: 0.8980, blue: 0.1765) // #C4E52D
    static let mist = Color(red: 0.1255, green: 0.1294, blue: 0.1176) // #20211E
    static let ink = Color(red: 0.9255, green: 0.9333, blue: 0.8980) // #ECEEE5
    static let muted = Color(red: 0.6549, green: 0.6667, blue: 0.6078) // #A7AA9B
    static let line = Color(red: 0.2157, green: 0.2235, blue: 0.1961) // #373932
}

private struct ContentCountMismatch: Error, CustomStringConvertible {
    let file: String
    let expected: Int
    let actual: Int
    var description: String { "\(file) contains \(actual) entries; expected \(expected)." }
}

@MainActor
final class DeckStore: ObservableObject {
    @Published private(set) var coreCards: [CardItem] = []
    @Published private(set) var sourceDecks: [SourceDeck] = []
    @Published private(set) var jungQuotes: [JungEntry] = []
    @Published private(set) var jungReflections: [JungEntry] = []
    @Published var savedIDs: Set<String>
    @Published private(set) var loadError: String?
    @Published private(set) var sourceDecksLoadError: String?
    @Published private(set) var jungQuotesLoadError: String?
    @Published private(set) var jungReflectionsLoadError: String?

    init() {
        savedIDs = Set(UserDefaults.standard.stringArray(forKey: "savedCardIDs") ?? [])
        do {
            let core: [CoreCard] = try Self.load("cards")
            guard core.count == 100 else { throw ContentCountMismatch(file: "cards.json", expected: 100, actual: core.count) }
            coreCards = core.map { CardItem(core: $0) }
        } catch {
            NSLog("Self-Care Cards: could not load card collection: %@", String(describing: error))
            loadError = "The card data is missing or damaged in this app build. Install the latest build to restore the collection."
        }
        do {
            let decks: [SourceDeck] = try Self.load("source-decks")
            guard decks.count == 9 else { throw ContentCountMismatch(file: "source-decks.json", expected: 9, actual: decks.count) }
            sourceDecks = decks
        } catch {
            NSLog("Self-Care Cards: could not load source decks: %@", String(describing: error))
            sourceDecksLoadError = "The source decks are missing or damaged in this app build. Install the latest build to restore them."
        }
        do {
            let quotes: [JungEntry] = try Self.load("jung-quotes")
            guard quotes.count == 6 else { throw ContentCountMismatch(file: "jung-quotes.json", expected: 6, actual: quotes.count) }
            jungQuotes = quotes
        } catch {
            NSLog("Self-Care Cards: could not load Jung quotes: %@", String(describing: error))
            jungQuotesLoadError = "The quote collection is missing or damaged in this app build. Install the latest build to restore it."
        }
        do {
            let reflections: [JungEntry] = try Self.load("jung-reflections")
            guard reflections.count == 20 else { throw ContentCountMismatch(file: "jung-reflections.json", expected: 20, actual: reflections.count) }
            jungReflections = reflections
        } catch {
            NSLog("Self-Care Cards: could not load Jungian-inspired reflections: %@", String(describing: error))
            jungReflectionsLoadError = "The reflection collection is missing or damaged in this app build. Install the latest build to restore it."
        }
    }

    var allCards: [CardItem] {
        coreCards + sourceDecks.flatMap { cards(for: $0) }
    }

    var jungEntries: [JungEntry] {
        jungQuotes + jungReflections
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
