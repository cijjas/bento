# Prompt for the next Claude session (on the Mac with Xcode)

Copy everything below the line into Claude Code, launched from the repo root.

---

I want to get this app running on my physical iPhone today. That is the only
goal of this session — guide me through it end to end and fix whatever breaks.

Context you need:

- This repo is **Bento** (github.com/cijjas/bento), an iOS 17 SwiftUI + ARKit
  app: measure objects with the camera, share dimensions as `.bento` files,
  project true-scale boxes/3D models into a room in AR, fit-check vs saved
  body/space profiles.
- The Xcode project is NOT committed — generate it with `xcodegen generate`
  (install via `brew install xcodegen` if missing). **Never add an `info:` key
  to project.yml** — it makes XcodeGen overwrite the handcrafted
  `Sources/Support/Info.plist`, which holds the camera-permission string and
  the `.bento` document type; losing it = crash on camera open.
- **Important:** the AR/RealityKit/Object Capture sources have NEVER been
  compiled against the iOS SDK (the previous machine had no Xcode). Expect the
  first `xcodebuild` to surface API-name errors, most likely in
  `Sources/Capture/` (ObjectCaptureSession / PhotogrammetrySession surface) and
  possibly RoomPlan delegate signatures. Fix them yourself by checking the SDK
  headers — the state-machine logic is correct, only symbol names may be off.
- I have **no paid Apple Developer account**. Use free personal-team signing:
  my Apple ID in Xcode → Settings → Accounts, team "Personal Team", automatic
  signing. If the bundle ID `com.bento.app` collides, change it to something
  unique under my name. App expires after 7 days — that's fine.
- My iPhone may need Developer Mode enabled (Settings → Privacy & Security)
  and the developer cert trusted (Settings → General → VPN & Device Management).
- I'm not familiar with Xcode or Apple distribution — spell out every click,
  and when something must be done on the phone itself, say so explicitly.

Plan of attack (adjust as needed):

1. Verify toolchain: `xcodegen generate`, then compile for a connected device
   or `generic/platform=iOS` from the CLI first so we see all build errors in
   one pass. Run `./scripts/test-logic.sh` too (should be ALL PASSED).
2. Fix every compile error until the app builds clean for iOS.
3. Walk me through signing + getting it onto my iPhone, step by step.
4. Verify on the phone with me:
   - + → Furniture → "Measure object box (camera)" on a real object
     (tap footprint corners, drag height slider) → save the card.
   - Card → "See it in my room (AR)" → ghost box appears at real size.
   - Card → "Share card" → AirDrop the `.bento` to myself → it re-imports.
   - If my iPhone is a Pro (LiDAR): also try "Capture full 3D model".
5. Commit and push whatever fixes were needed, with a clear message.

If a build error looks like an Apple API rename, check the actual iOS SDK in
this Xcode installation rather than guessing. If something can't work on my
specific iPhone model, tell me plainly instead of working around it silently.
