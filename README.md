# Self-Care Cards

A personal, neurodivergent-first card app with 100 original cards and nine optional source collections. It is a static PWA designed for iPhone Home Screen use, offline reading after the first visit, random draws, saved cards, and shareable card images.

## Decks

The main **Draw** view uses Shrook's 100 cards across five areas: sensory grounding, low-energy care, gentle music and movement, thoughts and big feelings, and social recovery and self-acceptance. Each card has an optional Jungian reflection and a smaller version.

The **Explore** view keeps Alora Young / NeuroScouts' collections separate and optional. Source-card wording is adapted where needed for clarity, location context, and user choice. Each source card identifies its source deck and links to its original PDF; shared images include credit.

Collections: Dopamine Farming, NeuroScouts Quests, Real Life NeuroScouts, Autistic Liberation Skill Cards, Playful Thinking Problem Solver, Care Quest, Frame Shifter, Design Thinking Solutions, and Divergent Thinking.

## Run locally

Serve the repository root over HTTPS or localhost. Opening `index.html` as a `file://` URL will not allow the PWA service worker to install.

## iOS app build

The repository also contains a native SwiftUI iOS app. GitHub Actions builds a device-architecture `.ipa` when app or card data changes, and the artifact is available from the **Build Self-Care Cards IPA** workflow run. The first workflow produces an unsigned IPA; installing it on an iPhone requires Apple signing and provisioning.

The iOS app works offline, keeps saved cards on the device, offers random draws from the 100-card deck, browses all five areas and nine credited source decks, and can share a card image through the iOS share sheet. The Xcode project is generated from `project.yml` with XcodeGen during the workflow.

To run a signed build from Xcode, generate the project with XcodeGen, open `SelfCareCards.xcodeproj`, select an Apple development team in Signing & Capabilities, then build for a connected device.

## Privacy

Saved cards use this browser's local storage. The app has no account, analytics, or network-backed user data. Source PDFs are linked from Alora Young's official free-tools page; the app includes the selected prompt content and attribution for Shrook's personal use.

## Credit

Source decks and original concepts: **Alora Young / NeuroScouts**. Care Quest's PDF cover also credits **SEHTLO WEBS MD**. See [Alora Young's free-tools page](https://alorayoung.org/free-tools.html#decks) for the original deck library.
