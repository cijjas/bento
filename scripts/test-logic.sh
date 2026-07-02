#!/bin/bash
# Runs Bento's pure-logic smoke test. Needs only the Swift toolchain that
# ships with Xcode Command Line Tools — no full Xcode, no iOS SDK, no device.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="$(mktemp -d)/fitlogic"
swiftc -o "$OUT" \
    Sources/Models/BentoCard.swift \
    Sources/Models/Profiles.swift \
    Sources/Models/FitEvaluator.swift \
    Tests/LogicSmokeTest.swift
"$OUT"
