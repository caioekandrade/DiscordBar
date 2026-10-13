import AppKit
import ApplicationServices
import ServiceManagement

private let discordID = "com.hnc.Discord"

enum BadgeState: Equatable {
    case permissionRequired, unavailable, notRunning, noBadge, unread(String)

    var explanation: String {
        switch self {
        case .permissionRequired: return "Permita o acesso em Acessibilidade"
        case .unavailable: return "Indicador do Dock indisponível"
        case .notRunning: return "Discord fechado"
        case .noBadge: return "Nenhuma notificação no Dock"
        case .unread(let value):
            if Int(value) != nil { return "Notificações no Dock: \(value)" }
            return "Há notificações no Discord"
        }
    }
}

/// Reads only the Discord Dock item's badge. No Discord account or network access.
final class DockBadgeReader {
    private var cachedDockPID: pid_t?
    private var cachedItem: AXUIElement?

    private func attribute(_ element: AXUIElement, _ name: String) -> (AXError, CFTypeRef?) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return (error, value)
    }

    private func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name).1 as? String
    }

    private func matchesDiscord(_ element: AXUIElement, appURL: URL) -> Bool {
        let (_, rawURL) = attribute(element, "AXURL")
        if let url = rawURL as? URL {
            return url.standardizedFileURL == appURL.standardizedFileURL
        }
        // The Dock doesn't expose AXURL on every macOS version.
        return string(element, "AXRole") == "AXDockItem"
            && string(element, "AXTitle") == appURL.deletingPathExtension().lastPathComponent
    }

    private func findItem(in root: AXUIElement, appURL: URL) -> AXUIElement? {
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var index = 0
        while index < queue.count && index < 512 {
            let (element, depth) = queue[index]
            index += 1
            if matchesDiscord(element, appURL: appURL) { return element }
            if depth < 4, let children = attribute(element, "AXChildren").1 as? [AXUIElement] {
                queue.append(contentsOf: children.map { ($0, depth + 1) })
            }
        }
        return nil
    }

    private func readBadge(_ item: AXUIElement) -> BadgeState? {
        let (error, raw) = attribute(item, "AXStatusLabel")
        switch error {
        case .success:
            guard let raw else { return .noBadge }
            guard let label = raw as? String else { return .unavailable }
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed == "0" ? .noBadge : .unread(trimmed)
        case .noValue: return .noBadge
        default: return nil
        }
    }

    func read() -> BadgeState {
        guard AXIsProcessTrusted() else {
            cachedItem = nil
            return .permissionRequired
        }
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: discordID).isEmpty else {
            cachedItem = nil
            return .notRunning
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: discordID),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            cachedItem = nil
            return .unavailable
        }
        if cachedDockPID != dock.processIdentifier {
            cachedDockPID = dock.processIdentifier
            cachedItem = nil
        }
        if let item = cachedItem, let state = readBadge(item) { return state }
        cachedItem = nil
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.4)
        guard let item = findItem(in: root, appURL: appURL) else { return .unavailable }
        cachedItem = item
        return readBadge(item) ?? .unavailable
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let reader = DockBadgeReader()
    private let readingQueue = DispatchQueue(label: "local.discordbar.dock", qos: .utility)
    private var reading = false
    private var timer: Timer?
    private var state: BadgeState = .unavailable
    private var lastRenderedState: BadgeState?
    private var lastDimPreference: Bool?
    private var discordIcon: NSImage!
    private var menu = NSMenu()
    private var loginError: String?
    private var statusLine: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var dimItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent two instances from occupying two menu bar slots.
        let siblings = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
        if siblings.contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        UserDefaults.standard.register(defaults: ["dimWhenIdle": true])
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: discordID) {
            discordIcon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            discordIcon = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill", accessibilityDescription: "Discord")!
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("DiscordBar")
        }
        buildMenu()
        render()
        refresh()
        timer = Timer(timeInterval: 2, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        timer?.tolerance = 0.4
        RunLoop.main.add(timer!, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh),
            name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        // Only the first manual launch can request system permission. Logins stay quiet.
        if !UserDefaults.standard.bool(forKey: "didSetUp") {
            UserDefaults.standard.set(true, forKey: "didSetUp")
            do { try SMAppService.mainApp.register() }
            catch { loginError = error.localizedDescription }
            if !AXIsProcessTrusted() { requestAccessibility() }
        }
    }

    private func item(_ title: String, _ action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false
        let heading = item("DiscordBar", nil)
        heading.isEnabled = false
        statusLine = item(state.explanation, nil)
        statusLine.isEnabled = false
        menu.addItem(.separator())
        _ = item("Abrir Discord", #selector(openDiscord))
        permissionItem = item("Permitir Acessibilidade…", #selector(requestAccessibility))
        _ = item("Atualizar agora", #selector(refresh))
        menu.addItem(.separator())
        loginItem = item("Iniciar com o Mac", #selector(toggleLogin))
        dimItem = item("Atenuar ícone sem notificações", #selector(toggleDim))
        menu.addItem(.separator())
        _ = item("Como usar…", #selector(showHelp))
        _ = item("Sair do DiscordBar", #selector(quit))
    }

    func menuWillOpen(_ menu: NSMenu) {
        statusLine.title = state.explanation
        permissionItem.title = AXIsProcessTrusted() ? "Ajustes de Acessibilidade…" : "Permitir Acessibilidade…"
        let loginStatus = SMAppService.mainApp.status
        loginItem.state = loginStatus == .enabled ? .on : .off
        loginItem.title = loginStatus == .requiresApproval ? "Autorizar início com o Mac…" : "Iniciar com o Mac"
        dimItem.state = UserDefaults.standard.bool(forKey: "dimWhenIdle") ? .on : .off
        refresh()
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            statusItem.menu = menu
            sender.performClick(nil)
            statusItem.menu = nil
        } else if state == .permissionRequired {
            requestAccessibility()
        } else {
            openDiscord()
        }
    }

    @objc private func refresh() {
        guard !reading else { return }
        reading = true
        readingQueue.async { [weak self] in
            guard let self else { return }
            let result = self.reader.read()
            DispatchQueue.main.async {
                self.reading = false
                self.state = result
                self.render()
                self.statusLine.title = result.explanation
            }
        }
    }

    private func render() {
        let dim = UserDefaults.standard.bool(forKey: "dimWhenIdle")
        guard lastRenderedState != state || lastDimPreference != dim else { return }
        lastRenderedState = state
        lastDimPreference = dim
        var count: String?
        var hasUnread = false
        var needsAttention = false
        switch state {
        case .unread(let value):
            hasUnread = true
            if let number = Int(value), number > 0 { count = number > 99 ? "99+" : String(number) }
        case .permissionRequired, .unavailable: needsAttention = true
        default: break
        }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let textWidth = count.map { ($0 as NSString).size(withAttributes: attributes).width } ?? 0
        let badgeWidth: CGFloat = count == nil ? 8 : max(17, ceil(textWidth) + 8)
        let width: CGFloat = hasUnread ? 21 + badgeWidth : 24
        let icon = discordIcon!
        let currentCount = count
        let unread = hasUnread
        let attention = needsAttention
        let opacity: CGFloat = !unread && !attention && dim ? 0.4 : 1
        let image = NSImage(size: NSSize(width: width, height: 22), flipped: false) { _ in
            icon.draw(in: NSRect(x: 1, y: 2, width: 18, height: 18),
                from: .zero, operation: .sourceOver, fraction: opacity)
            if unread {
                NSColor.systemRed.setFill()
                if let label = currentCount {
                    let rect = NSRect(x: 21, y: 3, width: badgeWidth, height: 16)
                    NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
                    let textSize = (label as NSString).size(withAttributes: attributes)
                    (label as NSString).draw(at: NSPoint(x: rect.midX - textSize.width / 2,
                        y: rect.midY - textSize.height / 2), withAttributes: attributes)
                } else {
                    NSBezierPath(ovalIn: NSRect(x: 21, y: 7, width: 7, height: 7)).fill()
                }
            } else if attention {
                NSColor.systemOrange.setFill()
                NSBezierPath(ovalIn: NSRect(x: 17, y: 13, width: 6, height: 6)).fill()
            }
            return true
        }
        image.isTemplate = false
        statusItem.button?.image = image
        statusItem.button?.toolTip = "DiscordBar — \(state.explanation)\nClique: abrir Discord · Clique direito: opções"
        statusItem.button?.setAccessibilityValue(state.explanation)
    }

    @objc private func openDiscord() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: discordID) else {
            showAlert("Discord não encontrado", "Instale o aplicativo Discord para usar o indicador.")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                DispatchQueue.main.async { self.showAlert("Não foi possível abrir o Discord", error.localizedDescription) }
            }
        }
    }

    @objc private func requestAccessibility() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLogin() {
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            showAlert("Não foi possível alterar o início automático", error.localizedDescription)
        }
    }

    @objc private func toggleDim() {
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: "dimWhenIdle"), forKey: "dimWhenIdle")
        render()
    }

    @objc private func showHelp() {
        var text = "O DiscordBar espelha o indicador do Discord no Dock.\n\nBolinha vermelha: há notificações.\nNúmero: contagem fornecida pelo Dock.\nÍcone atenuado: nenhuma notificação ou Discord fechado.\nBolinha laranja: falta permissão ou o Dock está indisponível.\n\nClique para abrir o Discord. Clique direito (ou Control + clique) para acessar as opções.\n\nEm Ajustes do Sistema → Privacidade e Segurança → Acessibilidade, habilite DiscordBar. Se o macOS não atualizar a permissão imediatamente, saia pelo menu e abra o app novamente.\n\nO Discord deve estar aberto e com o indicador de mensagens não lidas habilitado. O app consulta somente o indicador do Dock, a cada dois segundos. Não acessa mensagens, credenciais ou a internet.\n\nIniciar com o Mac pode ser alterado pelo menu. Não há janela ao iniciar."
        if let error = loginError { text += "\n\nInício automático: \(error)" }
        showAlert("DiscordBar 1.0", text)
    }

    private func showAlert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let delegate = AppDelegate()
application.delegate = delegate
application.run()
