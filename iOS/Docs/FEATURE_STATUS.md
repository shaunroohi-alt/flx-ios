# PDF feature coverage

This document records implementation scope against all 19 sections of the supplied 30-page technical reference. **Implemented source** means code exists, not that the native app has passed an iOS build or device test. **Partial** identifies specific differences. **Absent** means no implementation. **Hardware/reference** means the supplied specification is retained as information, not represented as an iPhone capability.

| PDF section | Feature | Status | Actual behavior / gap |
|---|---|---|---|
| 1 | Chassis 716 × 400.3 × 73.4 mm; 6.7 kg | Hardware/reference | Preserved in supplied PDF and in-app reference; adaptive touch layout |
| 1 | PSU, current, consumption, operating temperature/humidity | Hardware/reference | No phone capability inferred |
| 1 | 44.1 kHz sample rate | Implemented source | Internal render rate; iOS may convert for the output device |
| 1 | 24-bit A/D and D/A | Hardware/reference | Software uses Float32; no control of physical converter specification |
| 1 | S/N, THD, frequency response, impedance, crosstalk | Hardware/reference | No equivalence claims or measurements made |
| 1 | Channel EQ −26…+6 dB | Partial | Range retained; own peak filters at 80 Hz, 1 kHz and 10 kHz, not hardware coefficients |
| 1 | Mic EQ ±12 dB | Absent | Mic path not implemented |
| 1–2 | RCA, phono, XLR, TRS, two USB hosts, 512-channel DMX | Hardware/reference | No physical ports or hardware driver integration |
| 2 | Decks 1/3 left, 2/4 right; four-channel mixer | Implemented source | Tablet layout; phone shows one selected deck and all four mixer channels |
| 3 | Browse/load tracks | Partial | Local Files import and library selection; no hardware browse encoder |
| 3 | Instant Doubles | Absent | No clone command |
| 3 | Tag List, playlist palette, PREPARE, Related Tracks | Absent | Flat local library only |
| 4 | Cue/loop memory call/save/delete | Partial | Hot cues saved, temporary cue; saved loop/cue-call navigation absent |
| 4 | Mix Point Select / Link / Silent | Absent | No auto-start link state machine |
| 4 | Quantize | Partial | Snap cue/loop placement to manually entered grid |
| 4 | Slip | Partial | Basic clock-based return for jog seek and loop exit only |
| 4 | Vinyl mode / Jog Feel | Absent | No physical or virtual inertia model |
| 4 | Beat Sync / master | Partial | Manual BPM, one-shot tempo/phase alignment; no continuous sync or ×2/½ sync modes |
| 4 | Tempo slider / reset | Partial | ±6/10/16 and WIDE UI; no Serato profile; rate changes pitch |
| 4 | Key Sync / key lock | Absent | No key analysis or independent pitch processing |
| 4 | Deck selection | Implemented source | Select any of four independently playing decks |
| 4 | Dual Deck | Absent | No linked deck gestures |
| 4 | Play/pause | Implemented source | Tested kernel transport; native control not device-tested |
| 4 | Cue | Partial | Set when paused / return and stop when playing; no held cue sampler |
| 4 | Jog top/side scratching and pitch bend | Partial | Touch jog seeks; no vinyl scratch or independent pitch-bend model |
| 4 | 4/16-beat jump / fast search | Partial | ±4 buttons and variable beat-jump pads; no hold fast-search state machine |
| 4 | Reverse | Partial | Latching reverse; no 8-beat slip-reverse auto-cancel |
| 4 | Loop in/out, half/double, four-beat, exit | Implemented source | PCM loop boundaries tested; native controls pending |
| 4 | Active loop/reloop/jog boundary editing | Absent | No saved active-loop metadata or boundary-jog mode |
| 4 | Active Part drums/vocal/instrument | Absent | No stem model or pre-separated stem import |
| 4 | Part Instant Doubles | Absent | Depends on stems and clone routing |
| 5 | Input A/LINE/PHONO/B | Hardware/reference | App reads local PCM only |
| 5 | Master gain, trim, channel fader | Implemented source | Four channels, smoothed fader gain |
| 5 | Booth gain/output | Absent | No independent output bus |
| 5 | Channel meters | Partial | Pre-fader peak values; no calibrated hardware meter behavior |
| 5 | Master meters / flashing clip indicator | Absent | Output ceiling exists, UI master meter absent |
| 5 | Part ISO | Absent | No stem routing |
| 5 | Channel headphones cue | Implemented source | Pre-fader cue tap tested |
| 5 | Crossfader A/B/THRU | Implemented source | Equal-power A/B, THRU bypass; isolation tested |
| 5 | Crossfader curves / cut lag | Absent | No variable curve or 0.3–5.5 mm model |
| 5 | Fader start / crossfader start | Absent | No SHIFT gesture integration |
| 5 | Phones mix/level and mono split | Partial | Left cue/right mono master; no normal/inverse switch or independent stereo phones |
| 5 | Sampler volume/cue | Absent | No sampler engine |
| 5 | Mic on/off/talkover / two mic levels | Absent | No input-monitoring path |
| 6 | Stem-targeted effects | Absent | No stem engine |
| 6 | FX display, beat amount, depth | Partial | Per-deck picker and depth; no hardware display protocol or global selector |
| 6 | FX destinations CH1–4 | Partial | Independent effects on each deck |
| 6 | FX master/mic/sampler targets | Absent | No global FX target buses |
| 6 | Release FX | Absent | No release-effect state machine |
| 7 | Jog position/time/BPM/deck/on-air | Partial | Native jog overview displays these; no artwork, key, cue scope or digital marker modes |
| 7 | Stacked waveforms | Absent | Single overview per visible deck |
| 7 | Mix Point overlay / custom DJ logo / artwork modes | Absent | No equivalent modes |
| 8 | Hot Cue A–P / page selection | Partial | 16 persisted cue positions; no loop cues, gating or Serato 8-cue profile |
| 8 | Keyboard / Pitch Play | Absent | Requires pitch processing |
| 8 | Saved Flip | Absent | No recorded gesture sequencer; no Serato expansion integration |
| 8 | Pad FX 1/2 | Absent | No held pad effect matrix |
| 8 | Beat Jump | Partial | First-page −1,+1,−2,+2,−4,+4,−8,+8; second page ×16 is FLX design, not exact documented behavior |
| 8 | Beat Loop | Partial | First page 1/64…2 beats; second page 4…512; no Serato profile or loop shift |
| 8 | Sampler / banks | Absent | No sample voices or banks |
| 8 | Key Shift | Absent | No independent pitch processing |
| 9 | Echo / Low Cut Echo | Partial | Original feedback-delay implementations, not proprietary equivalents |
| 9 | Multi Tap Delay / Spiral | Absent | Not exposed as working effects |
| 9 | Reverb | Partial | Basic feedback-delay ambience, not a matched reverb model |
| 9 | Trans | Partial | Original periodic amplitude gate |
| 9 | Enigma Jet | Absent | Not exposed |
| 9 | Flanger | Partial | Original short modulated delay |
| 9 | Phaser | Partial | Simple all-pass effect; not the hardware's implementation |
| 9 | Stretch / Slip Roll / Roll | Absent | No capture/stretch engines |
| 9 | Mobius Saw / Tri | Absent | No Shepard generators |
| 9 | Sound Color Filter | Partial | Per-channel one-pole low/high-pass filter |
| 9 | Sound Color Crush | Partial | Crush is available as a per-deck effect, not exact bipolar Color behavior |
| 9 | Sound Color Space / Dub Echo / Pitch / Noise | Absent | No matching Color-mode implementations |
| 10 | Remaining/elapsed time | Partial | Elapsed/total display, no mode toggle |
| 10 | Ring/display brightness and color modes | Absent | Fixed app color scheme; device brightness remains OS-controlled |
| 10 | Vinyl braking adjustment | Absent | No braking ramp |
| 10 | Master mono/stereo | Implemented source | Software mono switch |
| 10 | Master/booth attenuators | Absent | Master gain only, no discrete 0/−6/−12 dB settings |
| 10 | Peak limiters | Partial | Emergency hard ceiling, not master/booth/mic limiter models |
| 10 | Recording location / mic inclusion | Absent | No recording backend |
| 10 | Demo, screensaver, power management / factory reset | Absent | No emulated hardware utilities |
| 10 | Windows ASIO / desktop setting utility | Hardware/reference | Not applicable to standalone iOS implementation |
| 11 | Idle thresholds / automatic power off | Absent | No emulated power manager |
| 11 | Talkover detection / ducking | Absent | No mic path |
| 11 | Mix-point auto-start and cancel conditions | Absent | No link scheduler |
| 11 | On-air state | Partial | Displayed from kernel play state; no hardware illumination |
| 11 | Hardware unlock/license events | Hardware/reference | No vendor unlock or license bypass |
| 12 | Loading, playback, cue, looping workflows | Partial | Native local equivalents described in README |
| 12 | Two computers B2B, external input, DMX | Absent | No audio-host switching or lighting backend |
| 12 | Custom DJ logo transfer | Absent | No hardware image-transfer protocol |
| 12 | Recording | Absent | No recorder |
| 13–15 | Full MIDI input/pads/control mapping | Reference only | Complete source tables retained; no CoreMIDI adapter implemented |
| 16 | Jog display / LED / meter MIDI output | Reference only | No outbound MIDI transport |
| 17 | Signal flow | Partial | PCM → rate/reverse/loop → trim/EQ/filter → cue tap → channel fader/crossfader → FX → master; differs from hardware |
| 18 | Troubleshooting | Reference only | Supplied troubleshooting text retained; app errors report decode/memory/audio failures |
| 19 | Source discrepancies | Preserved | Invalid MIDI selector bytes, jog NOTE/CC ambiguity, absent key table and software differences remain unresolved |

## Work required before a complete release

1. Build and type-check the native target with Xcode, then validate the UI and lifecycle on an actual iPhone and iPad.
2. Replace full-track buffer replacement with streamed decoding and a realtime-safe, seamless load/swap architecture. Benchmark four decks, import, route changes and thermal conditions.
3. Implement and test musical transport state machines: continuous sync, all cue/loop/slip modes, scratch and jog inertia, saved loops, Mix Point Link, dual decks and fader start.
4. Add tempo/key analysis and a legally usable time-stretch/pitch engine; test transient quality, latency and CPU. A stem model and mobile inference backend are not supplied by the PDF.
5. Implement sampler, recording, remaining effects and configurable signal placement. Establish objective tests for each original DSP design; hardware sonic equivalence requires access to the hardware and measured reference captures.
6. Add CoreMIDI transport and test every mapped input/output message against hardware, resolving the PDF's explicit ambiguities. Add multichannel output, mic/external input and lighting only with verified supported devices/protocols.
7. Complete app accessibility, localization, library management, privacy review, device regression tests, signing, archive validation and distribution through the owner's Apple developer account.

No feature is made complete by its presence in this table or in the bundled reference.
