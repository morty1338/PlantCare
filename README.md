# PlantCare 🌱

**An AI plant assistant for iOS: take a photo of a plant and get its species, health score and
personalized care recommendations.**

PlantCare is a native SwiftUI app. Recognition runs on Anthropic's Claude vision model; the photo
cut-out, history and settings stay on the device.

## Features

- **Recognition from a photo or a name** — species, soil condition and a 1–10 health score.
- **Care recommendations** — situation-specific advice plus general care tips with concrete
  numbers (watering, light, window direction), the plant's wild habitat and the right soil type.
- **Two modes** — *Home plants* saves every reading to a personal garden; *One-time* saves nothing.
- **My garden** — each plant is a pot with its own history, so you can track its health over time;
  pots can be renamed and rearranged by drag and drop.
- **Plant cut-out** — Apple's Vision framework lifts the plant out of the photo and places it into
  a drawn pot, on the device.
- **Follow-up chat** — when the model is unsure it asks a clarifying question; you can answer or
  send another photo.
- **Placement advice** — save photos of rooms in your home and get a suggestion where the plant
  will feel best.
- **English and Ukrainian** — switchable in the app, the model answers in the selected language.

## Tech stack

| Area | Technologies |
| --- | --- |
| Language | Swift 5 |
| UI | SwiftUI, MVVM |
| AI | Anthropic Messages API (Claude vision), strict JSON responses |
| On-device vision | Vision (`VNGenerateForegroundInstanceMaskRequest`), Core Image |
| Persistence | Codable JSON in the Documents directory |
| Networking | URLSession with timeouts and typed, user-friendly errors |

## Architecture

```
Config/                 Shared.xcconfig, Secrets(.example).xcconfig, Info.plist
PlantCare/
  PlantCareApp.swift    entry point
  Config.swift          model name, limits, API key read from Info.plist
  Models/               PlantAnalysis (API response), PlantRecord, ChatMessage, AppMode
  Services/             AnthropicService, HistoryStore, RoomStore, Segmentation, LanguageManager
  ViewModels/           AppViewModel (capture → loading → result), ChatViewModel
  Views/                capture flow, results, garden, plant detail, rooms, chat
  Components/           pots, leaf art, image pickers, cards
  Design/Theme.swift    colors and styles
```

Design decisions:

- **Prompting for structured output** — the system prompt forces a JSON-only answer; decoding is
  tolerant, so a partially filled reply never crashes the UI.
- **No secrets in code** — the API key lives in the git-ignored `Config/Secrets.xcconfig`, goes into
  Info.plist at build time and is read from the bundle.
- **Local-first** — history and room photos are stored on the device only.

## Getting started

Requirements: Xcode 26, iOS 16+ (the plant cut-out needs iOS 17+).

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
# fill in ANTHROPIC_API_KEY and DEVELOPMENT_TEAM
open PlantCare.xcodeproj
```

## Author

**Ivan Movchan** — [LinkedIn](https://www.linkedin.com/in/ivan-movchan-088854427) ·
[GitHub](https://github.com/morty1338)
