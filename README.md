# 🍱 Bento

**Will it fit?** Measure real objects with your iPhone camera, share their exact
dimensions with anyone in the world as a tiny `.bento` file, and project them —
true to size — into your own room before you buy or ship.

Buying a jacket from someone abroad? A couch from another country? Bento answers
the only question that matters before it arrives: *does it fit me / my space?*

- 📷 **Camera-only measuring** — works on any ARKit iPhone, no LiDAR needed
- 📦 **Object box tool** — tap the corners, drag a slider, get real W×H×D
- 👕 **AR ruler** — two taps for clothing laid flat (chest, sleeve, length)
- 🛋️ **Pro extras (LiDAR iPhones)** — full 3D Object Capture & RoomPlan auto-scan
- 🫥 **Project into your room** — walk around a true-scale ghost box (or the
  actual captured 3D object) in AR
- ✅ **Fit check** — compares dimensions against your saved body/space profiles:
  *Fits / Tight / Won't fit*, with the slack in cm
- ✈️ **No backend** — the only thing that travels is a small JSON `.bento` card
  you explicitly share over Messages, mail, or AirDrop

---

## How two people use it

```
 Seller (abroad)                          You
 ───────────────                          ───
 1. + → measure the item
    (corners + height slider,
     or LiDAR auto-capture)
 2. Share card  ──────.bento──────▶  3. Open it — imports instantly
                                     4. "See it in my room" (AR), or
                                        "Fit check" vs your profile
```

The `.bento` card is just JSON with labelled dimensions in metres — small enough
for any chat app. Full 3D models (USDZ, from LiDAR capture) are shared
separately since they're megabytes.

## The tech (and why not Gaussian splatting)

"Will it fit" is a **measurement** problem, not a rendering problem. Splatting /
photogrammetry give pretty visuals but no reliable metric scale. Bento uses
Apple's metric-accurate AR stack instead:

| Feature | API | Requires |
|---|---|---|
| Object box (tap corners + height) | ARKit raycasting, `ARSCNView` | any ARKit iPhone |
| Two-tap ruler | ARKit raycasting | any ARKit iPhone |
| Ghost-box room projection | SceneKit + plane raycast | any ARKit iPhone |
| Full 3D object capture | `ObjectCaptureSession` + `PhotogrammetrySession` | LiDAR (Pro models) |
| Auto furniture box | RoomPlan | LiDAR (Pro models) |
| Real-object room projection | RealityKit (real-scale USDZ) | any — model comes from a LiDAR phone |

Scale on non-LiDAR phones comes from ARKit's visual-inertial odometry (camera +
motion sensors): expect ~2–3 % accuracy; LiDAR gets closer to 1 %. LiDAR-only
features hide themselves automatically on unsupported phones.

## Project layout

```
Bento/
  project.yml                    # XcodeGen definition — regenerate freely
  scripts/test-logic.sh          # pure-logic tests, no Xcode needed
  Tests/LogicSmokeTest.swift
  Sources/
    BentoApp.swift               # @main; .bento import via onOpenURL
    Models/                      # BentoCard, profiles, fit evaluator, store
    AR/                          # camera-only tools: ruler, box tool, ghost box
    Capture/                     # LiDAR extras: Object Capture, model library
    Sharing/                     # .bento JSON codec + share sheet
    Views/                       # SwiftUI screens
    Support/Info.plist           # camera permission + .bento type (handcrafted —
                                 #   do NOT add an `info:` key to project.yml,
                                 #   XcodeGen would overwrite this file)
```

## Development setup

Requirements: macOS + Xcode 15+, an iPhone on iOS 17+ (AR doesn't run in the
Simulator). No paid Apple Developer account needed — a free Apple ID signs
builds for your own device (7-day expiry, just re-run from Xcode).

```bash
brew install xcodegen
git clone https://github.com/cijjas/bento.git && cd bento
xcodegen generate           # creates Bento.xcodeproj (gitignored)
open Bento.xcodeproj
```

Then in Xcode:
1. **Settings → Accounts** → add your Apple ID (creates a free "Personal Team").
2. Target **Bento → Signing & Capabilities** → pick your team. If the bundle ID
   collides, change it to something personal.
3. Plug in your iPhone, select it as destination, hit ▶.
4. On the phone: enable **Developer Mode** (Settings → Privacy & Security) and
   trust the developer cert (Settings → General → VPN & Device Management).

### Testing without a device

The fit math and the `.bento` wire format run anywhere Swift does:

```bash
./scripts/test-logic.sh
```

### Status / honest caveats

- Core logic (fit evaluation, JSON round-trip) is compiled and tested green.
- The AR/RealityKit sources are hand-audited against the iOS 17 API but haven't
  been built against the iOS SDK yet — first device build may surface small
  API-name fixes, most likely in `Capture/` (Object Capture is the fussiest).
- Free-account signing can't distribute via TestFlight; the other person needs
  to build from source until there's a paid developer account.

## Roadmap ideas

- CloudKit sharing so cards/models sync without manual file sends
- Photo attachments on cards
- Guided clothing flow (shoulder-to-shoulder, then length)
- Gaussian-splat *visual* upgrade layered on top of the metric measurements
