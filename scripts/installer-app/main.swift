// Install Circle Sans - a small native window around install-circle-sans.sh.
//
// The script does the work and stays the single source of truth; this app runs it
// off the main thread (so the cursor never spins), registers the bundled fonts for
// its own use so the window is set in Circle Sans before the font is installed,
// and shows the script's summary in the brand's colours.
//
// Test hook: `--snapshot out.png` renders the finished window to a PNG and quits,
// which lets CI and a headless session look at the result.

import AppKit
import CoreText

let green = NSColor(srgbRed: 0x22 / 255, green: 0x47 / 255, blue: 0x37 / 255, alpha: 1)
let ink = NSColor(srgbRed: 0x1a / 255, green: 0x1a / 255, blue: 0x1a / 255, alpha: 1)
let paper = NSColor.white

func resource(_ name: String) -> URL? {
    Bundle.main.resourceURL?.appendingPathComponent(name)
}

func registerBundledFonts() {
    guard let dir = resource("fonts"),
          let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    else { return }
    for url in files where url.pathExtension == "ttf" {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

/// Circle Sans at a given variable weight (100-900), falling back to the system font.
func circleSans(_ size: CGFloat, weight: CGFloat) -> NSFont {
    let wght = NSNumber(value: 0x7767_6874) // 'wght'
    let variation: [NSNumber: NSNumber] = [wght: NSNumber(value: Double(weight))]
    let descriptor = NSFontDescriptor(fontAttributes: [
        .family: "Circle Sans",
        NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
    ])
    if let font = NSFont(descriptor: descriptor, size: size), font.familyName == "Circle Sans" {
        return font
    }
    return NSFont.systemFont(ofSize: size, weight: weight >= 500 ? .semibold : .light)
}

func mono(_ size: CGFloat) -> NSFont {
    NSFont(name: "Menlo", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
}

func label(_ text: String, font: NSFont, color: NSColor, kern: CGFloat = 0, lineHeight: CGFloat? = nil) -> NSTextField {
    let paragraph = NSMutableParagraphStyle()
    if let lineHeight = lineHeight {
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
    }
    let attributed = NSAttributedString(string: text, attributes: [
        .font: font, .foregroundColor: color, .kern: kern, .paragraphStyle: paragraph,
    ])
    let field = NSTextField(labelWithAttributedString: attributed)
    field.isSelectable = false
    field.lineBreakMode = .byWordWrapping
    field.maximumNumberOfLines = 0
    field.translatesAutoresizingMaskIntoConstraints = false
    return field
}

/// The specimen's buttons: 2pt corners, tracked mono caps. Solid is white with dark
/// text, ghost is a white hairline. Drawn by hand so the shape, the hit area and the
/// focus ring are the same rectangle - a stock button only paints its small bezel.
final class BrandButton: NSButton {
    enum Style { case solid, ghost }
    private let style: Style
    private var pressed = false
    private var titleText = NSAttributedString()

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryChange)
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError() }

    func setLabel(_ text: String) {
        titleText = NSAttributedString(string: text.uppercased(), attributes: [
            .font: mono(11), .foregroundColor: style == .solid ? ink : paper, .kern: 2,
        ])
        title = text // for accessibility
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: max(120, ceil(titleText.size().width) + 44), height: 40)
    }

    private var shape: NSBezierPath { NSBezierPath(roundedRect: bounds, xRadius: 2, yRadius: 2) }

    override func draw(_ dirtyRect: NSRect) {
        switch style {
        case .solid:
            (pressed ? paper.withAlphaComponent(0.86) : paper).setFill()
            shape.fill()
        case .ghost:
            if pressed {
                paper.withAlphaComponent(0.12).setFill()
                shape.fill()
            }
            paper.withAlphaComponent(0.7).setStroke()
            let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
            outline.lineWidth = 1
            outline.stroke()
        }
        let size = titleText.size()
        // The kern trails the last glyph too, so nudge by half of it to centre the ink.
        titleText.draw(at: NSPoint(x: (bounds.width - size.width) / 2 + 1, y: (bounds.height - size.height) / 2))
    }

    override func drawFocusRingMask() { shape.fill() }
    override var focusRingMaskBounds: NSRect { bounds }

    override func mouseDown(with event: NSEvent) {
        pressed = true
        needsDisplay = true
        super.mouseDown(with: event) // tracks the press and fires the action on release
        pressed = false
        needsDisplay = true
    }
}

