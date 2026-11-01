import AppKit
import ScreenCaptureKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Disk-backed frames keep recording memory bounded; all calls use the recorder's serial queue.
final class GIFArchive {
    let directory: URL
    private(set) var frames: [(URL, TimeInterval)] = []
    private var bytes = 0
    private let maxFrames: Int
    init(maxFrames: Int = 300, directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("PromecaptGIF-\(UUID().uuidString)")) throws {
        self.maxFrames = max(1, maxFrames)
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    func append(_ image: CGImage, at time: TimeInterval) throws {
        guard frames.count < maxFrames, bytes < 256 * 1024 * 1024 else { return }
        let url = directory.appendingPathComponent("\(frames.count).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        bytes += (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
        frames.append((url, time))
    }
    var atLimit: Bool { frames.count >= maxFrames || bytes >= 256 * 1024 * 1024 }
    func finish(at end: TimeInterval) throws -> URL {
        guard !frames.isEmpty else { throw CocoaError(.fileReadUnknown) }
        let output = directory.appendingPathComponent("Recording.gif")
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for (index, frame) in frames.enumerated() {
            guard let source = CGImageSourceCreateWithURL(frame.0 as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw CocoaError(.fileReadCorruptFile) }
            let next = index + 1 < frames.count ? frames[index + 1].1 : end
            let delay = max(0.02, next - frame.1)
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return output
    }
    func removeTemporaryFiles() { try? FileManager.default.removeItem(at: directory) }
}

final class GIFRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    var onComplete: ((Result<URL, Error>) -> Void)?
    private let queue = DispatchQueue(label: "com.promlee.promepaste.gif", qos: .userInitiated)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var stream: SCStream?
    private var archive: GIFArchive?
    private var panel: NSPanel?
    private var regionPanel: NSPanel?
    private let options = GIFOptions.current
    private let label = NSTextField(labelWithString: L("GIF 준비 중…"))
    private var timer: Timer?
    private var started = false
    private var stopping = false
    private var done = false
    private var writing = false // queue only
    private var startTime: TimeInterval = 0
    private var startFailure: Error?

    func start(rect: NSRect) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: rect.midX, y: rect.midY)) }), screen.frame.contains(rect) else {
            complete(.failure(NSError(domain: "Promecapt", code: 1, userInfo: [NSLocalizedDescriptionKey: L("녹화 영역은 한 화면 안에 지정해 주세요.")]))); return
        }
        showControls(near: rect, screen: screen)
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self, !self.started, !self.done else { return }
            self.complete(.failure(NSError(domain: "Promecapt", code: 2, userInfo: [NSLocalizedDescriptionKey: L("녹화를 시작하지 못했습니다. 화면 캡처 권한을 확인해 주세요.")])))
        }
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { [weak self] content, error in
            DispatchQueue.main.async {
                guard let self, !self.done else { return }
                guard let content, let display = content.displays.first(where: { $0.displayID == (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value }) else {
                    self.complete(.failure(error ?? CocoaError(.fileReadUnknown))); return
                }
                do {
                    let archive = try GIFArchive(maxFrames: self.options.frameRate * self.options.duration); self.archive = archive
                    let own = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
                    let filter = SCContentFilter(display: display, excludingApplications: own, exceptingWindows: [])
                    let configuration = SCStreamConfiguration()
                    configuration.sourceRect = NSRect(x: rect.minX - screen.frame.minX, y: screen.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
                    let size = self.options.pixelSize(for: rect, scale: screen.backingScaleFactor)
                    configuration.width = Int(size.width); configuration.height = Int(size.height)
                    configuration.minimumFrameInterval = CMTime(value: 1, timescale: Int32(self.options.frameRate))
                    configuration.queueDepth = 3; configuration.showsCursor = self.options.showsCursor
                    configuration.pixelFormat = kCVPixelFormatType_32BGRA
                    configuration.capturesAudio = false
                    let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
                    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: self.queue)
                    self.stream = stream
                    self.startTime = Date.timeIntervalSinceReferenceDate
                    self.queue.sync { self.writing = true }
                    stream.startCapture { [weak self] error in
                        DispatchQueue.main.async {
                            guard let self else { return }
                            if self.done { stream.stopCapture(completionHandler: nil); return }
                            if let error { self.complete(.failure(error)); return }
                            self.started = true; self.label.stringValue = L("● GIF 녹화 중 · 0 / {0}초", self.options.duration)
                            self.timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                                guard let self else { return }
                                let elapsed = Date.timeIntervalSinceReferenceDate - self.startTime
                                self.label.stringValue = L("● GIF 녹화 중 · {0} / {1}초", Int(elapsed), self.options.duration)
                                if elapsed >= Double(self.options.duration) { self.stop() }
                            }
                        }
                    }
                } catch { self.complete(.failure(error)) }
            }
        }
    }
    private func showControls(near rect: NSRect, screen: NSScreen) {
        let regionPanel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        regionPanel.isReleasedWhenClosed = false; regionPanel.hidesOnDeactivate = false
        regionPanel.isOpaque = false; regionPanel.backgroundColor = .clear; regionPanel.ignoresMouseEvents = true
        regionPanel.level = .statusBar; regionPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        regionPanel.title = L("Promecapt · GIF 녹화 영역")
        regionPanel.contentView = GIFRecordingRegion(frame: NSRect(origin: .zero, size: screen.frame.size),
            region: rect.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY))
        regionPanel.orderFrontRegardless(); self.regionPanel = regionPanel
        let panel = NSPanel(contentRect: NSRect(x: max(screen.frame.minX + 10, min(rect.minX, screen.frame.maxX - 350)), y: max(screen.frame.minY + 10, rect.minY - 70), width: 340, height: 56), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = L("Promecapt GIF · {0}fps · 최대 {1}초", options.frameRate, options.duration)
        panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false; panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        label.frame = NSRect(x: 12, y: 18, width: 235, height: 20)
        let stop = NSButton(title: L("정지"), target: self, action: #selector(stopRecording))
        stop.frame = NSRect(x: 255, y: 12, width: 75, height: 30)
        panel.contentView?.addSubview(label); panel.contentView?.addSubview(stop)
        panel.orderFrontRegardless(); self.panel = panel
    }
    @objc private func stopRecording() { stop() }
    func stop() {
        guard !done, !stopping else { return }
        guard started else { complete(.failure(CocoaError(.userCancelled))); return }
        stopping = true; timer?.invalidate(); timer = nil
        label.stringValue = L("GIF 파일 작성 중…")
        regionPanel?.close(); regionPanel = nil
        let end = Date.timeIntervalSinceReferenceDate - startTime
        stream?.stopCapture { [weak self] error in
            guard let self else { return }
            self.queue.async {
                self.writing = false
                let result: Result<URL, Error>
                do {
                    if let failure = self.startFailure ?? error { throw failure }
                    guard let archive = self.archive else { throw CocoaError(.fileReadUnknown) }
                    result = .success(try archive.finish(at: end))
                } catch { result = .failure(error) }
                DispatchQueue.main.async { self.complete(result) }
            }
        }
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard writing, type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int, status == SCFrameStatus.complete.rawValue,
              let buffer = sampleBuffer.imageBuffer else { return }
        let image = CIImage(cvPixelBuffer: buffer)
        guard let cg = context.createCGImage(image, from: image.extent) else { return }
        do { try archive?.append(cg, at: Date.timeIntervalSinceReferenceDate - startTime) }
        catch { startFailure = error; writing = false; DispatchQueue.main.async { self.stop() }; return }
        if archive?.atLimit == true { writing = false; DispatchQueue.main.async { self.stop() } }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) { DispatchQueue.main.async { self.complete(.failure(error)) } }
    private func complete(_ result: Result<URL, Error>) {
        guard !done else { return }; done = true
        timer?.invalidate(); timer = nil; panel?.close(); panel = nil; regionPanel?.close(); regionPanel = nil
        queue.async { self.writing = false }
        onComplete?(result)
        if case .failure = result { stream?.stopCapture(completionHandler: nil); queue.async { self.archive?.removeTemporaryFiles() } }
    }
    func removeTemporaryFiles() { queue.async { self.archive?.removeTemporaryFiles() } }
}
