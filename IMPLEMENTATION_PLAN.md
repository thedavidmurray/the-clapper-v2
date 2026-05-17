# The Clapper v2 — Implementation Plan

**Status:** Planning Phase  
**Platform:** iOS 17.0+  
**Language:** Swift / SwiftUI  
**Audio Framework:** AVFoundation + Accelerate (FFT)  
**Monetization:** StoreKit 2 (Freemium)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        THE CLAPPER v2                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  AudioEngine │  │GestureMatcher│  │ProfileManager│          │
│  │   (Core)     │  │  (Core ML)   │  │  (Core)      │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                  │
│         └─────────────────┼─────────────────┘                  │
│                           ▼                                    │
│                  ┌─────────────────┐                           │
│                  │  App Intents    │                           │
│                  │  (Shortcuts)    │                           │
│                  └────────┬────────┘                           │
│                           │                                    │
│  ┌────────────────────────┼────────────────────────┐          │
│  │  Free Tier (3 gestures, camera only)              │          │
│  │  Premium (custom gestures, Shortcuts, profiles)│          │
│  │  ── StoreKit 2 Paywall ──                        │          │
│  └──────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Feature Breakdown

### 1. AudioEngine (Core)

**Purpose:** Real-time audio analysis to detect claps, snaps, and patterns.

**Components:**
- `AudioCapture` — AVAudioEngine microphone input with buffer management
- `FFTProcessor` — Real-time frequency analysis using Accelerate vDSP
- `PeakDetector` — Transient detection (claps = sharp peaks)
- `RhythmAnalyzer` — Pattern recognition from peak timing

**Key Algorithm:**
```swift
// Clap detection = high amplitude spike in 2-5kHz range
// Snap detection = high amplitude spike in 5-8kHz range
// Double-clap = two peaks within 0.5s window
// Pattern matching = DTW against stored templates
```

---

### 2. GestureMatcher (Core ML / Algorithm)

**Purpose:** Match detected audio patterns against known gestures.

**Components:**
- `TemplateStore` — JSON/MLModel storage of gesture templates
- `DTWEngine` — Dynamic Time Warping for pattern comparison
- `ConfidenceScorer` — Probability scoring (0.0-1.0)

**Training Flow:**
```
User performs gesture 3x → Capture audio fingerprints → 
Average templates → Store with metadata → Confirm matching
```

---

### 3. ProfileManager (Core)

**Purpose:** Context-based gesture sets that auto-switch.

**Components:**
- `Profile` — struct: name, gestures[], activation trigger
- `LocationTrigger` — CoreLocation-based profile switching
- `TimeTrigger` — Time-of-day-based profile switching
- `ManualTrigger` — User-selected profile

**Profiles:**
- **Home** — Clap-clap = lights, Snap = music pause
- **Office** — Clap = mute/unmute, Snap = presentation advance
- **Gym** — Double clap = start timer, Triple clap = stop
- **Studio** — Custom patterns for creative workflows

---

### 4. App Intents / Shortcuts Integration

**Purpose:** Expose gestures as Shortcuts automation triggers.

**Implementation:**
- `ClapperIntent` — AppIntent protocol conformance
- `GestureTrigger` — Entity for triggerable gestures
- `ShortcutsProvider` — AppShortcutsProvider implementation

**Shortcuts Available:**
```
When [gesture] detected → Run [shortcut]

Gestures:
- "Double clap detected"
- "Single snap detected"
- "Triple clap detected"
- "Clap-snap-clap detected" (custom)
- "Custom pattern [name] detected"
```

---

### 5. Freemium / StoreKit 2

**Purpose:** Monetize advanced features while keeping core free.

**Tiers:**

| Feature | Free | Premium |
|---------|------|---------|
| Built-in gestures | 3 | Unlimited |
| Custom gestures | ❌ | ✅ |
| Shortcuts integration | ❌ | ✅ |
| Multiple profiles | 1 | Unlimited |
| Advanced sensitivity | ❌ | ✅ |
| Ad removal | ❌ | ✅ |

**Pricing Options:**
1. $3.99 one-time purchase (recommended)
2. $0.99/month subscription (alternative)
3. $9.99/year subscription (best value)

**StoreKit 2 Products:**
- `theclapper.premium.onetime` — Non-consumable
- `theclapper.premium.monthly` — Auto-renewable subscription
- `theclapper.premium.yearly` — Auto-renewable subscription

---

## Project Structure

```
TheClapper/
├── TheClapper.xcodeproj/
├── TheClapper/
│   ├── App/
│   │   ├── TheClapperApp.swift
│   │   └── Info.plist
│   ├── Core/
│   │   ├── Audio/
│   │   │   ├── AudioCapture.swift
│   │   │   ├── FFTProcessor.swift
│   │   │   └── PeakDetector.swift
│   │   ├── Gesture/
│   │   │   ├── GestureMatcher.swift
│   │   │   ├── TemplateStore.swift
│   │   │   └── DTWEngine.swift
│   │   └── Profile/
│   │       ├── ProfileManager.swift
│   │       ├── Profile.swift
│   │       └── Triggers/
│   │           ├── LocationTrigger.swift
│   │           └── TimeTrigger.swift
│   ├── Intents/
│   │   ├── ClapperIntent.swift
│   │   ├── GestureTriggerEntity.swift
│   │   └── ShortcutsProvider.swift
│   ├── UI/
│   │   ├── Views/
│   │   │   ├── ContentView.swift
│   │   │   ├── GestureTrainingView.swift
│   │   │   ├── ProfileEditorView.swift
│   │   │   └── SettingsView.swift
│   │   └── Components/
│   │       ├── AudioVisualizer.swift
│   │       ├── GestureButton.swift
│   │       └── ProfileCard.swift
│   ├── Store/
│   │   ├── StoreManager.swift
│   │   ├── PremiumStore.swift
│   │   └── PaywallView.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       └── Preview Content/
├── TheClapperIntents/
│   └── IntentHandler.swift
└── Tests/
    ├── AudioEngineTests/
    ├── GestureMatcherTests/
    └── StoreKitTests/
```

