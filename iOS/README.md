# FLX by MP-audio

Native iOS/iPadOS development source, version 0.1.0. SwiftUI interface, AVAudioEngine output, and an original portable C++17 audio renderer. No web view, server, account, online API or physical DJ controller is required by the implemented playback path.

**Delivery status: source project only. Not compiled for iOS, installed, deployed, submitted to TestFlight, or production validated. This does not implement every feature in the supplied DDJ-FLX10 PDF.** The complete supplied PDF is retained in `Docs/`, and its text is bundled for in-app reference. See `Docs/FEATURE_STATUS.md` for the explicit gaps.

## Open and run

1. On a Mac with Xcode and the iOS SDK, open `FLX.xcodeproj`.
2. Select the FLX scheme and an iPhone/iPad simulator. Build and run. Alternatively, run `bash Scripts/build-ios.sh`.
3. For a physical device, choose your Apple development team under Signing & Capabilities and replace `com.mpaudio.flx` with your own available bundle identifier. Select your connected device and run.
4. Tap the folder on a deck, then Import audio from Files. Use unprotected WAV, AIFF, MP3, AAC or M4A audio supported by the installed OS.
5. Set BPM manually or use TAP; GRID 0 sets the grid origin at the current position. Press PLAY. The initial crossfader assignment is THRU; assign channels to A or B to use the crossfader.

The generated project is included. `python3 Scripts/generate-project.py` can regenerate it without XcodeGen or package dependencies. The app targets iOS 17 or later. Simulator playback is not evidence of device latency or DJ reliability.

## Implemented source

- Four independent software decks, file import and persistent local library.
- Play/pause, temporary cue, seeking, overview waveform, latching reverse, variable-speed playback.
- Manual tempo/grid, tap tempo, one-shot beat-phase and tempo alignment to a selected master.
- Sixteen persisted hot cues per track, two pad pages, beat jump and beat-loop pad modes.
- Manual loop in/out, halve/double, four-beat loop, loop exit and basic slip return.
- Four mixer channels, trim, three-band EQ with −26…+6 dB control range, pre-fader cue tap and low/high-pass filter.
- A/B/THRU assignment, equal-power crossfader, master gain, mono output and mono split cue/master routing.
- Original echo, low-cut echo, flanger, trans, basic reverb, phaser and crush DSP. These are not copies of AlphaTheta DSP and do not promise matching sound.
- Native adaptive iPhone/iPad interface, local error messages, accessibility labels, audio interruption pause, app icon and initial privacy manifest.

## Verification performed

`ASAN_OPTIONS=detect_leaks=0 bash Scripts/test-dsp.sh`

Result: **22 portable C++ DSP scenarios passed**, compiled with strict warnings, AddressSanitizer and UndefinedBehaviorSanitizer. LeakSanitizer could not inspect the container's `/proc` thread state, so leak detection was disabled for this run. No assertion, ASan or UBSan failures were reported in the successful run.

Tests cover silence without audio, play/pause timing, playback rate, reverse, forward and reverse loops, end-of-track stop, file-rate conversion timing, crossfader isolation, THRU, cue isolation before the channel fader, four-deck finite output, all seven implemented FX, invalid parameters, and concurrent atomic control updates.

All four Swift files also passed a tree-sitter syntax parse (not a Swift type check). Property-list parsing, scheme XML, project file references and source packaging were checked separately. No Swift compiler or Apple SDK exists in the execution environment. **Swift type checking, Xcode linking, simulator UI, on-device audio, performance, thermal behavior, accessibility and signing remain unverified.** The build script exits with a clear error when Xcode is absent.

## Important implementation limits

- Full tracks are decoded into memory. Per-track ceiling: 16,777,216 stereo frames (128 MiB); all decks: 384 MiB. At 44.1 kHz, the per-track limit is approximately 6m20s. Decoder staging can temporarily increase memory use. This is not yet a streaming, live-performance-safe engine.
- Installing a decoded track briefly stops the audio engine to safely replace PCM buffers. Other decks retain their state but the output pauses during installation.
- Resampling uses linear interpolation; there is no independent key lock, pitch-preserving time stretch or bandlimited quality mode. Changing tempo changes pitch. Fast seeks can click; scrub is not continuous vinyl scratching.
- BPM defaults to an explicitly manual 120 until edited/tapped. There is no automatic BPM or key analysis. Sync is a one-time alignment, not continuous phase locking. Quantize snaps cue/loop placement, not all live events.
- Slip return uses a monotonic host clock for basic jog/loop return. It is not a sample-accurate implementation of all FLX10 slip behaviors.
- Effects and EQ are independent approximations. Reverb is a basic feedback-delay effect; phaser is a simple all-pass design. The hardware's proprietary coefficients, filter slopes and processing topology are not provided in the reference.
- Output has an emergency hard ceiling at ±1. This is not a transparent look-ahead limiter. Loud mixes may clip audibly. Metering is per-channel peak, before the channel fader.
- Standard stereo output or split cue only. Separate stereo headphones, master and booth require a multichannel audio backend and compatible hardware, which are not implemented.
- Imported audio and cues remain in the app sandbox. No telemetry or network calls are implemented. Deleting the app deletes the local library unless separately backed up.

## Distribution

`Scripts/archive-ios.sh` prepares an archive only on a suitably configured Mac. It requires `FLX_APPLE_TEAM_ID` and `FLX_BUNDLE_ID`. It does not upload or publish anything. Review the remaining implementation and device-validation requirements before distributing this build.

The repository workflow at `.github/workflows/ios-build.yml` on the `ios-setup` branch of `sroohi/FLX` builds the `iOS/` directory. It checks the simulator and physical-device targets without signing. The workflow bundled inside this standalone source folder instead expects the project at the repository root.

A remote run was requested, but GitHub refused to start either job because recent account payments failed or the spending limit needs to be increased. Resolve that under GitHub Settings → Billing & plans, then rerun the workflow. No Xcode compilation, simulator runtime, physical-device installation or TestFlight deployment has been verified.

Automatic signing is enabled for Debug and Release. No Apple team or credential was invented or embedded. The build/archive scripts use the included project and only generate one if it is missing, preserving the team and bundle identifier you select in Xcode.

## Reference and identity

The PDF's overall dimensions (716 × 400.3 × 73.4 mm), weight, power, electrical levels, impedance, physical ports and analogue performance specifications belong to DDJ-FLX10 hardware. They cannot be implemented as iPhone hardware specifications. The PDF does not provide individual control coordinates, jog diameter, fader travel or exact DSP algorithms. FLX therefore does not claim an exact measured replica.

FLX is independent MP-audio software. No affiliation or endorsement by AlphaTheta, Pioneer DJ, rekordbox or Serato is claimed. No vendor software, paid expansion pack or stem model is included.

Official API reference consulted: https://developer.apple.com/documentation/avfaudio/avaudiosourcenode

## Preparation checks in this session

The uploaded archive passed all of its original SHA-256 checks. Its 22 portable DSP scenarios passed locally with AddressSanitizer and UndefinedBehaviorSanitizer. The prepared project's file references, plist files, shared scheme and shell syntax were checked. `Docs/VALIDATION.json` records the current blocker. `SHA256SUMS.txt` describes this prepared source, including the documented script changes.
