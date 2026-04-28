import AVFoundation
import UIKit
import WebKit

final class MediaViewController: UIViewController, WKScriptMessageHandler {
    private let playerView = PlayerSurfaceView()
    private let webInputStatusLabel = UILabel()
    private var player: AVPlayer?
    private var playerEndObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Media & WebKit"
        view.backgroundColor = DemoTheme.background

        let scroll = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 40, right: 20)

        let intro = makeSectionCard(
            title: "Host Screenshot Surface",
            subtitle: "Contains AVPlayerLayer, WKWebView and keyboard input to verify screenshot provider quality."
        )
        stack.addArrangedSubview(intro)

        playerView.accessibilityIdentifier = DemoID.mediaPlayer
        playerView.backgroundColor = .black
        playerView.layer.cornerRadius = 20
        playerView.layer.masksToBounds = true
        playerView.heightAnchor.constraint(equalToConstant: 190).isActive = true
        stack.addArrangedSubview(playerView)

        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController.add(WeakScriptMessageHandler(target: self), name: "viewglassDemo")
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.accessibilityIdentifier = DemoID.mediaWebView
        webView.layer.cornerRadius = 20
        webView.layer.masksToBounds = true
        webView.heightAnchor.constraint(equalToConstant: 280).isActive = true
        webView.loadHTMLString(Self.webHTML, baseURL: nil)
        stack.addArrangedSubview(webView)

        webInputStatusLabel.accessibilityIdentifier = DemoID.mediaWebInputStatus
        webInputStatusLabel.text = "Web editor: empty"
        webInputStatusLabel.textColor = DemoTheme.ink
        webInputStatusLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        webInputStatusLabel.numberOfLines = 0
        stack.addArrangedSubview(webInputStatusLabel.embedInRoundedSurface())

        let field = UITextField()
        field.accessibilityIdentifier = DemoID.mediaKeyboardField
        field.placeholder = "Tap to show keyboard"
        field.borderStyle = .roundedRect
        field.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        field.heightAnchor.constraint(equalToConstant: 52).isActive = true
        stack.addArrangedSubview(field.embedInRoundedSurface())

        scroll.addSubview(stack)
        view.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])

        configurePlayer()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player?.play()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        player?.pause()
    }

    private func configurePlayer() {
        guard let url = Self.makeDemoVideoURL() else {
            return
        }
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .none
        playerEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
        self.player = player
        playerView.playerLayer.player = player
        playerView.playerLayer.videoGravity = .resizeAspectFill
    }

    deinit {
        if let playerEndObserver {
            NotificationCenter.default.removeObserver(playerEndObserver)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "viewglassDemo" else {
            return
        }
        let text = (message.body as? String) ?? ""
        webInputStatusLabel.text = text.isEmpty ? "Web editor: empty" : "Web editor: \(text.count) chars"
    }

    private static let webHTML = """
    <!doctype html>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
      body { margin: 0; font: 700 22px -apple-system; background: #07111f; color: white; }
      .hero { min-height: 132px; display: grid; place-items: center; background:
        radial-gradient(circle at 20% 20%, #34d399, transparent 30%),
        linear-gradient(135deg, #2563eb, #f97316); }
      .pill { padding: 18px 22px; border-radius: 999px; background: rgba(255,255,255,.22); }
      .editor { min-height: 98px; margin: 14px; padding: 16px; border-radius: 18px;
        outline: 2px solid rgba(255,255,255,.32); background: rgba(255,255,255,.12);
        font: 600 18px -apple-system; line-height: 1.35; }
      .editor:empty:before { content: attr(data-placeholder); color: rgba(255,255,255,.6); }
    </style>
    <div class="hero"><div class="pill">WKWebView Rendered Content</div></div>
    <div id="editor" class="editor" contenteditable="true" role="textbox" data-placeholder="Write into this WK editor"></div>
    <script>
      const editor = document.getElementById('editor');
      function notify() {
        window.webkit?.messageHandlers?.viewglassDemo?.postMessage(editor.innerText || editor.textContent || '');
      }
      editor.addEventListener('input', notify);
      editor.addEventListener('change', notify);
    </script>
    """

    private static func makeDemoVideoURL() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("viewglass-demo-player.mp4")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let width = 640
            let height = 360
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ])
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height
                ]
            )
            guard writer.canAdd(input) else {
                return nil
            }
            writer.add(input)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            for frame in 0..<90 {
                while !input.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.005)
                }
                guard let buffer = makePixelBuffer(width: width, height: height, frame: frame) else {
                    continue
                }
                adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
            }

            input.markAsFinished()
            let semaphore = DispatchSemaphore(value: 0)
            writer.finishWriting {
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 5)
            return writer.status == .completed ? url : nil
        } catch {
            return nil
        }
    }

    private static func makePixelBuffer(width: Int, height: Int, frame: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            nil,
            &buffer
        )
        guard let buffer else {
            return nil
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.setFillColor(UIColor(red: 0.04, green: 0.07, blue: 0.14, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(UIColor(red: 0.14, green: 0.45, blue: 0.95, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        context.setFillColor(UIColor(red: 0.98, green: 0.42, blue: 0.18, alpha: 1).cgColor)
        let x = CGFloat((frame * 9) % width)
        context.fill(CGRect(x: x, y: 72, width: 140, height: 140))
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 40, y: 260, width: 360, height: 18))
        return buffer
    }
}

private final class PlayerSurfaceView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
