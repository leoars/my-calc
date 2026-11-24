import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var controller: MainWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The Dock shows the free-form icon itself, without the grey plate macOS adds to it.
        if let url = Bundle.main.url(forResource: "MyCalc", withExtension: "icns"), let icon = NSImage(contentsOf: url) {
            let view = NSImageView(image: icon)
            view.imageScaling = .scaleProportionallyUpOrDown
            NSApp.dockTile.contentView = view
            NSApp.dockTile.display()
        }
        controller = MainWindowController()
        NSApp.mainMenu = makeMainMenu()
        controller.window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updater.startAutomatically()
    }

    /// Updates from the GitHub releases.
    lazy var updater: PackageUpdater = {
        let updater = PackageUpdater(appName: "My Calc", repository: "leoars/my-calc", prefix: "My-Calc") { [weak self] in
            self?.controller?.window
        }
        updater.preferences = UpdatePreferences(defaults: AppSettings.defaults)
        // Settings follows the check while it is open.
        updater.changed = { [weak self] in self?.controller?.settingsWindow?.sync() }
        return updater
    }()

    @objc func checkForUpdates(_ sender: Any?) { updater.checkNow() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let app = NSMenu()
        app.addItem(withTitle: L("menu.about"), action: #selector(MainWindowController.showAboutPanel(_:)), keyEquivalent: "").target = controller
        app.addItem(.separator())
        app.addItem(withTitle: L("menu.settings"), action: #selector(MainWindowController.openAppSettings(_:)), keyEquivalent: ",").target = controller
        if PackageUpdater.isAvailable {
            app.addItem(withTitle: L("updates.check"), action: #selector(checkForUpdates(_:)), keyEquivalent: "").target = self
        }
        app.addItem(.separator())
        app.addItem(withTitle: L("menu.hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = app.addItem(withTitle: L("menu.hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: L("menu.showAll"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        add(app, titled: "My Calc", to: main)

        // The commands of the window answer from the window, whatever has the keyboard.
        for menu in [controller.makeEditMenu(), controller.makeViewMenu()] {
            for item in menu.items { target(item) }
            add(menu, titled: menu.title, to: main)
        }

        // Window and Help close the bar, as in every Mac application and in the rest of the suite.
        let windowMenu = NSMenu(title: L("menu.window"))
        windowMenu.addItem(withTitle: L("menu.minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        add(windowMenu, titled: windowMenu.title, to: main)
        NSApp.windowsMenu = windowMenu
        let helpMenu = NSMenu(title: L("menu.help"))
        helpMenu.addItem(withTitle: L("menu.helpReadme"), action: #selector(openHelp(_:)), keyEquivalent: "").target = self
        helpMenu.addItem(withTitle: L("about.issues"), action: #selector(reportIssue(_:)), keyEquivalent: "").target = self
        helpMenu.addItem(.separator())
        helpMenu.addItem(withTitle: L("menu.about"), action: #selector(MainWindowController.showAboutPanel(_:)), keyEquivalent: "").target = controller
        add(helpMenu, titled: helpMenu.title, to: main)
        NSApp.helpMenu = helpMenu
        return main
    }

    private func target(_ item: NSMenuItem) {
        if item.action != nil { item.target = controller }
        item.submenu?.items.forEach(target)
    }

    /// The README of the repository, in the language the application is running in.
    @objc func openHelp(_ sender: Any?) {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        let page = language == "pt-BR" ? "" : "/blob/main/docs/readme/\(language).md"
        if let url = URL(string: "https://github.com/leoars/my-calc" + page) { NSWorkspace.shared.open(url) }
    }

    @objc func reportIssue(_ sender: Any?) {
        if let url = URL(string: "https://github.com/leoars/my-calc/issues") { NSWorkspace.shared.open(url) }
    }

    private func add(_ menu: NSMenu, titled title: String, to main: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        main.addItem(item)
    }
}
