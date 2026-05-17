#!/usr/bin/env python3
"""
TheClapper Design Spec Ingestion Pipeline

Extracts design rationale, gesture sequences, and voice/audio interaction
patterns from the Swift codebase. Outputs a Figma-ready DESIGN.md spec with
embedded gesture sequence diagrams and component anatomy.

Usage:
    python3 scripts/generate_design_spec.py
"""

import re
import os
import sys
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Dict, Optional
from datetime import datetime

@dataclass
class ViewComponent:
    name: str
    file: str
    state_vars: List[str] = field(default_factory=list)
    actions: List[str] = field(default_factory=list)
    subviews: List[str] = field(default_factory=list)
    sheets: List[str] = field(default_factory=list)
    toolbar_items: List[str] = field(default_factory=list)

@dataclass
class GestureSequence:
    name: str
    steps: List[str] = field(default_factory=list)
    triggers: List[str] = field(default_factory=list)
    feedback: List[str] = field(default_factory=list)

@dataclass
class AudioPipeline:
    sample_rate: float
    buffer_size: int
    fft_size: int
    frequency_ranges: Dict[str, tuple] = field(default_factory=dict)
    thresholds: Dict[str, float] = field(default_factory=dict)

@dataclass
class DesignSpec:
    app_name: str = "TheClapper v2"
    version: str = "1.0.0"
    description: str = ""
    screens: List[ViewComponent] = field(default_factory=list)
    gestures: List[GestureSequence] = field(default_factory=list)
    audio: Optional[AudioPipeline] = None
    permissions: List[str] = field(default_factory=list)
    security_features: List[str] = field(default_factory=list)


