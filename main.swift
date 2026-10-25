import AppKit
import Carbon.HIToolbox
import ServiceManagement

// MARK: - Storage

enum NoteStore {
    static let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ForeverNote", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("note.txt")
    }()

    static func load() -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    static func save(_ text: String) {
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Editor

final class NoteTextView: NSTextView {
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

final class NoteViewController: NSViewController, NSTextViewDelegate {
    let textView: NoteTextView = {
        // Build the TextKit 1 stack by hand so our layout manager can draw code/quote backgrounds.
        let storage = NSTextStorage()
        let layout = NoteLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        return NoteTextView(frame: .zero, textContainer: container)
    }()
    private let markdown = MarkdownStyler()
    private var saveWork: DispatchWorkItem?

    override func loadView() {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 380))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        textView.frame = scroll.contentView.bounds
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 12, height: 14)
        textView.insertionPointColor = .controlAccentColor
        textView.typingAttributes = [.font: MarkdownStyler.bodyFont, .foregroundColor: NSColor.labelColor,
                                     .paragraphStyle: MarkdownStyler.paragraph]
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.font = MarkdownStyler.bodyFont
        textView.linkTextAttributes = [.foregroundColor: NSColor.controlAccentColor, .cursor: NSCursor.pointingHand]
        textView.drawsBackground = false
        // Notes are often IDs / codes / passwords: keep what's typed verbatim.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textStorage?.delegate = markdown
        textView.string = NoteStore.load()
        textView.delegate = self

        scroll.documentView = textView
        view = scroll
    }

    func textDidChange(_ notification: Notification) {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        saveWork = nil
        NoteStore.save(textView.string)
    }
}

// MARK: - Global hotkey (Carbon: no Accessibility permission needed)

final class HotKey {
    private var ref: EventHotKeyRef?
    private static var handler: (() -> Void)?

    init?(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        HotKey.handler = handler
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.handler?() }
            return noErr
        }, 1, &spec, nil, nil)

        let id = EventHotKeyID(signature: OSType(0x464E4F54) /* 'FNOT' */, id: 1)
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id,
                                         GetApplicationEventTarget(), 0, &ref)
        if status != noErr { return nil }
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let noteVC = NoteViewController()
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Forever Note")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.contentViewController = noteVC
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        noteVC.textView.onEscape = { [weak self] in self?.popover.performClose(nil) }

        hotKey = HotKey(keyCode: kVK_ANSI_E, modifiers: cmdKey) { [weak self] in self?.toggle() }
        if hotKey == nil {
            NSLog("ForeverNote: Cmd+E is already taken by another app")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        noteVC.saveNow()
    }

    func popoverDidClose(_ notification: Notification) {
        noteVC.saveNow()
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            toggle()
        }
    }

    private func toggle() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            frostPopoverBackground()
            popover.contentViewController?.view.window?.makeKey()
            popover.contentViewController?.view.window?.makeFirstResponder(noteVC.textView)
        }
    }

    // The popover's Liquid Glass background is very see-through; tint it so text reads crisply.
    private func frostPopoverBackground() {
        guard #available(macOS 26, *),
              let frame = noteVC.view.window?.contentView?.superview,
              let glass = frame.subviews.compactMap({ $0 as? NSGlassEffectView }).first else { return }
        glass.tintColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.13, alpha: 0.85) : NSColor(white: 1, alpha: 0.85)
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Forever Note", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("ForeverNote: launch at login failed: \(error)")
        }
    }

    // Menu-bar-only apps have no main menu, so Cmd+C/V/X/A/Z wouldn't work without this.
    private func installEditMenu() {
        let main = NSMenu()
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Find…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
            .tag = Int(NSTextFinder.Action.showFindInterface.rawValue)
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
