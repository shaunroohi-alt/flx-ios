import SwiftUI
import UniformTypeIdentifiers

private let cyan = Color(red: 0.20, green: 0.85, blue: 0.91)
private let panel = Color(red: 0.065, green: 0.075, blue: 0.09)

struct ConsoleView: View {
    @EnvironmentObject var session: DJSession
    @State private var left = 0
    @State private var right = 1
    @State private var loadDeck = 0
    @State private var showImporter = false
    @State private var showLibrary = false
    @State private var importAfterDismiss = false
    @State private var showSettings = false
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 14) {
                    HStack(alignment: .center) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("FLX").font(.system(size: 36, weight: .black, design: .rounded)).italic()
                            Text("BY MP-AUDIO").font(.caption.weight(.bold)).tracking(2).foregroundStyle(cyan)
                        }
                        Spacer()
                        if session.loading { ProgressView() }
                        Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3").font(.title2) }.accessibilityLabel("Settings and feature status")
                        Button("STOP") { session.pauseAll() }.tint(.orange)
                    }
                    HStack {
                        Circle().fill(session.decks.contains(where: { $0.playing }) ? cyan : .gray).frame(width: 6, height: 6)
                        Text(session.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        Spacer()
                        Text("NATIVE DEVELOPMENT BUILD").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                    }
                    if geometry.size.width > 850 {
                        HStack(alignment: .top, spacing: 12) {
                            deckGroup($left, indices: [0,2]).frame(maxWidth: .infinity)
                            mixer.frame(width: min(360,geometry.size.width*0.3))
                            deckGroup($right, indices: [1,3]).frame(maxWidth: .infinity)
                        }
                    } else {
                        deckGroup($left, indices: [0,1,2,3])
                        mixer
                    }
                    HStack {
                        Text("A").foregroundStyle(cyan)
                        Slider(value: $session.crossfader, in: 0...1).accessibilityLabel("Crossfader")
                        Text("B").foregroundStyle(.orange)
                    }.padding().background(panel, in: RoundedRectangle(cornerRadius: 12))
                    Text("Offline audio • 4 decks • Files import • No account required")
                        .font(.caption2).foregroundStyle(.secondary)
                }.padding(16)
            }.background(Color(red: 0.025, green: 0.03, blue: 0.04))
        }
        .tint(cyan)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url): Task { await session.importFile(url, deck: loadDeck) }
            case .failure(let error): session.error = error.localizedDescription
            }
        }
        .sheet(isPresented: $showLibrary, onDismiss: {
            if importAfterDismiss { importAfterDismiss = false; showImporter = true }
        }) { librarySheet }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .alert("FLX", isPresented: Binding(get: { session.error != nil }, set: { if !$0 {session.error = nil} })) {
            Button("OK") { session.error = nil }
        } message: { Text(session.error ?? "") }
    }
    func deckGroup(_ selection: Binding<Int>, indices: [Int]) -> some View {
        VStack(spacing: 10) {
            Picker("Deck", selection: selection) { ForEach(indices,id: \.self) { n in Text("DECK \(n+1)").tag(n) } }.pickerStyle(.segmented)
            DeckView(number: selection.wrappedValue) {
                loadDeck = selection.wrappedValue; showLibrary = true
            }
        }
    }
    var mixer: some View {
        VStack(spacing: 14) {
            Text("4-CHANNEL MIXER").font(.caption.weight(.bold)).tracking(2)
            HStack(alignment: .top, spacing: 8) {
                ForEach([2,0,1,3],id: \.self) { n in ChannelStrip(number: n) }
            }
            Divider()
            LabeledSlider(name: "MASTER", value: $session.master, range: 0...1)
            Toggle("Split cue output", isOn: $session.splitCue).font(.caption)
            if session.splitCue {
                Text("Cue = LEFT • Master = RIGHT. Use a DJ split cable; both outputs are mono.")
                    .font(.caption2).foregroundStyle(.orange)
                LabeledSlider(name: "CUE / MASTER", value: $session.cueMix, range: 0...1)
                LabeledSlider(name: "CUE LEVEL", value: $session.cueLevel, range: 0...1)
            }
        }.padding(12).background(panel, in: RoundedRectangle(cornerRadius: 14))
    }
    var librarySheet: some View {
        NavigationStack {
            List {
                Section {
                    Button("Import audio from Files") { importAfterDismiss = true; showLibrary = false }
                    Text("Loading replaces Deck \(loadDeck+1). Decoding runs in the background; installing audio briefly stops the output engine. Do not load during a live performance in this development build.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("LOCAL LIBRARY") {
                    ForEach(session.library) { track in
                        Button {
                            showLibrary = false; Task { await session.loadTrack(track, deck: loadDeck) }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(track.title)
                                Text("\(track.bpm, specifier: "%.1f") BPM · manual grid").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if session.library.isEmpty { Text("Import a local audio file to begin.").foregroundStyle(.secondary) }
                }
            }.navigationTitle("Load Deck \(loadDeck+1)")
                .toolbar { Button("Close") { showLibrary = false } }
        }
    }
}

struct DeckView: View {
    @EnvironmentObject var session: DJSession
    let number: Int
    let load: () -> Void
    @State private var clearPads = false
    @State private var jogOrigin: Double?
    var d: DeckState { session.decks[number] }
    var accent: Color { number % 2 == 0 ? cyan : .orange }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(d.track?.title ?? "NO TRACK LOADED").font(.headline).lineLimit(1)
                    Text(d.track == nil ? "Import audio to this deck" : "\(d.bpm*d.rate, specifier: "%.2f") BPM · \((d.rate-1)*100, specifier: "%+.1f") %")
                        .font(.system(.caption,design: .monospaced)).foregroundStyle(accent)
                }
                Spacer(); Button(action: load) { Image(systemName: "folder.badge.plus") }.disabled(session.loading)
            }
            WaveformView(samples: d.waveform, progress: d.duration > 0 ? d.position/d.duration : 0, color: accent)
                .frame(height: 58).overlay(alignment: .bottomTrailing) {
                    Text("\(time(d.position)) / \(time(d.duration))").font(.system(size: 10,design: .monospaced)).padding(3).background(.black.opacity(0.7))
                }
            Slider(value: Binding(get: { min(d.position,max(d.duration,1)) }, set: { session.seek(number,$0) }), in: 0...max(d.duration,1))
                .accessibilityLabel("Track position").disabled(d.track == nil)
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(RadialGradient(colors: [Color(white: 0.18), .black],center: .center,startRadius: 20,endRadius: 110))
                    Circle().stroke(Color(white: 0.2),lineWidth: 12).padding(8)
                    Circle().trim(from: 0,to: d.duration > 0 ? min(1,max(0,d.position/d.duration)) : 0).stroke(accent,lineWidth: 3).padding(5).rotationEffect(.degrees(-90))
                    VStack(spacing: 5) {
                        Text("\(number+1)").font(.system(size: 30,weight: .black,design: .rounded))
                        Text(time(d.position)).font(.system(.caption,design: .monospaced))
                        Text(d.looping ? "LOOP" : (d.playing ? "ON AIR" : "PAUSED")).font(.system(size: 9,weight: .bold)).foregroundStyle(accent)
                        Text("DRAG TO SEEK").font(.system(size: 7)).foregroundStyle(.secondary)
                    }
                }.frame(width: 150,height: 150)
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        if jogOrigin == nil { jogOrigin = session.audio.position(number); session.beginSlip(number) }
                        session.seek(number,(jogOrigin ?? 0)+Double(value.translation.width)*0.025)
                    }.onEnded { _ in jogOrigin = nil; session.endSlip(number) })
                    .accessibilityLabel("Jog seek, deck \(number+1)")
                    .accessibilityAdjustableAction { dir in session.jump(number,dir == .increment ? 1 : -1) }
                VStack(spacing: 10) {
                    Button("SYNC") { session.sync(number) }
                    Button("MASTER") { session.selectedMaster = number }.tint(session.selectedMaster == number ? accent : .gray)
                    Button("REVERSE") { session.reverse(number) }.tint(d.reverse ? .red : .gray)
                    Toggle("QUANTIZE",isOn: $session.decks[number].quantize).font(.system(size: 9,weight: .bold))
                    Toggle("SLIP",isOn: $session.decks[number].slip).font(.system(size: 9,weight: .bold))
                }.buttonStyle(.bordered)
            }
            HStack {
                Button("CUE") { session.cue(number) }.tint(.orange)
                Button { session.play(number) } label: { Label(d.playing ? "PAUSE" : "PLAY",systemImage: d.playing ? "pause.fill" : "play.fill") }.tint(accent)
                Spacer()
                Button("−4") { session.jump(number,-4) }; Button("+4") { session.jump(number,4) }
            }.buttonStyle(.borderedProminent).controlSize(.regular)
            HStack {
                Text("TEMPO").font(.caption2)
                Slider(value: Binding(get: { min(1+d.tempoRange,max(1-d.tempoRange,d.rate)) },set: { session.setRate(number,$0) }),in: max(0.01,1-d.tempoRange)...(1+d.tempoRange))
                Button("RESET") { session.setRate(number,1) }.font(.caption2)
            }
            HStack {
                Picker("Range",selection: $session.decks[number].tempoRange) {
                    Text("±6%").tag(0.06); Text("±10%").tag(0.10); Text("±16%").tag(0.16); Text("WIDE").tag(1.0)
                }.labelsHidden()
                TextField("BPM",value: Binding(get: { d.bpm },set: {session.setBPM(number,$0)}),format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad).textFieldStyle(.roundedBorder).frame(width: 70).accessibilityLabel("Manual BPM")
                Button("TAP") { session.tap(number) }
                Button("GRID 0") { session.decks[number].grid = session.audio.position(number); session.remember(number) }
            }.font(.caption2)
            HStack {
                Button("IN / ½") { session.loopIn(number) }
                Button("OUT / 2×") { session.loopOut(number) }
                Button(d.looping ? "EXIT LOOP" : "4 BEAT LOOP") { session.loop(number) }.tint(d.looping ? accent : .gray)
            }.buttonStyle(.bordered).font(.caption2)
            Picker("Pad mode",selection: $session.decks[number].mode) {
                ForEach(PadMode.allCases,id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            HStack {
                Button("PAGE \(d.page+1)") { session.decks[number].page = 1-d.page }
                Spacer()
                Toggle("DELETE CUE",isOn: $clearPads).toggleStyle(.button).tint(.red).disabled(d.mode != .cue)
            }.font(.caption2)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(),spacing: 6),count: 4),spacing: 6) {
                ForEach(0..<8,id: \.self) { p in
                    Button { session.pad(number,p,clear: clearPads) } label: {
                        Text(padLabel(p)).font(.system(size: 12,weight: .bold,design: .monospaced))
                            .frame(maxWidth: .infinity,minHeight: 43)
                            .background(accent.opacity(d.mode == .cue && d.cues[p+d.page*8] == nil ? 0.10 : 0.30),in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(0.5)))
                    }.buttonStyle(.plain)
                }
            }
            Divider()
            HStack {
                Picker("Beat effect",selection: Binding(get: { d.fx },set: {session.decks[number].fx = $0; session.mix(number,FLXEffect,Double($0))})) {
                    ForEach(Array(["OFF","ECHO","LOW CUT ECHO","FLANGER","TRANS","REVERB","PHASER","CRUSH"].enumerated()),id: \.offset) { i,name in Text(name).tag(i) }
                }.labelsHidden()
                Picker("FX beats",selection: Binding(get: { d.beats },set: {session.decks[number].beats = $0;session.mix(number,FLXBeats,$0)})) {
                    ForEach([0.0625,0.125,0.25,0.5,1,2,4,8,16],id: \.self) { Text("\($0, specifier: "%g") beat").tag($0) }
                }.labelsHidden()
            }
            LabeledSlider(name: "FX DEPTH",value: Binding(get: {d.depth},set: {session.decks[number].depth = $0;session.mix(number,FLXDepth,$0)}),range: 0...1)
        }.padding(14).background(panel,in: RoundedRectangle(cornerRadius: 14)).tint(accent)
    }
    func padLabel(_ p: Int) -> String {
        switch d.mode {
        case .cue: return String(UnicodeScalar(65+p+d.page*8)!)
        case .jump: return String(format: "%+d",[-1,1,-2,2,-4,4,-8,8][p]*(d.page == 1 ? 16 : 1))
        case .loop: return String(format: "%g",pow(2,Double(p-6+d.page*8)))
        }
    }
    func time(_ seconds: Double) -> String { let s = max(0,Int(seconds));return String(format: "%02d:%02d",s/60,s%60) }
}

