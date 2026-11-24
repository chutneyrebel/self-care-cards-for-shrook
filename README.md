# Self-Care Cards

A personal, neurodivergent-first card app with 100 original cards, nine optional reference collections, and a source-cited Jung quote generator. The PWA is designed for iPhone Home Screen use, offline reading after the first visit, random draws, saved cards, and sharing.

## Decks

The main **Draw** view uses Shrook's 100 cards across five areas: sensory grounding, low-energy care, gentle music and movement, thoughts and big feelings, and social recovery and self-acceptance. Each card has an optional Jungian reflection and a smaller version.

The **Explore** view brings the five care areas and nine optional reference collections together. Selected prompts are adapted with permission from tools by Alora Young / NeuroScouts. Each collection links to its original source.

Collections: Dopamine Farming, NeuroScouts Quests, Real Life NeuroScouts, Autistic Liberation Skill Cards, Playful Thinking Problem Solver, Care Quest, Frame Shifter, Design Thinking Solutions, and Divergent Thinking.

## Run locally

Serve the repository root over HTTPS or localhost. Opening `index.html` as a `file://` URL will not allow the PWA service worker to install.

## iOS app build

The repository also contains a native SwiftUI iOS app. GitHub Actions builds a device-architecture `.ipa` when app or card data changes, and the artifact is available from the **Build Self-Care Cards IPA** workflow run. The first workflow produces an unsigned IPA; installing it on an iPhone requires Apple signing and provisioning.

The iOS app works offline, keeps saved cards on the device, offers random draws from the 100-card deck, combines all five care areas and nine reference collections in Explore, and includes the same six-quote generator. Card and quote sharing uses the iOS share sheet. The Xcode project is generated from `project.yml` with XcodeGen during the workflow.

To run a signed build from Xcode, generate the project with XcodeGen, open `SelfCareCards.xcodeproj`, select an Apple development team in Signing & Capabilities, then build for a connected device.

## Privacy

Saved cards use this browser's local storage. The app has no account, analytics, or network-backed user data. Selected reference prompts are included with permission and linked to Alora Young / NeuroScouts' [free-tools page](https://alorayoung.org/free-tools.html#decks). The shared `jung-quotes.json` file powers the PWA quote view and is bundled into the iOS app; neither version sends saved cards or quote activity to a server.

## Credit

Reference tools and original concepts: **Alora Young / NeuroScouts**. Care Quest's PDF cover also credits **SEHTLO WEBS MD**. See [Alora Young's free-tools page](https://alorayoung.org/free-tools.html#decks) for the original resource library.

The quote generator uses one shared, local data file. The PWA fetches and caches it for offline use; the iOS build bundles the same file in the app. Updating its contents requires publishing the PWA and producing a new iOS build.