class SwiftParser:
    """Extract design-relevant info from SwiftUI view files."""

    def __init__(self, source_dir: Path):
        self.source_dir = source_dir

    def parse_all(self) -> DesignSpec:
        spec = DesignSpec()
        spec.description = (
            "A gesture-driven iOS app that detects claps and snaps via microphone, "
            "triggers configurable actions per profile, and supports custom gesture training "
            "with DTW pattern matching."
        )

        # Parse UI views
        views_dir = self.source_dir / "TheClapper" / "UI" / "Views"
        for swift_file in views_dir.glob("*.swift"):
            component = self._parse_view(swift_file)
            spec.screens.append(component)

        # Parse gesture system
        gesture_dir = self.source_dir / "TheClapper" / "Core" / "Gesture"
        spec.gestures = self._parse_gestures(gesture_dir)

        # Parse audio pipeline
        audio_file = self.source_dir / "TheClapper" / "Core" / "Audio" / "AudioCapture.swift"
        spec.audio = self._parse_audio(audio_file)

        # Parse permissions from SettingsView
        settings_file = views_dir / "SettingsView.swift"
        spec.permissions = self._parse_permissions(settings_file)

        # Parse security features
        spec.security_features = self._parse_security_features()

        return spec

    def _parse_view(self, path: Path) -> ViewComponent:
        text = path.read_text()
        name = path.stem

        # Extract @State / @StateObject variables
        state_vars = re.findall(r'@State(?:Object)?\s+private\s+var\s+(\w+)', text)

        # Extract sheet destinations
        sheets = re.findall(r'\.sheet\(isPresented:.*?\{\s*(\w+)', text)

        # Extract toolbar items
        toolbar_items = re.findall(r'Button\s*\{.*?\}\s*label:\s*\{[^}]*Image\(systemName:\s*"([^"]+)"', text)

        # Extract actions from buttons
        actions = re.findall(r'Button\(action:\s*(\w+)\)', text)

        # Extract subviews (private var ...: some View)
        subviews = re.findall(r'private\s+var\s+(\w+):\s+some\s+View', text)

        return ViewComponent(
            name=name,
            file=str(path.relative_to(self.source_dir)),
            state_vars=state_vars,
            actions=actions,
            subviews=subviews,
            sheets=sheets,
            toolbar_items=toolbar_items
        )

    def _parse_gestures(self, gesture_dir: Path) -> List[GestureSequence]:
        gestures = []

        # Built-in gestures from GestureMatcher
        matcher_file = gesture_dir / "GestureMatcher.swift"
        if matcher_file.exists():
            text = matcher_file.read_text()
            # Extract built-in gesture types
            built_ins = [
                ("Single Clap", ["1 peak detected", "Type: clap"], ["Trigger profile action"], ["Haptic success", "Status update"]),
                ("Double Clap", ["2 peaks", "~0.3s apart", "Type: clap"], ["Trigger profile action"], ["Haptic success", "Status update"]),
                ("Triple Clap", ["3 peaks", "~0.3s apart", "Type: clap"], ["Trigger profile action"], ["Haptic success", "Status update"]),
                ("Single Snap", ["1 peak detected", "Type: snap"], ["Trigger profile action"], ["Haptic success", "Status update"]),
                ("Double Snap", ["2 peaks", "~0.3s apart", "Type: snap"], ["Trigger profile action"], ["Haptic success", "Status update"]),
            ]
            for name, steps, triggers, feedback in built_ins:
                gestures.append(GestureSequence(name=name, steps=steps, triggers=triggers, feedback=feedback))

        # Custom gesture training
        gestures.append(GestureSequence(
            name="Custom Gesture Training",
            steps=[
                "User opens GestureTrainingView sheet",
                "Enter gesture name",
                "Record sample 1/3 (3-second capture)",
                "Record sample 2/3 (3-second capture)",
                "Record sample 3/3 (3-second capture)",
                "DTW validation: all 3 samples must match within distance < 0.2",
                "Save to TemplateStore (encrypted)",
                "Register App Intent binding"
            ],
            triggers=["Custom gesture now available in profile actions"],
            feedback=["Validation passed/failed message", "Saved confirmation"]
        ))

        return gestures

    def _parse_audio(self, audio_file: Path) -> AudioPipeline:
        text = audio_file.read_text()

        # Extract config values
        sample_rate = float(re.search(r'sampleRate:\s*Double\s*=\s*(\d+\.?\d*)', text).group(1))
        buffer_size = int(re.search(r'bufferSize:\s*UInt32\s*=\s*(\d+)', text).group(1))

        # Extract from PeakDetector
        peak_file = audio_file.parent / "PeakDetector.swift"
        peak_text = peak_file.read_text() if peak_file.exists() else ""

        freq_ranges = {}
        thresholds = {}
        if peak_text:
            clap_match = re.search(r'clapRange.*?=\s*(\d+)\.\.(\d+)', peak_text)
            snap_match = re.search(r'snapRange.*?=\s*(\d+)\.\.(\d+)', peak_text)
            if clap_match:
                freq_ranges["clap"] = (int(clap_match.group(1)), int(clap_match.group(2)))
            if snap_match:
                freq_ranges["snap"] = (int(snap_match.group(1)), int(snap_match.group(2)))

            thresh_clap = re.search(r'clapThreshold.*?=\s*(\d+\.?\d*)', peak_text)
            thresh_snap = re.search(r'snapThreshold.*?=\s*(\d+\.?\d*)', peak_text)
            if thresh_clap:
                thresholds["clap"] = float(thresh_clap.group(1))
            if thresh_snap:
                thresholds["snap"] = float(thresh_snap.group(1))

        return AudioPipeline(
            sample_rate=sample_rate,
            buffer_size=buffer_size,
            fft_size=2048,  # Inferred from code comment
            frequency_ranges=freq_ranges,
            thresholds=thresholds
        )

    def _parse_permissions(self, settings_file: Path) -> List[str]:
        if not settings_file.exists():
            return []
        text = settings_file.read_text()
        perms = []
        if "AVAudioSession" in text or "microphone" in text.lower():
            perms.append("Microphone (NSMicrophoneUsageDescription)")
        if "CLLocationManager" in text or "location" in text.lower():
            perms.append("Location (NSLocationWhenInUseUsageDescription)")
        if "UNUserNotificationCenter" in text or "notification" in text.lower():
            perms.append("Notifications (UNUserNotificationCenter)")
        return perms

    def _parse_security_features(self) -> List[str]:
        features = []
        pm_file = self.source_dir / "TheClapper" / "Core" / "Profile" / "ProfileManager.swift"
        if pm_file.exists():
            text = pm_file.read_text()
            if "allowedSchemes" in text:
                features.append("URL scheme whitelist (https, http, shortcuts)")
            if "applicationSupportDirectory" in text and "completeFileProtection" in text:
                features.append("Encrypted profile storage (Library/Application Support + .completeFileProtection)")
            if "com.edgeless.clapper." in text:
                features.append("Reverse-DNS notification namespacing")
        
        ts_file = self.source_dir / "TheClapper" / "Core" / "Gesture" / "TemplateStore.swift"
        if ts_file.exists():
            text = ts_file.read_text()
            if "applicationSupportDirectory" in text and "completeFileProtection" in text:
                features.append("Encrypted gesture template storage")

        ac_file = self.source_dir / "TheClapper" / "Core" / "Audio" / "AudioCapture.swift"
        if ac_file.exists():
            text = ac_file.read_text()
            if "recordPermission == .granted" in text:
                features.append("Runtime microphone permission guard")

        return features