struct ChannelStrip: View {
    @EnvironmentObject var session: DJSession
    let number: Int
    var body: some View {
        VStack(spacing: 8) {
            Text("\(number+1)").font(.headline).foregroundStyle(number % 2 == 0 ? cyan : .orange)
            ProgressView(value: Double(min(1,session.decks[number].meter))).tint(session.decks[number].meter > 0.9 ? .red : cyan)
            Text("TRIM").font(.system(size: 8))
            Slider(value: Binding(get: {session.decks[number].trim},set: {session.decks[number].trim = $0;session.mix(number,FLXGain,$0)}),in: 0...2).accessibilityLabel("Deck \(number+1) trim")
            ForEach([2,1,0],id: \.self) { band in
                Text(["LOW","MID","HI"][band]).font(.system(size: 8))
                Slider(value: Binding(get: {session.decks[number].eq[band]},set: {
                    session.decks[number].eq[band] = $0
                    session.mix(number,[FLXLow,FLXMid,FLXHigh][band],$0)
                }),in: -26...6).accessibilityLabel("Deck \(number+1) \(["low","mid","high"][band]) EQ")
                    .onTapGesture(count: 2) { session.decks[number].eq[band] = 0;session.mix(number,[FLXLow,FLXMid,FLXHigh][band],0) }
            }
            Text("FILTER").font(.system(size: 8))
            Slider(value: Binding(get: {session.decks[number].color},set: {session.decks[number].color = $0;session.mix(number,FLXColor,$0)}),in: -1...1).accessibilityLabel("Deck \(number+1) filter")
                .onTapGesture(count: 2) {session.decks[number].color = 0;session.mix(number,FLXColor,0)}
            Button("CUE") { session.decks[number].monitor.toggle();session.mix(number,FLXCue,session.decks[number].monitor ? 1 : 0) }
                .font(.caption2).buttonStyle(.bordered).tint(session.decks[number].monitor ? .orange : .gray)
            Text("FADER").font(.system(size: 8))
            Slider(value: Binding(get: {session.decks[number].fader},set: {session.decks[number].fader = $0;session.mix(number,FLXFader,$0)}),in: 0...1).accessibilityLabel("Deck \(number+1) volume")
            Picker("Assign",selection: Binding(get: {session.decks[number].assign},set: {session.decks[number].assign = $0;session.mix(number,FLXAssign,Double($0))})) {
                Text("A").tag(0);Text("B").tag(1);Text("THRU").tag(2)
            }.labelsHidden().font(.caption2)
        }.frame(maxWidth: .infinity).padding(4).background(.black.opacity(0.25),in: RoundedRectangle(cornerRadius: 7))
    }
}

