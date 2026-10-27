import AVFoundation
import Foundation

final class AudioHost {
    let kernel: OpaquePointer
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode!
    var sampleRate: Double { 44100 }
    var running: Bool { engine.isRunning }
    init() {
        guard let kernel = FLXCreate(44100) else { fatalError("Cannot allocate the audio engine") }
        self.kernel = kernel
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        source = AVAudioSourceNode(format: format) { _, _, count, list -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            guard buffers.count == 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return -50 }
            FLXRender(kernel, left, right, count)
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
    }
    deinit { engine.stop(); FLXDestroy(kernel) }
    // Only session negotiation runs on this queue; engine and PCM ownership stay
    // on the main actor so loading cannot race engine startup.
    private static let sessionQueue = DispatchQueue(label: "audio.mp.flx.session")
    @MainActor
    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Self.sessionQueue.async {
                do {
                    try Self.activateSession()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        try Task.checkCancellation()
        engine.prepare()
        try engine.start()
    }
    private static func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setPreferredSampleRate(44100)
        try session.setPreferredIOBufferDuration(0.0058)
        try session.setActive(true)
    }
    func stop() { engine.stop() }
    func set(_ deck: Int, _ parameter: FLXParameter, _ value: Double) {
        FLXSet(kernel, Int32(deck), Int32(parameter.rawValue), value)
    }
    func get(_ deck: Int, _ parameter: FLXParameter) -> Double {
        FLXGet(kernel, Int32(deck), Int32(parameter.rawValue))
    }
    func seek(_ deck: Int, _ seconds: Double) { FLXSeek(kernel, Int32(deck), seconds) }
    func position(_ deck: Int) -> Double { FLXPosition(kernel, Int32(deck)) }
    func load(_ decoded: DecodedAudio, deck: Int) throws {
        let resume = engine.isRunning
        engine.stop() // Guarantees that the render thread is not accessing the replaced PCM arrays.
        guard let channels = decoded.buffer.floatChannelData else { throw AudioFailure.unsupported }
        let right = decoded.buffer.format.channelCount > 1 ? channels[1] : channels[0]
        let success = FLXLoad(kernel, Int32(deck), channels[0], right,
                              Int64(decoded.buffer.frameLength), decoded.buffer.format.sampleRate)
        if resume { try engine.start() }
        guard success == 1 else { throw AudioFailure.memoryLimit }
    }
}

enum AudioFailure: LocalizedError {
    case unsupported, memoryLimit, tooShort
    var errorDescription: String? {
        switch self {
        case .unsupported: return "This file could not be decoded as mono or stereo audio. Use an unprotected WAV, AIFF, MP3, AAC or M4A file."
        case .memoryLimit: return "The current engine supports 128 MiB of decoded stereo audio per track and 384 MiB across all four decks. Use a shorter file."
        case .tooShort: return "The audio file contains fewer than two frames."
        }
    }
}
struct DecodedAudio: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    let waveform: [Float]
    static func read(_ url: URL) throws -> DecodedAudio {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard file.length > 1 else { throw AudioFailure.tooShort }
        guard file.processingFormat.channelCount <= 2 else { throw AudioFailure.unsupported }
        guard file.length <= 16_777_216 else { throw AudioFailure.memoryLimit }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw AudioFailure.memoryLimit
        }
        try file.read(into: buffer)
        guard buffer.frameLength > 1, let samples = buffer.floatChannelData?[0] else { throw AudioFailure.tooShort }
        let count = Int(buffer.frameLength), bins = 768
        var waveform = [Float](repeating: 0, count: bins)
        for i in 0..<bins {
            let lower = i * count / bins, upper = max(lower + 1, (i + 1) * count / bins)
            var peak: Float = 0
            for j in lower..<min(upper, count) { peak = max(peak, abs(samples[j])) }
            waveform[i] = peak
        }
        return DecodedAudio(buffer: buffer, waveform: waveform)
    }
}
