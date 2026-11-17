import AppKit

extension AppDelegate {
    private func captureScreen(full: Bool, recording: Bool = false) {
        guard !capturePending, captureSession == nil, gifRecorder == nil else { return }
        // On modern macOS, ScreenCaptureKit is the authority. The legacy CG preflight can
        // report false for a replaced development build even while Settings shows it enabled.
        if #unavailable(macOS 14.0) {
            guard CGPreflightScreenCaptureAccess() else {
                _ = CGRequestScreenCaptureAccess()
                showError(L("시스템 설정 → 개인정보 보호 및 보안 → 화면 녹화에서 Promecapt를 허용해 주세요."))
                return
            }
        }
        capturePending = true
        let request = UUID()
        captureRequest = request
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self, self.capturePending, self.captureRequest == request else { return }
            self.capturePending = false
            self.captureRequest = nil
            showError(L("화면 캡처 요청이 응답하지 않았습니다. 다시 캡처를 시작해 주세요."))
            self.showDashboard()
        }
        preferences?.window?.orderOut(nil)
        let delay = Double(UserDefaults.standard.integer(forKey: DefaultsKey.captureDelay)) + 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.terminating else { return }
            ScreenSnapshots.capture { [weak self] result in
                guard let self, !self.terminating, self.captureRequest == request else { return }
                self.capturePending = false
                self.captureRequest = nil
                switch result {
                case .failure(let error):
                    showError(L("화면 캡처 실패: {0}", error.localizedDescription))
                    self.showDashboard()
                case .success(let surfaces):
                    guard !surfaces.isEmpty else { self.showDashboard(); return }
                    let session = CaptureSession()
                    let entries = self.library.entries
                    session.historyCount = entries.count
                    session.historyImage = { [weak self] index in
                        guard entries.indices.contains(index) else { return nil }
                        return self?.library.historyItem(entries[index])
                    }
                    session.recordingSelection = recording
                    session.onFinish = { [weak self] document, destination, frame, context in
                        guard let self else { return }
                        self.captureSession = nil
                        if destination == .gif { self.recordGIF(frame); return }
                        let image = document.rendered()
                        UserDefaults.standard.set(NSStringFromRect(frame), forKey: DefaultsKey.lastCaptureRect)
                        do { try self.library.add(image, context: context) }
                        catch { showError(L("캡처 기록 저장 실패: {0}", error.localizedDescription)) }
                        if UserDefaults.standard.bool(forKey: DefaultsKey.autoCopy) && destination != .copy { copyImage(image) }
                        switch destination {
                        case .copy: copyImage(image)
                        case .pin:
                            let pin = self.createPin(image)
                            pin.setDocument(document)
                            pin.window?.setFrame(frame, display: true)
                            pin.window?.makeKeyAndOrderFront(nil)
                            self.schedulePersistence()
                        case .save: saveImage(image)
                        case .gif: break
                        }
                    }
                    session.onCancel = { [weak self] in self?.captureSession = nil }
                    self.captureSession = session
                    session.start(surfaces, full: full)
                }
            }
        }
    }

    @objc func capture() { captureScreen(full: false) }
    @objc func captureFull() { captureScreen(full: true) }

    @objc func captureGIF() { captureScreen(full: false, recording: true) }
    @objc func stopGIF() { gifRecorder?.stop() }
    private func recordGIF(_ frame: NSRect) {
        let recorder = GIFRecorder(); gifRecorder = recorder
        recorder.onComplete = { [weak self, weak recorder] result in
            guard let self, let recorder else { return }
            self.gifRecorder = nil
            switch result {
            case .failure(let error): showError(L("GIF 녹화 실패: {0}", error.localizedDescription))
            case .success(let file):
                do {
                    let result = try GIFResultController(data: Data(contentsOf: file))
                    result.onPin = { [weak self] data, image in self?.createPin(image).setGIF(data) }
                    result.onClose = { [weak self] closing in self?.gifResults.removeAll { $0 === closing } }
                    self.gifResults.append(result)
                    result.show()
                } catch { showError(L("GIF 결과를 열지 못했습니다: {0}", error.localizedDescription)) }
                recorder.removeTemporaryFiles()
            }
        }
        recorder.start(rect: frame)
    }
}