---

## Implementation Phases

### Phase 1: Foundation (v1 Core)
**Duration:** 3-4 days  
**Deliverable:** Working clap/snap detection, camera trigger

| Task | Files | Complexity |
|------|-------|------------|
| Audio capture + FFT | AudioCapture.swift, FFTProcessor.swift | Medium |
| Peak detection | PeakDetector.swift | Low |
| Basic gesture matching | GestureMatcher.swift | Medium |
| Camera trigger | CameraManager.swift | Low |
| Basic UI | ContentView.swift | Low |

### Phase 2: App Intents / Shortcuts
**Duration:** 2-3 days  
**Deliverable:** Gestures trigger Shortcuts automations

| Task | Files | Complexity |
|------|-------|------------|
| AppIntents framework setup | ClapperIntent.swift | Medium |
| Gesture entities | GestureTriggerEntity.swift | Low |
| Shortcuts provider | ShortcutsProvider.swift | Medium |
| Background audio | BackgroundAudioManager.swift | High |

### Phase 3: Custom Gestures
**Duration:** 2-3 days  
**Deliverable:** User can train custom patterns

| Task | Files | Complexity |
|------|-------|------------|
| Training UI | GestureTrainingView.swift | Medium |
| Template storage | TemplateStore.swift | Low |
| DTW algorithm | DTWEngine.swift | Medium |
| Pattern validation | PatternValidator.swift | Low |

### Phase 4: Profiles
**Duration:** 2 days  
**Deliverable:** Multiple context-based profiles

| Task | Files | Complexity |
|------|-------|------------|
| Profile model | Profile.swift | Low |
| Profile manager | ProfileManager.swift | Medium |
| Location triggers | LocationTrigger.swift | Low |
| Time triggers | TimeTrigger.swift | Low |
| Profile UI | ProfileEditorView.swift | Medium |

### Phase 5: Freemium / StoreKit
**Duration:** 2-3 days  
**Deliverable:** Paywall, purchases, restore

| Task | Files | Complexity |
|------|-------|------------|
| StoreKit 2 setup | StoreManager.swift | Medium |
| Product definitions | PremiumStore.swift | Low |
| Paywall UI | PaywallView.swift | Medium |
| Receipt validation | ReceiptValidator.swift | Medium |
| Feature gating | FeatureGating.swift | Low |

---

## Technical Specifications

### Audio Processing

**Sample Rate:** 16kHz (sufficient for clap/snap detection)  
**Buffer Size:** 1024 samples (~64ms)  
**FFT Size:** 2048 (zero-padded)  
**Frequency Range:** 2-8kHz (clap/snap dominant)

**Peak Detection Threshold:**
- Clap: > 2x ambient average in 2-5kHz
- Snap: > 2x ambient average in 5-8kHz
- Cooldown: 200ms (prevent double-triggering)

### DTW Parameters

**Window Size:** ±20% time variance  
**Distance Metric:** Euclidean on MFCC features  
**Match Threshold:** < 0.3 normalized distance  
**Template Count:** 3 samples → averaged template

### Background Execution

**Mode:** Audio background mode + App Intents  
**Battery Impact:** ~3-5% per hour (optimized FFT)  
**Privacy:** All processing on-device, no audio leaves device

---

## Acceptance Criteria Checklist

### App Intents
- [ ] 5+ gesture triggers exposed to Shortcuts
- [ ] Each trigger can be wired to any Shortcut
- [ ] Gestures work while app is backgrounded
- [ ] End-to-end test: gesture → HomeKit toggle

### Custom Gestures
- [ ] Training UI with 3-sample workflow
- [ ] DTW matching with >90% accuracy
- [ ] Gesture persistence across app restarts
- [ ] Delete/edit custom gestures

### Profiles
- [ ] 2+ switchable profiles
- [ ] Location-based auto-switching
- [ ] Time-based auto-switching
- [ ] Manual profile selector

### Freemium
- [ ] StoreKit 2 paywall implemented
- [ ] $3.99 one-time purchase option
- [ ] Restore purchases functionality
- [ ] Feature gating enforced
- [ ] No paywall bypass possible

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Background audio rejection | Medium | High | Use App Intents, minimal battery impact |
| Gesture false positives | Medium | Medium | Sensitivity calibration, confidence thresholds |
| StoreKit review issues | Low | High | Follow guidelines, clear paywall |
| DTW performance | Low | Medium | Optimize with vDSP, reduce template size |
| Shortcuts integration bugs | Medium | Medium | Extensive testing, fallback to in-app |

---

## Next Steps

1. **Xcode Project Setup** — Create SwiftUI project, configure entitlements
2. **Audio Engine** — Implement FFT-based peak detection
3. **Test v1 Core** — Verify clap/snap detection accuracy
4. **App Intents** — Add Shortcuts integration
5. **Custom Training** — Build gesture training UI
6. **Profiles** — Add context-based switching
7. **StoreKit** — Implement paywall and gating
8. **TestFlight** — Beta testing with real users
9. **App Store** — Submission preparation

---

**Total Estimated Duration:** 11-15 days  
**Priority Order:** Foundation → Shortcuts → Custom → Profiles → StoreKit