def generate_gesture_diagram(gesture: GestureSequence) -> str:
    """Generate an ASCII gesture sequence diagram for Figma annotation."""
    lines = [f"### {gesture.name}", ""]
    
    # Timeline diagram
    lines.append("```")
    lines.append("User          App                    Audio Pipeline              Profile")
    lines.append(" |             |                          |                         |")
    
    for i, step in enumerate(gesture.steps):
        arrow = " |------------>" if i % 2 == 0 else " <------------|"
        actor = ["User", "App", "Audio", "Profile"][i % 4]
        lines.append(f" {actor:12} {arrow} {step}")
    
    lines.append(" |             |                          |                         |")
    lines.append("```")
    lines.append("")
    
    if gesture.triggers:
        lines.append("**Triggers:**")
        for t in gesture.triggers:
            lines.append(f"- {t}")
        lines.append("")
    
    if gesture.feedback:
        lines.append("**Feedback:**")
        for f in gesture.feedback:
            lines.append(f"- {f}")
        lines.append("")
    
    return "\n".join(lines)


def generate_audio_pipeline_diagram(audio: AudioPipeline) -> str:
    """Generate an ASCII audio pipeline diagram."""
    lines = [
        "### Audio Pipeline Architecture",
        "",
        "```",
        "[Mic Input] --16kHz--> [AVAudioEngine] --1024-sample buffer--> [FFTProcessor]",
        "                                                            |",
        "                                                            v",
        "[PeakDetector] <--magnitudes-- [Energy calc per bin] <-- [vDSP]",
        "     |",
        "     |-- Clap: 256-640 bins (2-5kHz), thresh > 0.6",
        "     |-- Snap: 640-1024 bins (5-8kHz), thresh > 0.5",
        "     |",
        "     v",
        "[GestureMatcher] --DTW distance--> [ProfileAction]",
        "```",
        "",
        f"**Sample Rate:** {audio.sample_rate} Hz  ",
        f"**Buffer Size:** {audio.buffer_size} samples  ",
        f"**FFT Size:** {audio.fft_size} bins  ",
    ]
    
    if audio.frequency_ranges:
        lines.append("**Frequency Ranges:**")
        for name, (low, high) in audio.frequency_ranges.items():
            lines.append(f"- {name.capitalize()}: bins {low}-{high}")
    
    if audio.thresholds:
        lines.append("**Thresholds:**")
        for name, val in audio.thresholds.items():
            lines.append(f"- {name.capitalize()}: {val}")
    
    lines.append("")
    return "\n".join(lines)


