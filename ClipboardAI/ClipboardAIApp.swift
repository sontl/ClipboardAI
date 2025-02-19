import SwiftUI
import Cocoa
import Carbon
import Foundation
import GoogleGenerativeAI
@main
struct ClipboardAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!
    var statusItem: NSStatusItem!
    var hotKeyRef: EventHotKeyRef?
    var apiClient = APIClient()
    
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
        registerHotKey()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Copy & Rephrase (⇧⌘C)", action: nil, keyEquivalent: ""))
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
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// API Client to handle the rephrasing service
class APIClient {
    private let model: GenerativeModel
    
    init() {
        let config = GenerationConfig(
            temperature: 1,
            topP: 0.95,
            topK: 40,
            maxOutputTokens: 8192,
            responseMIMEType: "application/json"
        )
        
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] else {
            fatalError("Add GEMINI_API_KEY as an Environment Variable in your app's scheme.")
        }
        
        model = GenerativeModel(
            name: "gemini-2.0-flash-exp",
            apiKey: apiKey,
            generationConfig: config
        )
    }
    
    func rephraseText(_ text: String, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                // Create a new chat instance for each request
                let chat = model.startChat(history: [])
                
                 let message = "Please rephrase the following text in a professional manner, Just return the rephrased text, no other text or comment, Only return one option, no other options. Don't return array. Here is the text need to rephrase: \(text)" 
                let response = try await chat.sendMessage(message)
                
                if let responseText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
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