struct Outcome {
    let headline: String
    let body: String
    let failed: Bool
    var backupPath: String? = nil
}

let backupLead = "The version you had before was moved to:"

/// Runs the install script and reports its stdout (summary) or stderr (the reason).
func runInstaller(completion: @escaping (Outcome) -> Void) {
    guard let script = resource("install-circle-sans.sh") else {
        completion(Outcome(headline: "The installer is incomplete.", body: "The install script is missing from the app. Download it again.", failed: true))
        return
    }
    DispatchQueue.global(qos: .userInitiated).async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                completion(Outcome(headline: "The installer could not start.", body: error.localizedDescription, failed: true))
            }
            return
        }
        // Drain both pipes before waiting, or a chatty script deadlocks on a full pipe.
        let group = DispatchGroup()
        var stdout = Data(), stderr = Data()
        group.enter(); DispatchQueue.global().async { stdout = out.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.enter(); DispatchQueue.global().async { stderr = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.wait()
        process.waitUntilExit()
        let summary = String(decoding: stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let errors = String(decoding: stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let outcome: Outcome
        if process.terminationStatus == 0, !summary.isEmpty {
            var paragraphs = summary.components(separatedBy: "\n\n")
            let headline = paragraphs.removeFirst()
            // The script names the folder it set the old fonts aside in; the window
            // offers to open it instead of spelling out the path.
            var backupPath: String?
            if let index = paragraphs.firstIndex(where: { $0.hasPrefix(backupLead) }) {
                let lines = paragraphs[index].components(separatedBy: "\n")
                backupPath = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                paragraphs[index] = "The version you had before was set aside, in case you need it."
            }
            // One newline per paragraph; the paragraph spacing in the view makes the gaps.
            outcome = Outcome(headline: headline, body: paragraphs.joined(separator: "\n"), failed: false, backupPath: backupPath)
        } else {
            // The script's last stderr line is its own explanation of what went wrong.
            let reason = errors.components(separatedBy: "\n").last ?? ""
            outcome = Outcome(headline: "Circle Sans could not be installed.", body: reason.isEmpty ? "Something went wrong, and the script left no explanation." : reason, failed: true)
        }
        DispatchQueue.main.async { completion(outcome) }
    }
}

final class InstallerWindow: NSWindow {
    private let headline: NSTextField
    private let body: NSTextField
    private let spinner = NSProgressIndicator()
    private let done = BrandButton(style: .solid)
    private let reveal = BrandButton(style: .ghost)
    private var backupPath: String?

    init() {
        headline = label("Installing Circle Sans\u{2026}", font: circleSans(20, weight: 500), color: paper)
        body = label("", font: circleSans(14, weight: 380), color: paper.withAlphaComponent(0.85), lineHeight: 21)
        let size = NSSize(width: 560, height: 380)
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        title = "Install Circle Sans"
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = green
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        setContentSize(size)
        center()

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        content.wantsLayer = true
        content.layer?.backgroundColor = green.cgColor
        contentView = content
        // Constraints size the window: a fixed width, and a height that prefers
        // the design size but grows for a long message rather than clipping it.
        let width = content.widthAnchor.constraint(equalToConstant: size.width)
        let minHeight = content.heightAnchor.constraint(greaterThanOrEqualToConstant: size.height)
        let preferredHeight = content.heightAnchor.constraint(equalToConstant: size.height)
        preferredHeight.priority = .defaultLow
        NSLayoutConstraint.activate([width, minHeight, preferredHeight])
        let m: CGFloat = 40
        headline.preferredMaxLayoutWidth = size.width - 2 * m - 40
        body.preferredMaxLayoutWidth = size.width - 2 * m

        let eyebrow = label("Coffee Circle \u{00B7} Brand".uppercased(), font: mono(10), color: paper.withAlphaComponent(0.7), kern: 2)
        let wordmark = NSMutableAttributedString(string: "Circle ", attributes: [.font: circleSans(54, weight: 600), .foregroundColor: paper, .kern: -1.2])
        wordmark.append(NSAttributedString(string: "Sans", attributes: [.font: circleSans(54, weight: 200), .foregroundColor: paper, .kern: -1.2]))
        let mark = NSTextField(labelWithAttributedString: wordmark)
        mark.translatesAutoresizingMaskIntoConstraints = false

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimation(nil)

        done.setLabel("Done")
        done.keyEquivalent = "\r"
        done.target = NSApp
        done.action = #selector(NSApplication.terminate(_:))
        done.isHidden = true

        reveal.setLabel("Show previous version")
        reveal.target = self
        reveal.action = #selector(revealBackup)
        reveal.isHidden = true

        for view in [eyebrow, mark, headline, body, spinner, done, reveal] { content.addSubview(view) }
        NSLayoutConstraint.activate([
            eyebrow.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: m),
            eyebrow.topAnchor.constraint(equalTo: content.topAnchor, constant: 44),
            mark.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: m - 3),
            mark.topAnchor.constraint(equalTo: eyebrow.bottomAnchor, constant: 18),
            headline.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: m),
            headline.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -m - 40),
            headline.topAnchor.constraint(equalTo: mark.bottomAnchor, constant: 26),
            spinner.leadingAnchor.constraint(equalTo: headline.trailingAnchor, constant: 10),
            spinner.centerYAnchor.constraint(equalTo: headline.centerYAnchor),
            body.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: m),
            body.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -m),
            body.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 8),
            done.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -m),
            done.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -m + 6),
            done.topAnchor.constraint(greaterThanOrEqualTo: body.bottomAnchor, constant: 28),
            reveal.trailingAnchor.constraint(equalTo: done.leadingAnchor, constant: -10),
            reveal.centerYAnchor.constraint(equalTo: done.centerYAnchor),
        ])
        // The headline hugs its text so the spinner can sit right after it.
        headline.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    func show(_ outcome: Outcome) {
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        headline.attributedStringValue = NSAttributedString(string: outcome.headline, attributes: [
            .font: circleSans(20, weight: 500), .foregroundColor: paper,
        ])
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 21
        paragraph.maximumLineHeight = 21
        paragraph.paragraphSpacing = 10
        body.attributedStringValue = NSAttributedString(string: outcome.body, attributes: [
            .font: circleSans(14, weight: 380), .foregroundColor: paper.withAlphaComponent(0.85), .paragraphStyle: paragraph,
        ])
        done.setLabel(outcome.failed ? "Close" : "Done")
        done.isHidden = false
        backupPath = outcome.backupPath
        reveal.isHidden = outcome.backupPath == nil
    }

    @objc private func revealBackup() {
        guard let path = backupPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func snapshot(to path: String) {
        guard let view = contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: InstallerWindow?
    let snapshotPath: String?

    init(snapshotPath: String?) { self.snapshotPath = snapshotPath }

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerBundledFonts()
        let window = InstallerWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        if snapshotPath == nil { NSApp.activate(ignoringOtherApps: true) }
        runInstaller { outcome in
            window.show(outcome)
            if let path = self.snapshotPath {
                // Let the layout pass settle before reading the pixels.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    window.snapshot(to: path)
                    NSApp.terminate(nil)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let arguments = CommandLine.arguments
var snapshotPath: String?
if let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count {
    snapshotPath = arguments[index + 1]
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate(snapshotPath: snapshotPath)
app.delegate = delegate
app.run()