def generate_screen_flow(spec: DesignSpec) -> str:
    """Generate a screen flow diagram."""
    lines = ["### Screen Flow", "", "```"]
    
    # Find main screens
    main_screens = [s for s in spec.screens if s.name in ["ContentView", "GestureTrainingView", "SettingsView", "PaywallView", "ProfileEditorView"]]
    
    lines.append("+------------------+        +------------------+        +------------------+")
    lines.append("|   ContentView    |<------>| GestureTraining  |<------>|   ProfileEditor  |")
    lines.append("|   (Main Screen)  |  sheet |   (Train Custom) |  sheet |  (Edit Triggers) |")
    lines.append("+--------+---------+        +------------------+        +------------------+")
    lines.append("         |")
    lines.append("         | sheet")
    lines.append("         v")
    lines.append("+--------+---------+        +------------------+")
    lines.append("|    PaywallView   |<------>|   SettingsView   |")
    lines.append("|  (Premium Gate)  |  sheet | (Permission Mgmt)  |")
    lines.append("+------------------+        +------------------+")
    lines.append("```")
    lines.append("")
    
    for screen in main_screens:
        lines.append(f"**{screen.name}** (`{screen.file}`)")
        if screen.state_vars:
            lines.append(f"- State: {', '.join(screen.state_vars[:5])}")
        if screen.sheets:
            lines.append(f"- Sheets: {', '.join(screen.sheets)}")
        if screen.toolbar_items:
            lines.append(f"- Toolbar: {', '.join(screen.toolbar_items[:3])}")
        lines.append("")
    
    return "\n".join(lines)


