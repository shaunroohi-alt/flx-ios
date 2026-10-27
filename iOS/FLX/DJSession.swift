import AVFoundation
import Combine
import SwiftUI

struct LibraryTrack: Identifiable, Codable {
    var id: UUID
    var title: String
    var filename: String
    var bpm: Double = 120
    var grid: Double = 0
    var cues: [Double?] = Array(repeating: nil, count: 16)
}
enum PadMode: String, CaseIterable { case cue = "HOT CUE", jump = "BEAT JUMP", loop = "BEAT LOOP" }
struct DeckState {
    var track: LibraryTrack?
    var waveform: [Float] = []
    var playing = false
    var position = 0.0
    var duration = 0.0
    var rate = 1.0
    var tempoRange = 0.16
    var bpm = 120.0
    var grid = 0.0
    var cue = 0.0
    var cues: [Double?] = Array(repeating: nil, count: 16)
    var quantize = false
    var reverse = false
    var slip = false
    var slipOrigin: Double?
    var slipTime: TimeInterval?
    var loopStart = 0.0
    var loopEnd = 0.0
    var looping = false
    var mode: PadMode = .cue
    var page = 0
    var fader = 0.8
    var trim = 1.0
    var eq = [0.0, 0.0, 0.0]
    var color = 0.0
    var monitor = false
    var assign = 2
    var meter: Float = 0
    var fx = 0
    var depth = 0.3
    var beats = 1.0
    var taps: [TimeInterval] = []
}

@MainActor
final class DJSession: ObservableObject {
    @Published var decks = Array(repeating: DeckState(), count: 4)
    @Published var library: [LibraryTrack] = []
    @Published var crossfader = 0.5 { didSet { updateMaster() } }
    @Published var master = 0.7 { didSet { updateMaster() } }
    @Published var cueMix = 0.0 { didSet { updateMaster() } }
    @Published var cueLevel = 0.7 { didSet { updateMaster() } }
    @Published var splitCue = false { didSet { updateMaster() } }
    @Published var mono = false { didSet { updateMaster() } }
    @Published var loading = false
    @Published var error: String?
    @Published var status = "Ready · import local audio"
    @Published var selectedMaster = 0
    let audio = AudioHost()
    private var audioStartTask: Task<Void, Never>?
    private var pendingPlay = Set<Int>()
    private var timer: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private let fm = FileManager.default
    var documents: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    var indexURL: URL { documents.appendingPathComponent("library.json") }

