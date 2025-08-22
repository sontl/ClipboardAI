import SwiftUI
import Cocoa
import Carbon
import Foundation
import UserNotifications
import GoogleGenerativeAI

@main
struct ClipboardAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate {
    static var shared: AppDelegate!
    var statusItem: NSStatusItem!
    var hotKeyRef: EventHotKeyRef?
    var apiClient = APIClient()
    var prefsWindow: NSWindow?
    var prefsWindowController: NSWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name("StatusBarIcon"))
            if button.image == nil {
                button.title = "📋" // Fallback if image is not found
            }
        }
        // hello world 
        setupMenu()
        // Request notification authorization and set delegate
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
            print("Notifications granted: \(granted)")
        }
        registerHotKey()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        let rephraseItem = NSMenuItem(title: "Copy & Rephrase (⇧⌘C)", action: #selector(rephraseNow(_:)), keyEquivalent: "")
        rephraseItem.target = self
        menu.addItem(rephraseItem)

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences(_:)), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    func registerHotKey() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Install event handler with correct closure signature
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
            if let appDelegate = AppDelegate.shared {
                appDelegate.handleHotKeyEvent()
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
        
        // Register hotkey (Cmd+Shift+C)
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("RPHR".utf8CString.map(UInt8.init)[0...3].reduce(0) { ($0 << 8) + UInt32($1) })
        hotKeyID.id = UInt32(1)
        
        // Cmd + Shift + C key combination
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        
        // 'C' key code
        let keyCode: UInt32 = UInt32(8) // 'C' key
        
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    func handleHotKeyEvent() {
        // Simulate Cmd+C to copy selected text
        simulateCmdC()
        
        // Wait a moment for the copy operation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Get the clipboard contents
            guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
                NSSound.beep()
                return
            }

            //log the clipboard content
            print("Clipboard content: \(clipboardString)")
            
            // Show notification that rephrasing is in progress
            self.showNotification(title: "Rephrasing...", message: "Processing your text")
            
            // Call API to rephrase the text
            self.apiClient.rephraseText(clipboardString) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let rephrasedText):
                        // Replace clipboard content with rephrased text
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(rephrasedText, forType: .string)
                        
                        // Show success notification
                        self.showNotification(title: "Rephrasing Complete", message: "Ready to paste!")
                        
                    case .failure(let error):
                        // Handle error - show a notification
                        self.showNotification(title: "Rephrasing Failed", message: error.localizedDescription)
                        NSSound.beep()
                    }
                }
            }
        }
    }
    
    func simulateCmdC() {
        // Create a CGEvent to simulate Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down for Command key
        let cmdKeyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(55), keyDown: true)
        cmdKeyDown?.flags = .maskCommand
        cmdKeyDown?.post(tap: .cghidEventTap)
        
        // Key down for C key
        let cKeyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(8), keyDown: true)
        cKeyDown?.flags = .maskCommand
        cKeyDown?.post(tap: .cghidEventTap)
        
        // Key up for C key
        let cKeyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(8), keyDown: false)
        cKeyUp?.flags = .maskCommand
        cKeyUp?.post(tap: .cghidEventTap)
        
        // Key up for Command key
        let cmdKeyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(55), keyDown: false)
        cmdKeyUp?.post(tap: .cghidEventTap)
    }
    
    func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = UNNotificationSound.default

        // Deliver immediately
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to deliver notification: \(error)")
            }
        }
    }

    // Ensure notifications show while app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    // MARK: - Menu Actions
    @objc func rephraseNow(_ sender: Any?) {
        handleHotKeyEvent()
    }

    @objc func openPreferences(_ sender: Any?) {
        if prefsWindow == nil {
            let hostingController = NSHostingController(rootView: PreferencesView())
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.center()
            window.title = "Preferences"
            window.contentViewController = hostingController
            window.isReleasedWhenClosed = false
            window.delegate = self
            let controller = NSWindowController(window: window)
            prefsWindow = window
            prefsWindowController = controller
        }
        prefsWindowController?.showWindow(nil)
        prefsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == prefsWindow {
            // Keep window around if needed, or nil out to recreate fresh next time
            prefsWindow = nil
            prefsWindowController = nil
        }
    }
}

// API Client to handle the rephrasing service
class APIClient {
    private let config = GenerationConfig(
        temperature: 1,
        topP: 0.95,
        topK: 40,
        maxOutputTokens: 8192,
        responseMIMEType: "application/json"
    )

    func rephraseText(_ text: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Fetch API key per call to avoid hard-crashing at init
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !apiKey.isEmpty else {
            let err = NSError(domain: "APIClientError", code: 100, userInfo: [NSLocalizedDescriptionKey: "Missing GEMINI_API_KEY. Set it in Scheme > Run > Environment Variables."])
            AppDelegate.shared?.showNotification(title: "Missing API Key", message: "Set GEMINI_API_KEY in the Run scheme.")
            completion(.failure(err))
            return
        }

        let model = GenerativeModel(
            name: "gemini-2.0-flash-exp",
            apiKey: apiKey,
            generationConfig: config
        )

        Task {
            do {
                let chat = model.startChat(history: [])
                // Read user-selected tone (default: Professional)
                let tone = UserDefaults.standard.string(forKey: "rephrase_tone") ?? "Professional"
                let message = "You are a writing assistant. Rephrase the text in a \(tone.lowercased()) tone. Return only the rephrased text with no extra commentary or formatting. Here is the text: \(text)"
                let response = try await chat.sendMessage(message)

                if let responseText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines), !responseText.isEmpty {
                    print("Raw response: \(responseText)")
                    DispatchQueue.main.async {
                        completion(.success(responseText))
                    }
                } else {
                    print("No response text received")
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "APIClientError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No response received"])))
                    }
                }
            } catch {
                print("Task error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
