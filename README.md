# Boswell

An on-device iPhone consultation scribe prototype: **the AI drafts, code checks,
the clinician decides**. The intended app records with patient agreement,
transcribes locally, drafts a structured note, checks each item against the
transcript, requires clinician review/sign-off, then exports the approved note.
No server, cloud AI or Private Cloud Compute is part of this architecture.

**Current status: foundation plus a BW-2 device-check probe. Not for real patient
use.** The app shows the evidence colour key and developer speech/AI checks.
Consultation recording, note drafting, checking, storage, review enforcement and
exports are not implemented yet. `Verified` will mean transcript support, not
clinical verification. The probe is not evidence of device feasibility until
the physical-iPhone checks below have actually been run.

## Build and test Core (Linux or Mac)

```sh
.agents/setup --run-tests
```

The executable setup script prepares Swift and builds/tests `BoswellCore`. It
uses Swift 5.9 or newer already on PATH, then checks an existing swiftly
environment. On Linux it can install swiftly 1.1.2 and Swift 6.2. On macOS,
install/select Xcode 27 if suitable Swift is missing. Core has no third-party
dependencies and no backing services or secrets to configure.

```sh
.agents/setup                 # prepare tools and compile Core plus its tests
.agents/setup --no-build      # prepare tools only
.agents/tests/setup_test.sh   # offline installer tests using stand-in commands
```

`--run-tests` runs tests even when combined with `--no-build`; `--help` lists
options. Exit codes: 0 ready, 1 build/test failure, 2 unavailable toolchain,
64 invalid option. `BOSWELL_SWIFT_VERSION` overrides the version for a **new**
installation, not an already suitable Swift on PATH. A cold install needs network
access to `download.swift.org` and `www.swift.org`, plus the system package mirror
when dependencies are missing. Linux package installation uses root or
non-interactive passwordless sudo; otherwise setup names the prerequisites an
administrator must install. It never prompts for a password.

Fresh remote environments run `.agents/setup`; installed tools and build caches
can be snapshotted for later environments. A warm setup checks/reuses those
tools and performs an incremental build, rather than unconditionally downloading
them again. No resume script or long-lived service is needed by this scaffold.

## Build the iPhone app (Mac only)

Use Xcode 27 with the iOS platform installed:

```sh
brew install xcodegen
xcodegen generate
xcodebuild build -project Boswell.xcodeproj -scheme Boswell \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Open generated `Boswell.xcodeproj`, select scheme **Boswell** and an iPhone
simulator to run the starter screen or inspect its SwiftUI preview. Check light
and dark appearance and large Dynamic Type. Linux can build/test Core but cannot
build or render SwiftUI, use the iPhone simulator, or sign the app.

For a physical device, put your own `DEVELOPMENT_TEAM` and a unique
`PRODUCT_BUNDLE_IDENTIFIER` in **Config/Signing.xcconfig** (git-ignored), then
regenerate the project. The default `com.example.Boswell` is a development
placeholder. The optional config is included by `Config/Boswell.xcconfig`;
never commit team credentials, signing keys or profiles.

## Check a physical iPhone (BW-2)

Open **Developer checks → Check this iPhone**. This developer probe uses Apple's
on-device frameworks, not a server, cloud AI or Private Cloud Compute. It does
not request microphone access or save the selected audio, transcript or results.
Speech-file installation uses the network, and choosing an iCloud file can cause
Files to download it. Neither action is proof of offline operation.

1. Tap **Check again**. Check British-English support and speech-file readiness.
   A different English region is reported rather than silently substituted.
2. If offered, tap **Download speech files** and let installation finish.
3. On your phone, make a short fictional clip, for example: “This is a fictional
   test. Alex has had a cough for two days.” Save it locally in Files. Do not use
   a patient recording. Select it with **Choose fictional audio clip**; the limit
   is 60 seconds. Compare the returned words with the clip, and check the counts
   of timed text runs and runs with confidence. Runs are not necessarily words.
4. Enable Apple Intelligence in Settings if needed and let its model download.
   Run the fictional AI test. Expected structured output: name **Pip**, species
   **cat**. The screen reports the actual values, prompt token count, context
   limit and elapsed time. Failure is reported without a cloud fallback.
5. Turn on Airplane Mode **and turn Wi-Fi off**. Repeat both tests with the clip
   stored locally. Do not claim offline success from the availability check alone.
6. Try light/dark appearance and the largest accessibility text size. Check that
   long results remain readable, buttons disable while a task runs, and returning
   to the home screen still works. Simulator results cannot prove phone support.

Record the following with fictional data only; all entries are **not run** until
a person fills them in after testing. No device identifiers are needed.

| Check | Device/OS and observed result |
| --- | --- |
| Supported physical iPhone: British-English files, transcription, timing/confidence | Not run |
| Structured AI output, context limit, prompt tokens and elapsed time | Not run |
| Both real tests with Airplane Mode on and Wi-Fi off | Not run |
| Apple Intelligence disabled/not ready: useful explanation and disabled AI test | Not run |
| Speech files absent, download fails offline, retry after reconnecting | Not run |
| Empty, silent, unreadable or over-60-second clip: no false success | Not run |
| Simulator/unsupported device: no claim of physical-device success | Not run |
| Light/dark, large text, busy buttons and navigation | Not run |

BW-2 does not implement live capture, the clinical drafting prompt, clinical
accuracy checks, persistent reports or the full BW-8/BW-9 pipeline.

## Layout and checks

| Path | Purpose |
| --- | --- |
| `project.yml`, `Config/` | XcodeGen app spec and optional local signing |
| `App/` | SwiftUI app, evidence key and device-check probe |
| `BoswellCore/` | Foundation-only data contracts, fictional transcript and XCTest tests |
| `.agents/` | Repeatable Swift setup and offline setup tests |
| `.github/workflows/` | macOS Core/app checks and clean Ubuntu setup checks |

CI uses SHA-pinned actions. `ci.yml` runs Core tests and builds the unsigned
app on `xcode-27`; `agents-setup.yml` runs shellcheck, offline installer tests
and two real setup/test runs in an `ubuntu:24.04` container. The second setup
must reuse the installed Swift toolchain. CI is configured in these files;
successful runs still require publishing the branch to GitHub.

## Fictional sample and next steps

`SampleConsultation.transcript` contains 28 fictional chest-infection lines.
The supplied examples at L16, L23 (01:39) and L24 are preserved; the remaining
lines and all timing/confidence values are authored synthetic test data. No
audio is supplied. This is not treatment advice or measured transcription output.

Later checker/assembly tickets will freeze an independently reviewed simulated
draft and per-item expected results: the target example is 11 items (8 green,
1 yellow, 2 red), with four omission alerts at L16/17/24/26. Those are **not**
results this scaffold produces, nor evidence of a live model's accuracy.

Next: finish physical-device feasibility checks (BW-2), normalization (BW-3) and
portable transcript chunking (BW-5), before evidence checking, note assembly,
review and the full app.
Speech and AI capability must be tested on an actual supported iPhone before
claiming end-to-end on-device operation.

See [CONTRIBUTING](CONTRIBUTING.md) for boundaries, ticket review and privacy rules.
All audio, generated exports, build projects and local signing settings are
ignored by git. **Fictional data only; no real patient use.**
