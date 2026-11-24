import AppKit

/// My Calc ▸ Settings…: digit grouping and the updates.
final class SettingsWindow: NSObject {
    let window: NSWindow
    let groupingButton = NSButton(checkboxWithTitle: L("settings.digitGrouping"), target: nil, action: nil)
    let updatesButton = NSButton(checkboxWithTitle: L("updates.automatic"), target: nil, action: nil)
    var updates: UpdatePreferences { UpdatePreferences(defaults: AppSettings.defaults) }
    let checkNowButton = NSButton(title: L("updates.check_now"), target: nil, action: nil)
    let updateStatus = NSTextField(wrappingLabelWithString: L("updates.status.idle"))
    /// The app's updater, for Check now and the status line; none in the tests.
    var updater: PackageUpdater? { (NSApp.delegate as? AppDelegate)?.updater }
    private weak var controller: MainWindowController?

    init(controller: MainWindowController) {
        self.controller = controller
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 92), styleMask: [.titled, .closable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = L("settings.title")
        window.isReleasedWhenClosed = false
        let content = FlippedView(frame: NSRect(x: 0, y: 0, width: 380, height: 92))
        groupingButton.target = self
        groupingButton.action = #selector(toggleGrouping(_:))
        groupingButton.sizeToFit()
        groupingButton.frame.origin = NSPoint(x: 20, y: 20)
        let note = NSTextField(wrappingLabelWithString: L("settings.digitGroupingNote"))
        note.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        // As many lines as the note takes in the current language.
        let noteHeight = max(16, ceil(note.cell!.cellSize(forBounds: NSRect(x: 0, y: 0, width: 340, height: 1000)).height))
        note.frame = NSRect(x: 20, y: groupingButton.frame.maxY + 6, width: 340, height: noteHeight)
        [groupingButton, note].forEach(content.addSubview)
        var width = max(380, groupingButton.frame.maxX + 20)
        var height = note.frame.maxY + 12
        // Only a copy installed from GitHub updates itself.
        if PackageUpdater.isAvailable {
            let heading = NSTextField(labelWithString: L("updates.heading"))
            heading.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
            heading.sizeToFit()
            heading.frame.origin = NSPoint(x: 20, y: height + 6)
            updatesButton.target = self
            updatesButton.action = #selector(toggleUpdates(_:))
            updatesButton.sizeToFit()
            updatesButton.frame.origin = NSPoint(x: 20, y: heading.frame.maxY + 8)
            // The option and Check now side by side, the status below, as in My Explorer's Options.
            checkNowButton.bezelStyle = .rounded
            checkNowButton.target = self
            checkNowButton.action = #selector(checkNow(_:))
            checkNowButton.sizeToFit()
            checkNowButton.frame.origin = NSPoint(x: updatesButton.frame.maxX + 12,
                                                  y: updatesButton.frame.midY - checkNowButton.frame.height / 2)
            updateStatus.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            updateStatus.textColor = .secondaryLabelColor
            // Room for two lines: the longest states take them in some languages.
            let lineHeight = ceil(updateStatus.font!.boundingRectForFont.height)
            updateStatus.frame = NSRect(x: 20, y: max(updatesButton.frame.maxY, checkNowButton.frame.maxY) + 6,
                                        width: 340, height: 2 * lineHeight + 2)
            [heading, updatesButton, checkNowButton, updateStatus].forEach(content.addSubview)
            width = max(width, checkNowButton.frame.maxX + 20)
            updateStatus.frame.size.width = width - 40
            height = updateStatus.frame.maxY + 14
        }
        content.frame.size = NSSize(width: width, height: height)
        window.setContentSize(NSSize(width: width, height: height))
        window.contentView = content
        sync()
    }

    func sync() {
        groupingButton.state = controller?.calculator.format.grouping == true ? .on : .off
        updatesButton.state = updates.automatic ? .on : .off
        updateStatus.stringValue = L(updater?.status ?? "updates.status.idle")
        checkNowButton.isEnabled = updater?.canCheckNow ?? false
    }

    @objc func toggleGrouping(_ sender: NSButton) { controller?.setDigitGrouping(sender.state == .on) }

    @objc func checkNow(_ sender: NSButton) { updater?.checkNow() }

    @objc func toggleUpdates(_ sender: NSButton) { updates.automatic = sender.state == .on }
}