    init() {
        if let data = try? Data(contentsOf: indexURL), let tracks = try? JSONDecoder().decode([LibraryTrack].self, from: data) { library = tracks }
        startAudio()
        timer = Timer.publish(every: 1.0/30, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification, AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.pauseAll(); self?.status = "Audio route changed or interrupted · press Play to resume" }
            })
        }
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
    func updateMaster() { FLXMaster(audio.kernel, crossfader, master, splitCue ? 1 : 0, cueMix, cueLevel, mono ? 1 : 0) }
    func refresh() {
        for n in 0..<4 {
            decks[n].position = audio.position(n)
            decks[n].playing = audio.get(n, FLXPlaying) > 0
            decks[n].meter = FLXMeter(audio.kernel, Int32(n))
        }
    }
    func pauseAll() {
        audioStartTask?.cancel(); audioStartTask = nil
        pendingPlay.removeAll()
        for n in 0..<4 {
            audio.set(n, FLXPlaying, 0); decks[n].playing = false
            decks[n].slipOrigin = nil; decks[n].slipTime = nil
        }
        audio.stop()
    }
    func saveLibrary() {
        do { try JSONEncoder().encode(library).write(to: indexURL, options: .atomic) }
        catch { self.error = "Could not save library: \(error.localizedDescription)" }
    }
    func remember(_ n: Int) {
        guard let id = decks[n].track?.id, let i = library.firstIndex(where: { $0.id == id }) else { return }
        library[i].bpm = decks[n].bpm; library[i].grid = decks[n].grid; library[i].cues = decks[n].cues
        saveLibrary()
    }
    func importFile(_ url: URL, deck n: Int) async {
        guard !loading else { return }; loading = true; defer { loading = false }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let track = LibraryTrack(id: UUID(), title: url.deletingPathExtension().lastPathComponent, filename: UUID().uuidString + "." + url.pathExtension)
        let local = documents.appendingPathComponent(track.filename)
        do {
            try fm.copyItem(at: url, to: local)
            let decoded = try await Task.detached(priority: .userInitiated) { try DecodedAudio.read(local) }.value
            try install(decoded, track: track, deck: n)
            library.append(track); saveLibrary()
        } catch { try? fm.removeItem(at: local); self.error = error.localizedDescription }
    }
    func loadTrack(_ track: LibraryTrack, deck n: Int) async {
        guard !loading else { return }; loading = true; defer { loading = false }
        let url = documents.appendingPathComponent(track.filename)
        do {
            let decoded = try await Task.detached(priority: .userInitiated) { try DecodedAudio.read(url) }.value
            try install(decoded, track: track, deck: n)
        } catch { self.error = error.localizedDescription }
    }
    private func install(_ decoded: DecodedAudio, track: LibraryTrack, deck n: Int) throws {
        try audio.load(decoded, deck: n)
        var d = DeckState(); d.track = track; d.waveform = decoded.waveform
        d.duration = FLXDuration(audio.kernel, Int32(n)); d.bpm = track.bpm; d.grid = track.grid; d.cues = track.cues
        decks[n] = d
        let settings: [(FLXParameter, Double)] = [(FLXRate, 1), (FLXGain, 1), (FLXFader, 0.8), (FLXLow, 0), (FLXMid, 0), (FLXHigh, 0), (FLXColor, 0), (FLXCue, 0), (FLXAssign, 2), (FLXReverse, 0), (FLXEffect, 0), (FLXDepth, 0.3), (FLXBeats, 1), (FLXBPM, d.bpm)]
        for (parameter, value) in settings { audio.set(n, parameter, value) }
        status = "Loaded \(track.title) · set BPM or tap tempo"
    }
    func play(_ n: Int) {
        guard decks[n].track != nil else { return }
        if !audio.running {
            if pendingPlay.contains(n) { pendingPlay.remove(n) }
            else { pendingPlay.insert(n) }
            startAudio()
            return
        }
        if decks[n].position >= decks[n].duration { seek(n, 0) }
        decks[n].playing.toggle(); audio.set(n, FLXPlaying, decks[n].playing ? 1 : 0)
    }
    private func startAudio() {
        guard audioStartTask == nil else { return }
        audioStartTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await audio.start()
                let requested = pendingPlay
                pendingPlay.removeAll()
                audioStartTask = nil
                for deck in requested { play(deck) }
            } catch is CancellationError {
                // pauseAll has already cleared this request; do not restart playback.
            } catch {
                guard !Task.isCancelled else { return }
                pendingPlay.removeAll()
                audioStartTask = nil
                self.error = error.localizedDescription
            }
        }
    }
    func seek(_ n: Int, _ seconds: Double) { audio.seek(n, min(max(0, seconds), decks[n].duration)) }
    func snapped(_ n: Int, _ position: Double) -> Double {
        let d = decks[n]; guard d.quantize else { return position }
        let beat = 60/d.bpm
        return max(0, ((position-d.grid)/beat).rounded()*beat+d.grid)
    }
    func cue(_ n: Int) {
        if decks[n].playing { seek(n, decks[n].cue); audio.set(n, FLXPlaying, 0); decks[n].playing = false }
        else { decks[n].cue = snapped(n, audio.position(n)) }
    }
    func setRate(_ n: Int, _ rate: Double) { decks[n].rate = rate; audio.set(n, FLXRate, rate) }
    func setBPM(_ n: Int, _ bpm: Double) { decks[n].bpm = min(300,max(30,bpm)); audio.set(n, FLXBPM, decks[n].bpm); remember(n) }
    func tap(_ n: Int) {
        let now = ProcessInfo.processInfo.systemUptime
        if let last = decks[n].taps.last, now-last > 2 { decks[n].taps = [] }
        decks[n].taps.append(now); if decks[n].taps.count > 8 { decks[n].taps.removeFirst() }
        let taps = decks[n].taps
        if taps.count > 1 { setBPM(n, 60 * Double(taps.count-1) / (now-taps[0])) }
    }
    func sync(_ n: Int) {
        guard n != selectedMaster, decks[n].track != nil, decks[selectedMaster].track != nil else { return }
        let m = decks[selectedMaster], d = decks[n]
        let rate = min(4,max(0.01,m.bpm*m.rate/d.bpm)); setRate(n, rate)
        let masterBeat = (audio.position(selectedMaster)-m.grid)*m.bpm/60
        let ownBeat = (audio.position(n)-d.grid)*d.bpm/60
        seek(n, d.grid + (floor(ownBeat) + masterBeat-floor(masterBeat))*60/d.bpm)
        status = "Tempo/grid aligned once to Deck \(selectedMaster+1) · manual grids"
    }
    func jump(_ n: Int, _ beats: Double) { seek(n, audio.position(n)+beats*60/decks[n].bpm) }
    func beginSlip(_ n: Int) {
        guard decks[n].slip, decks[n].playing, decks[n].slipOrigin == nil else { return }
        decks[n].slipOrigin = audio.position(n); decks[n].slipTime = ProcessInfo.processInfo.systemUptime
    }
    func endSlip(_ n: Int) {
        if let origin = decks[n].slipOrigin, let time = decks[n].slipTime {
            seek(n, origin+(ProcessInfo.processInfo.systemUptime-time)*decks[n].rate)
        }
        decks[n].slipOrigin = nil; decks[n].slipTime = nil
    }
    func reverse(_ n: Int) { decks[n].reverse.toggle(); audio.set(n, FLXReverse, decks[n].reverse ? 1 : 0) }
    func loop(_ n: Int, beats: Double = 4) {
        if decks[n].looping { decks[n].looping = false; audio.set(n, FLXLoopEnabled, 0); endSlip(n); return }
        beginSlip(n); decks[n].loopStart = snapped(n, audio.position(n)); decks[n].loopEnd = min(decks[n].duration,decks[n].loopStart+beats*60/decks[n].bpm)
        commitLoop(n)
    }
    func commitLoop(_ n: Int) {
        let d = decks[n];guard d.loopEnd > d.loopStart else { return }
        audio.set(n, FLXLoopStart, d.loopStart); audio.set(n, FLXLoopEnd, d.loopEnd)
        audio.set(n, FLXLoopEnabled, 1); decks[n].looping = true
    }
    func loopIn(_ n: Int) {
        if decks[n].looping { decks[n].loopEnd = decks[n].loopStart+(decks[n].loopEnd-decks[n].loopStart)/2;commitLoop(n) }
        else { decks[n].loopStart = snapped(n,audio.position(n)) }
    }
    func loopOut(_ n: Int) {
        if decks[n].looping { decks[n].loopEnd = min(decks[n].duration,decks[n].loopStart+(decks[n].loopEnd-decks[n].loopStart)*2) }
        else { beginSlip(n); decks[n].loopEnd = snapped(n,audio.position(n)) }
        commitLoop(n)
    }
    func pad(_ n: Int, _ p: Int, clear: Bool = false) {
        guard decks[n].track != nil else { return }
        let slot = p+decks[n].page*8
        switch decks[n].mode {
        case .cue:
            if clear { decks[n].cues[slot] = nil }
            else if let cue = decks[n].cues[slot] { seek(n,cue); if !decks[n].playing {play(n)} }
            else { decks[n].cues[slot] = snapped(n,audio.position(n)) }
            remember(n)
        case .jump:
            let sizes: [Double] = [-1,1,-2,2,-4,4,-8,8]
            jump(n,sizes[p] * (decks[n].page == 1 ? 16 : 1))
        case .loop:
            let length = pow(2,Double(p-6+decks[n].page*8))
            loop(n,beats:length)
        }
    }
    func mix(_ n: Int, _ parameter: FLXParameter, _ value: Double) { audio.set(n,parameter,value) }
}
