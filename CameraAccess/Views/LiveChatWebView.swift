/*
 * Live Chat Web View
 * WKWebView wrapper for WebRTC video chat
 * Streams glasses video via canvas.captureStream() override
 * Routes audio through glasses via Bluetooth (AVAudioSession)
 */

import SwiftUI
import WebKit
import AVFoundation

struct LiveChatWebView: View {
    let roomCode: String
    @ObservedObject var streamViewModel: StreamSessionViewModel
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            WebRTCWebView(roomCode: roomCode, streamViewModel: streamViewModel)
                .ignoresSafeArea()

            Button(action: { onDismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 56)
            .padding(.leading, AppSpacing.md)
        }
    }
}

// MARK: - WebRTC WKWebView

struct WebRTCWebView: UIViewRepresentable {
    let roomCode: String
    let streamViewModel: StreamSessionViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(streamViewModel: streamViewModel)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Configure audio session for Bluetooth (glasses mic + speaker)
        context.coordinator.configureAudioForGlasses()

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Inject getUserMedia override before page JS runs
        let script = WKUserScript(
            source: Self.getUserMediaOverrideJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator

        context.coordinator.webView = webView
        context.coordinator.startFrameTimer()

        let urlString = "https://app.ariaspark.com/webrtc/?a=\(roomCode)&autostart=true"
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - JavaScript Override

    /// Overrides navigator.mediaDevices.getUserMedia so that:
    /// - Video track comes from an offscreen canvas (fed with glasses frames from Swift)
    /// - Audio track comes from the glasses microphone (via Bluetooth, handled by AVAudioSession)
    static let getUserMediaOverrideJS = """
    (function() {
        var _canvas = document.createElement('canvas');
        _canvas.width = 640;
        _canvas.height = 480;
        var _ctx = _canvas.getContext('2d');
        _ctx.fillStyle = '#000';
        _ctx.fillRect(0, 0, 640, 480);
        var _stream = _canvas.captureStream(30);

        var _localStreamId = null;

        var _origGUM = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);

        navigator.mediaDevices.getUserMedia = function(constraints) {
            var needsVideo = constraints && constraints.video;
            var needsAudio = constraints && constraints.audio;

            if (needsVideo && needsAudio) {
                return _origGUM({ audio: constraints.audio }).then(function(audioStream) {
                    var combined = new MediaStream();
                    _stream.getVideoTracks().forEach(function(t) { combined.addTrack(t); });
                    audioStream.getAudioTracks().forEach(function(t) { combined.addTrack(t); });
                    _localStreamId = combined.id;
                    return combined;
                });
            } else if (needsVideo) {
                var vs = new MediaStream(_stream.getVideoTracks());
                _localStreamId = vs.id;
                return Promise.resolve(vs);
            } else {
                return _origGUM(constraints);
            }
        };

        // Auto-mute any media element that receives the local stream
        // to prevent mic audio from playing back through the phone speaker (echo)
        var _srcObjDesc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'srcObject');
        if (_srcObjDesc && _srcObjDesc.set) {
            var _origSet = _srcObjDesc.set;
            Object.defineProperty(HTMLMediaElement.prototype, 'srcObject', {
                set: function(stream) {
                    _origSet.call(this, stream);
                    if (stream && _localStreamId && stream.id === _localStreamId) {
                        this.muted = true;
                        this.volume = 0;
                    }
                },
                get: _srcObjDesc.get,
                configurable: true
            });
        }

        window.__updateGlassesFrame = function(b64) {
            var img = new Image();
            img.onload = function() {
                if (_canvas.width !== img.width || _canvas.height !== img.height) {
                    _canvas.width = img.width;
                    _canvas.height = img.height;
                }
                _ctx.drawImage(img, 0, 0);
            };
            img.src = 'data:image/jpeg;base64,' + b64;
        };
    })();
    """

    // MARK: - Coordinator

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        weak var webView: WKWebView?
        let streamViewModel: StreamSessionViewModel
        var frameTimer: Timer?
        var routeChangeObserver: NSObjectProtocol?

        init(streamViewModel: StreamSessionViewModel) {
            self.streamViewModel = streamViewModel
            super.init()

            // Monitor audio route changes — WKWebView may override our Bluetooth route
            routeChangeObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.selectBluetoothRoute()
            }
        }

        deinit {
            frameTimer?.invalidate()
            if let observer = routeChangeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        /// Route audio I/O through Bluetooth (glasses mic and speaker)
        func configureAudioForGlasses() {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.allowBluetooth]
                )
                try session.setActive(true)
                selectBluetoothRoute()
            } catch {
                print("⚠️ [LiveChat] Audio session config failed: \(error)")
            }

            // Re-apply after WKWebView has started WebRTC (it may override the route)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.selectBluetoothRoute()
            }
        }

        /// Explicitly select the Bluetooth HFP device as preferred audio input
        private func selectBluetoothRoute() {
            let session = AVAudioSession.sharedInstance()
            guard let inputs = session.availableInputs else { return }
            for input in inputs {
                if input.portType == .bluetoothHFP {
                    do {
                        try session.setPreferredInput(input)
                    } catch {
                        print("⚠️ [LiveChat] Failed to set Bluetooth input: \(error)")
                    }
                    return
                }
            }
        }

        func startFrameTimer() {
            frameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.sendFrame()
            }
        }

        private func sendFrame() {
            guard let webView = webView,
                  let frame = streamViewModel.currentVideoFrame,
                  let jpegData = frame.jpegData(compressionQuality: 0.5) else { return }

            let base64 = jpegData.base64EncodedString()
            let js = "window.__updateGlassesFrame('\(base64)');"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        // Auto-grant microphone permission for WebRTC
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.grant)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            completionHandler()
        }
    }
}
