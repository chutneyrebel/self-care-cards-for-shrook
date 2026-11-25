# Self-Care Cards

A personal, neurodivergent-first card app with 100 original cards, nine optional reference collections, and the PWA’s “Jung // signal” feature: six sourced quotations plus 20 original Jungian-inspired paraphrases. The iOS app mirrors the PWA’s charcoal, acid-lime, subtle grid design and works offline with bundled content.

## Decks

The main **Draw** view uses Shrook's 100 cards across five areas: sensory grounding, low-energy care, gentle music and movement, thoughts and big feelings, and social recovery and self-acceptance. Each card has an optional Jungian reflection and a smaller version.

The **Explore** view opens nine optional reference collections. It draws one prompt at a time, links to the original source, and keeps the collection picker out of the card flow. Selected prompts are adapted with permission from tools by Alora Young / NeuroScouts.

Collections: Dopamine Farming, NeuroScouts Quests, Real Life NeuroScouts, Autistic Liberation Skill Cards, Playful Thinking Problem Solver, Care Quest, Frame Shifter, Design Thinking Solutions, and Divergent Thinking.

## Run locally

Serve the repository root over HTTPS or localhost. Opening `index.html` as a `file://` URL will not allow the PWA service worker to install.

## iOS app build

The repository also contains a native SwiftUI iOS app. GitHub Actions builds a device-architecture `.ipa` when app or card data changes, and the artifact is available from the **Build Self-Care Cards IPA** workflow run. The first workflow produces an unsigned IPA; installing it on an iPhone requires Apple signing and provisioning.

The iOS app bundles its cards, nine source collections, six verified quotations, and 20 original paraphrases for offline use. Draw filters cover the same five care areas as the PWA. Explore draws one source card at a time; Save stays on the device; card and Jung-entry sharing uses the iOS share sheet. The Xcode project is generated from `project.yml` with XcodeGen during the workflow.

To run a signed build from Xcode, generate the project with XcodeGen, open `SelfCareCards.xcodeproj`, select an Apple development team in Signing & Capabilities, then build for a connected device.

## Privacy

Saved cards use this browser's local storage. The app has no account, analytics, or network-backed user data. Selected reference prompts are included with permission and linked to Alora Young / NeuroScouts' [free-tools page](https://alorayoung.org/free-tools.html#decks). The iOS app bundles its Jung entries alongside the other content; neither version sends saved cards or quote activity to a server.

## Credit

Reference tools and original concepts: **Alora Young / NeuroScouts**. Care Quest's PDF cover also credits **SEHTLO WEBS MD**. See [Alora Young's free-tools page](https://alorayoung.org/free-tools.html#decks) for the original resource library.

The PWA and native app keep content local and available offline. The iOS build validates the expected content counts before packaging: 100 core cards, nine source collections, six sourced quotations, and 20 original Jungian-inspired reflections.