def generate_figma_spec(spec: DesignSpec) -> str:
    """Generate the full DESIGN.md spec."""
    lines = [
        "---",
        f"version: {spec.version}",
        f"name: {spec.app_name}",
        f"description: {spec.description}",
        "platform: iOS",
        "target: iPhone / iPad",
        "colors:",
        '  primary: "#007AFF"',
        '  secondary: "#6C7278"',
        '  success: "#34C759"',
        '  danger: "#FF3B30"',
        '  warning: "#FF9500"',
        '  neutral: "#F2F2F7"',
        "typography:",
        "  h1:",
        "    fontFamily: SF Pro Display",
        "    fontSize: 28px",
        "    fontWeight: 700",
        "    lineHeight: 1.2",
        "  body:",
        "    fontFamily: SF Pro Text",
        "    fontSize: 17px",
        "    fontWeight: 400",
        "    lineHeight: 1.5",
        "  caption:",
        "    fontFamily: SF Pro Text",
        "    fontSize: 12px",
        "    fontWeight: 400",
        "    lineHeight: 1.3",
        "rounded:",
        "  sm: 8px",
        "  md: 12px",
        "  lg: 16px",
        "  full: 9999px",
        "spacing:",
        "  xs: 4px",
        "  sm: 8px",
        "  md: 16px",
        "  lg: 24px",
        "components:",
        "  status-banner:",
        '    backgroundColor: "{colors.success}"',
        '    textColor: "{colors.primary}"',
        '    rounded: "{rounded.md}"',
        "    padding: 16px",
        "  gesture-card:",
        '    backgroundColor: "{colors.neutral}"',
        '    textColor: "{colors.primary}"',
        '    rounded: "{rounded.md}"',
        "    padding: 16px",
        "  record-button:",
        '    backgroundColor: "{colors.primary}"',
        '    textColor: "#FFFFFF"',
        '    rounded: "{rounded.full}"',
        "    size: 160px",
        "---",
        "",
        "# TheClapper v2 — Design Spec",
        "",
        "## Overview",
        "",
        f"{spec.description}",
        "",
        "The design philosophy centers on **immediate feedback** and **low-friction interaction**:",
        "users should clap/snap once and see their configured action trigger instantly. "
        "The UI is intentionally minimal — a single record button, a status banner, and a scrollable "
        "gesture list — to keep focus on the audio-gesture loop rather than navigation.",
        "",
        "## Voice & Tone",
        "",
        "- **Direct:** Status messages say exactly what happened (\"Matched: Double Clap\").",
        "- **Calm:** No alarming colors unless there's an error. Green = listening, red = recording/training.",
        "- **Empowering:** Custom gesture training guides users through 3 samples with clear progress indicators.",
        "",
        "## Colors",
        "",
        "- **Primary (#007AFF):** Main action driver — record button, active training states, toolbar accents.",
        "- **Success (#34C759):** Listening status banner, validation passed indicators, progress dots.",
        "- **Danger (#FF3B30):** Recording state, permission denied alerts, validation failures.",
        "- **Neutral (#F2F2F7):** Card backgrounds, gesture list rows, sheet backgrounds.",
        "- **Secondary (#6C7278):** Metadata text (trigger counts, captions), inactive states.",
        "",
        "## Typography",
        "",
        "SF Pro family throughout. Display sizes use SF Pro Display; body and captions use SF Pro Text. "
        "No custom fonts — keeps app lightweight and native-feeling.",
        "",
        "## Gesture Interaction Design",
        "",
    ]
    
    # Add gesture sequence diagrams
    for gesture in spec.gestures:
        lines.append(generate_gesture_diagram(gesture))
    
    lines.extend([
        "## Audio Pipeline",
        "",
        generate_audio_pipeline_diagram(spec.audio) if spec.audio else "_Audio pipeline not parsed._",
        "",
        "## Screen Architecture",
        "",
        generate_screen_flow(spec),
        "",
        "## Permissions UX",
        "",
        "The app requires the following permissions, requested at first user action (not cold launch):",
        "",
    ])
    
    for perm in spec.permissions:
        lines.append(f"- {perm}")
    lines.append("")
    lines.extend([
        "SettingsView provides a unified permission management interface where users can:",
        "- View current permission status",
        "- Request denied permissions",
        "- Open system Settings for granular control",
        "",
        "## Security & Privacy",
        "",
    ])
    
    for feature in spec.security_features:
        lines.append(f"- {feature}")
    lines.append("")
    lines.extend([
        "## Figma Annotation Notes",
        "",
        "### For Designers:",
        "",
        "1. **Gesture Cards** — Use the gesture-card component spec. Each row should show:",
        "   - Left: SF Symbol icon (24pt, Blue)",
        "   - Center: Gesture name (Headline) + trigger count (Caption, Secondary)",
        "   - Right: 'CUSTOM' pill (if applicable, Purple, Caption2, Bold)",
        "",
        "2. **Record Button** — 160×160pt circle. Use system Blue when idle, system Red when recording. "
        "Add shadow: color opacity 0.35, radius 16pt.",
        "",
        "3. **Status Banner** — Full-width, 16pt padding, 14pt corner radius. "
        "Green tint when listening, red tint when recording. "
        "Include 10pt status dot (left) and active profile pill (right, 999pt radius, Gray6 bg).",
        "",
        "4. **Training Flow** — 3-step horizontal progress (14pt circles). "
        "Active step = Blue, completed = Green, pending = Gray 30% opacity.",
        "",
        "5. **Sheet Modals** — All secondary flows (training, paywall, settings, profile editor) "
        "use `.sheet` presentation with inline navigation title.",
        "",
        "## Do's and Don'ts",
        "",
        "- **Do** use system colors for status states — users instantly recognize green/red semantics.",
        "- **Do** maintain 16pt padding on all primary screens for comfortable thumb reach.",
        "- **Don't** request microphone permission on cold launch — always defer to first user action.",
        "- **Don't** use custom fonts — SF Pro is required for native iOS feel.",
        "- **Don't** nest more than 2 sheet levels deep — use NavigationStack within sheets if needed.",
        "",
        "---",
        f"*Generated by TheClapper Design Spec Ingestion Pipeline on {datetime.now().strftime('%Y-%m-%d %H:%M')}*",
    ])
    
    return "\n".join(lines)


def main():
    repo_root = Path(__file__).resolve().parents[1]
    parser = SwiftParser(repo_root)
    spec = parser.parse_all()
    
    output_path = repo_root / "DESIGN.md"
    output_path.write_text(generate_figma_spec(spec))
    print(f"✅ Design spec generated: {output_path}")
    print(f"   Screens: {len(spec.screens)}")
    print(f"   Gestures: {len(spec.gestures)}")
    print(f"   Security features: {len(spec.security_features)}")


if __name__ == "__main__":
    main()
