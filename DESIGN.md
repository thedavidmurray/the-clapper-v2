---
version: 1.0.0
name: TheClapper v2
description: A gesture-driven iOS app that detects claps and snaps via microphone, triggers configurable actions per profile, and supports custom gesture training with DTW pattern matching.
platform: iOS
target: iPhone / iPad
colors:
  primary: "#0051D5"
  secondary: "#6C7278"
  success: "#248A3D"
  danger: "#FF3B30"
  warning: "#FF9500"
  neutral: "#F2F2F7"
  on-primary: "#FFFFFF"
  on-success: "#FFFFFF"
typography:
  h1:
    fontFamily: SF Pro Display
    fontSize: 28px
    fontWeight: 700
    lineHeight: 1.2
  body:
    fontFamily: SF Pro Text
    fontSize: 17px
    fontWeight: 400
    lineHeight: 1.5
  caption:
    fontFamily: SF Pro Text
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.3
rounded:
  sm: 8px
  md: 12px
  lg: 16px
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
components:
  status-banner:
    backgroundColor: "{colors.success}"
    textColor: "{colors.on-success}"
    rounded: "{rounded.md}"
    padding: 16px
  gesture-card:
    backgroundColor: "{colors.neutral}"
    textColor: "#000000"
    rounded: "{rounded.md}"
    padding: 16px
  record-button:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.full}"
    size: 160px
---

# TheClapper v2 — Design Spec

## Overview

A gesture-driven iOS app that detects claps and snaps via microphone, triggers configurable actions per profile, and supports custom gesture training with DTW pattern matching.

The design philosophy centers on **immediate feedback** and **low-friction interaction**:
users should clap/snap once and see their configured action trigger instantly. The UI is intentionally minimal — a single record button, a status banner, and a scrollable gesture list — to keep focus on the audio-gesture loop rather than navigation.

## Voice & Tone

- **Direct:** Status messages say exactly what happened ("Matched: Double Clap").
- **Calm:** No alarming colors unless there's an error. Green = listening, red = recording/training.
- **Empowering:** Custom gesture training guides users through 3 samples with clear progress indicators.

## Colors