struct LabeledSlider: View {
    let name: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var body: some View {
        HStack { Text(name).font(.system(size: 9,weight: .bold)).frame(width: 85,alignment: .leading);Slider(value: $value,in: range).accessibilityLabel(name) }
    }
}

struct WaveformView: View {
    let samples: [Float]
    let progress: Double
    let color: Color
    var body: some View {
        Canvas { context,size in
            guard !samples.isEmpty else {return}
            var path = Path()
            for (i,value) in samples.enumerated() {
                let x = Double(i)/Double(samples.count)*size.width
                let h = max(1,Double(min(1,value))*size.height*0.46)
                path.move(to: CGPoint(x: x,y: size.height/2-h));path.addLine(to: CGPoint(x: x,y: size.height/2+h))
            }
            context.stroke(path,with: .color(color.opacity(0.75)),lineWidth: 1)
            let x = min(1,max(0,progress))*size.width
            var marker = Path();marker.move(to: CGPoint(x: x,y: 0));marker.addLine(to: CGPoint(x: x,y: size.height))
            context.stroke(marker,with: .color(.white),lineWidth: 2)
        }.background(.black.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 6)).accessibilityLabel("Track waveform")
    }
}

struct SettingsView: View {
    @EnvironmentObject var session: DJSession
    @Environment(\.dismiss) private var dismiss
    @State private var reference = ""
    var body: some View {
        NavigationStack {
            List {
                Section("OUTPUT") {
                    Toggle("Mono master",isOn: $session.mono)
                    Text("The internal renderer runs at 44.1 kHz using 32-bit floating point audio. iOS negotiates the actual device rate. No claims are made about the phone's converters, S/N, THD or output impedance.").font(.caption)
                }
                Section("IMPLEMENTED SOURCE · DEVICE VALIDATION PENDING") {
                    Text("4-deck local audio, playback/pause, cue, 16 saved hot cues, waveform, manual BPM and grid, tap tempo, one-shot grid/tempo alignment, rate control, latching reverse, beat jumps, manual/auto loops, basic slip return, 4-channel EQ/mixer, equal-power crossfader, split cue, filter and seven original DSP effects.")
                        .font(.caption)
                }
                Section("NOT IMPLEMENTED") {
                    Text("Automatic BPM/key detection, independent pitch/key lock, realtime stems, sampler, recording, true vinyl scratching, pad FX, saved Flips, dual-deck linking, Mix Point Link, full slip behavior, MIDI device integration, DMX lighting, microphone/talkover, external audio inputs, separate multichannel booth/headphone outputs, remaining proprietary effects and all hardware utility behaviors.").font(.caption)
                }
                Section("REFERENCE MEASUREMENTS") {
                    Text("DDJ-FLX10: 716 × 400.3 × 73.4 mm; 6.7 kg; 44.1 kHz; 24-bit A/D and D/A; channel EQ −26…+6 dB; mic EQ ±12 dB. These describe the reference hardware, not this app or your iPhone.").font(.caption)
                    Text("The PDF gives overall chassis dimensions, but no measured jog diameter, fader travel, button spacing or complete DSP implementation. The touch layout is adaptive rather than a claimed dimensionally exact replica.").font(.caption)
                    NavigationLink("Read full supplied reference") {
                        ScrollView([.horizontal,.vertical]) { Text(reference).font(.system(size: 11,design: .monospaced)).textSelection(.enabled).padding() }.navigationTitle("DDJ-FLX10 reference")
                    }
                }
                Section("ABOUT") {
                    Text("FLX by MP-audio · 0.1.0 development source").font(.caption)
                    Text("Independent software. Not affiliated with or endorsed by AlphaTheta, Pioneer DJ, rekordbox or Serato. No vendor software or proprietary models are included.").font(.caption)
                }
            }.navigationTitle("FLX settings").toolbar { Button("Done") { dismiss() } }
                .task { if let url = Bundle.main.url(forResource: "Reference",withExtension: "txt") { reference = (try? String(contentsOf: url,encoding: .utf8)) ?? "Reference unavailable" } }
        }
    }
}
