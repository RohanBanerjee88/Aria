# Aria - Augmented Vision Assistant 👁️

> AI-powered accessibility app for blind and visually impaired users. Navigate environments, read text, and get directions—all hands-free.

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)

**Built at Hack Harvard 2025** 🏆

---

## ✨ What It Does

Aria transforms your iPhone camera into an intelligent assistant with three gesture-controlled modes:

- **✋ Environment Mode** - Detects obstacles, describes surroundings, guides safe paths
- **✌️ Communication Mode** - Reads text from signs, menus, labels, documents
- **🗺️ Navigation Mode** - Turn-by-turn walking directions with voice guidance

All controlled hands-free with simple gestures. Show a **fist** (✊) to stop.

---

## 🛠️ Tech Stack

- **Gemini 2.0 Flash** - Scene understanding & OCR
- **ElevenLabs** - Natural text-to-speech
- **Google Maps API** - Turn-by-turn navigation
- **iOS Vision** - Hand gesture recognition
- **Swift/SwiftUI** - Native iOS app

---

## 🚀 Quick Start

1. **Clone the repo**
```bash
git clone https://github.com/yourusername/aria.git
```

2. **Get API keys** from:
   - [Google AI Studio](https://aistudio.google.com/app/apikey) (Gemini)
   - [ElevenLabs](https://elevenlabs.io/) (TTS)
   - [Google Cloud Console](https://console.cloud.google.com/) (Maps - enable Directions API)

3. **Add keys to `Utilities/Constants.swift`**:
```swift
static let geminiAPIKey = "YOUR_KEY"
static let elevenLabsAPIKey = "YOUR_KEY"
static let googleMapsAPIKey = "YOUR_KEY"
```

4. **Run on iPhone** (requires physical device for camera/GPS)

---

## 📱 Usage

**Environment Mode:** Show open palm ✋ → Move camera around → Hear obstacle descriptions

**Reading Mode:** Show peace sign ✌️ → Point at text → Hear it read aloud

**Navigation:** Tap Navigate button → Enter destination → Follow voice directions

**Stop anytime:** Show fist ✊