- **Primary (#007AFF):** Main action driver — record button, active training states, toolbar accents.
- **Success (#34C759):** Listening status banner, validation passed indicators, progress dots.
- **Danger (#FF3B30):** Recording state, permission denied alerts, validation failures.
- **Neutral (#F2F2F7):** Card backgrounds, gesture list rows, sheet backgrounds.
- **Secondary (#6C7278):** Metadata text (trigger counts, captions), inactive states.

## Typography

SF Pro family throughout. Display sizes use SF Pro Display; body and captions use SF Pro Text. No custom fonts — keeps app lightweight and native-feeling.

## Gesture Interaction Design

### Single Clap

```
User          App                    Audio Pipeline              Profile
 |             |                          |                         |
 User          |------------> 1 peak detected
 App           <------------| Type: clap
 |             |                          |                         |
```

**Triggers:**
- Trigger profile action

**Feedback:**
- Haptic success
- Status update

### Double Clap

```
User          App                    Audio Pipeline              Profile
 |             |                          |                         |
 User          |------------> 2 peaks
 App           <------------| ~0.3s apart
 Audio         |------------> Type: clap
 |             |                          |                         |
```

**Triggers:**
- Trigger profile action

**Feedback:**
- Haptic success
- Status update

### Triple Clap

```
User          App                    Audio Pipeline              Profile
 |             |                          |                         |
 User          |------------> 3 peaks
 App           <------------| ~0.3s apart
 Audio         |------------> Type: clap
 |             |                          |                         |
```

**Triggers:**
- Trigger profile action

**Feedback:**
- Haptic success
- Status update

### Single Snap

```
User          App                    Audio Pipeline              Profile
 |             |                          |                         |
 User          |------------> 1 peak detected
 App           <------------| Type: snap
 |             |                          |                         |
```

**Triggers:**
- Trigger profile action

**Feedback:**
- Haptic success
- Status update

### Double Snap

```
User          App                    Audio Pipeline              Profile
 |             |                          |                         |
 User          |------------> 2 peaks
 App           <------------| ~0.3s apart
 Audio         |------------> Type: snap
 |             |                          |                         |
```

**Triggers:**
- Trigger profile action

**Feedback:**
- Haptic success
- Status update

### Custom Gesture Training

```
User          App                    Audio Pipeline              Profile
 |             |                          |                         |
 User          |------------> User opens GestureTrainingView sheet
 App           <------------| Enter gesture name
 Audio         |------------> Record sample 1/3 (3-second capture)
 Profile       <------------| Record sample 2/3 (3-second capture)
 User          |------------> Record sample 3/3 (3-second capture)
 App           <------------| DTW validation: all 3 samples must match within distance < 0.2
 Audio         |------------> Save to TemplateStore (encrypted)
 Profile       <------------| Register App Intent binding
 |             |                          |                         |
```

**Triggers:**
- Custom gesture now available in profile actions

**Feedback:**
- Validation passed/failed message
- Saved confirmation

## Audio Pipeline

### Audio Pipeline Architecture

```
[Mic Input] --16kHz--> [AVAudioEngine] --1024-sample buffer--> [FFTProcessor]
                                                            |
                                                            v
[PeakDetector] <--magnitudes-- [Energy calc per bin] <-- [vDSP]
     |
     |-- Clap: 256-640 bins (2-5kHz), thresh > 0.6
     |-- Snap: 640-1024 bins (5-8kHz), thresh > 0.5
     |
     v
[GestureMatcher] --DTW distance--> [ProfileAction]
```

**Sample Rate:** 16000.0 Hz  
**Buffer Size:** 1024 samples  
**FFT Size:** 2048 bins  
**Thresholds:**
- Clap: 0.6
- Snap: 0.5


## Screen Architecture

### Screen Flow

```
+------------------+        +------------------+        +------------------+
|   ContentView    |<------>| GestureTraining  |<------>|   ProfileEditor  |
|   (Main Screen)  |  sheet |   (Train Custom) |  sheet |  (Edit Triggers) |
+--------+---------+        +------------------+        +------------------+
         |
         | sheet
         v
+--------+---------+        +------------------+
|    PaywallView   |<------>|   SettingsView   |
|  (Premium Gate)  |  sheet | (Permission Mgmt)  |
+------------------+        +------------------+
```

**ProfileEditorView** (`TheClapper/UI/Views/ProfileEditorView.swift`)
- State: selectedProfile, isAddingProfile, newProfileName, newProfileIcon, showingTriggerEditor
- Sheets: addProfileSheet, TriggerEditorView

**SettingsView** (`TheClapper/UI/Views/SettingsView.swift`)
- State: micPermissionStatus, locationPermissionStatus, notificationsEnabled

**GestureTrainingView** (`TheClapper/UI/Views/GestureTrainingView.swift`)
- State: gestureName, isRecording, sampleIndex, samples, validationMessage

**ContentView** (`TheClapper/UI/Views/ContentView.swift`)
- State: audioCapture, gestureMatcher, profileManager, storeManager, isRecording
- Sheets: GestureTrainingView, PaywallView, SettingsView


## Permissions UX

The app requires the following permissions, requested at first user action (not cold launch):

- Microphone (NSMicrophoneUsageDescription)
- Location (NSLocationWhenInUseUsageDescription)
- Notifications (UNUserNotificationCenter)

SettingsView provides a unified permission management interface where users can:
- View current permission status
- Request denied permissions
- Open system Settings for granular control

## Security & Privacy

- URL scheme whitelist (https, http, shortcuts)
- Encrypted profile storage (Library/Application Support + .completeFileProtection)
- Reverse-DNS notification namespacing
- Encrypted gesture template storage
- Runtime microphone permission guard

## Figma Annotation Notes

### For Designers:

1. **Gesture Cards** — Use the gesture-card component spec. Each row should show:
   - Left: SF Symbol icon (24pt, Blue)
   - Center: Gesture name (Headline) + trigger count (Caption, Secondary)
   - Right: 'CUSTOM' pill (if applicable, Purple, Caption2, Bold)

2. **Record Button** — 160×160pt circle. Use system Blue when idle, system Red when recording. Add shadow: color opacity 0.35, radius 16pt.

3. **Status Banner** — Full-width, 16pt padding, 14pt corner radius. Green tint when listening, red tint when recording. Include 10pt status dot (left) and active profile pill (right, 999pt radius, Gray6 bg).

4. **Training Flow** — 3-step horizontal progress (14pt circles). Active step = Blue, completed = Green, pending = Gray 30% opacity.

5. **Sheet Modals** — All secondary flows (training, paywall, settings, profile editor) use `.sheet` presentation with inline navigation title.

## Do's and Don'ts

- **Do** use system colors for status states — users instantly recognize green/red semantics.
- **Do** maintain 16pt padding on all primary screens for comfortable thumb reach.
- **Don't** request microphone permission on cold launch — always defer to first user action.
- **Don't** use custom fonts — SF Pro is required for native iOS feel.
- **Don't** nest more than 2 sheet levels deep — use NavigationStack within sheets if needed.

---
*Generated by TheClapper Design Spec Ingestion Pipeline on 2026-05-16 16:01*