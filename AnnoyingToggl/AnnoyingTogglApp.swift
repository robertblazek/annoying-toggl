import SwiftUI

@main
struct AnnoyingTogglApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Annoying Clock", systemImage: "timer") {
            ContentView()
                .environmentObject(appDelegate)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ProgressInfo {
    let value: Double
    let label: String
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var timer: Timer?
    private var progressTimer: Timer?
    private var togglService: TogglService?
    private var workspaceId: Int?
    private var checkInterval: TimeInterval = 300 // 5 minutes default
    private var lastCheckTime: Date?

    @Published var isMuted = false
    @Published var muteEndTime: Date?
    @Published var currentProgress: ProgressInfo?
    @Published var currentTimerDescription: String = ""
    @Published var apiCallCount: Int = 0
    private var lastApiReset: Date?
    private var currentEntryId: Int?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launched")
        setupLaunchAgent()
        setupTogglService()
        startBackgroundTimer()
        startProgressTimer()
    }

    private func setupTogglService() {
        if let savedToken = UserDefaults.standard.string(forKey: "apiToken"), !savedToken.isEmpty {
            print("Setting up Toggl service with saved token")
            togglService = TogglService(apiToken: savedToken)
            togglService?.onApiCall = { [weak self] in
                DispatchQueue.main.async {
                    self?.apiCallCount += 1
                }
            }
            Task {
                do {
                    print("Fetching workspaces")
                    let workspaces = try await togglService!.getWorkspaces()
                    workspaceId = workspaces.first?.id
                    print("Workspaces fetched, first ID: \(workspaceId ?? 0)")
                } catch {
                    print("Failed to get workspaces: \(error)")
                }
            }
        } else {
            print("No API token saved")
        }
    }

    private func startBackgroundTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkTimer()
        }
        timer?.fire() // Check immediately
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func updateProgress() {
        if isMuted, let endTime = muteEndTime {
            let remaining = endTime.timeIntervalSince(Date())
            if remaining > 0 {
                let total = TimeInterval(UserDefaults.standard.integer(forKey: "muteDuration") * 60)
                let progress = 1.0 - (remaining / total)
                currentProgress = ProgressInfo(
                    value: progress,
                    label: String(format: "Muted: %.0f min left", remaining / 60)
                )
            } else {
                isMuted = false
                muteEndTime = nil
                currentProgress = nil
            }
        } else if let lastCheck = lastCheckTime {
            let elapsed = Date().timeIntervalSince(lastCheck)
            let progress = min(elapsed / checkInterval, 1.0)
            currentProgress = ProgressInfo(
                value: progress,
                label: String(format: "Next check: %.0f min", (checkInterval - elapsed) / 60)
            )
        }
    }

    func updateCheckFrequency(minutes: Int) {
        checkInterval = TimeInterval(minutes * 60)
        startBackgroundTimer()
    }

    private func checkTimer() {
        lastCheckTime = Date()
        print("Checking timer at \(Date())")
        // Reset API count every hour
        if let lastReset = lastApiReset, Date().timeIntervalSince(lastReset) >= 3600 {
            apiCallCount = 0
            lastApiReset = Date()
            print("API call count reset")
        } else if lastApiReset == nil {
            lastApiReset = Date()
        }

        guard !isMuted, let togglService = togglService, let _ = workspaceId else {
            print("Check skipped: muted=\(isMuted), service=\(togglService != nil), workspaceId=\(workspaceId ?? 0)")
            return
        }

        Task {
            do {
                print("Fetching current time entry")
                let currentEntry = try await togglService.getCurrentTimeEntry()
                DispatchQueue.main.async {
                    self.currentTimerDescription = currentEntry?.description ?? ""
                    self.currentEntryId = currentEntry?.id
                }
                if currentEntry == nil {
                    print("No current timer running, showing popup")
                    showPopup()
                } else {
                    print("Current timer: \(currentEntry!.description)")
                }
            } catch {
                print("Failed to check timer: \(error)")
            }
        }
    }

    private func showPopup() {
        print("Showing popup")
        DispatchQueue.main.async {
            Task {
                do {
                    print("Fetching recent entries")
                    let recentEntries = try await self.togglService!.getRecentTimeEntries()
                    let descriptions = Array(Set(recentEntries.compactMap { $0.description }.filter { !$0.isEmpty })).prefix(10)
                    print("Recent descriptions: \(descriptions)")

                    let alert = NSAlert()
                    alert.messageText = "No Timer Running!"
                    alert.informativeText = "Please enter what you're working on:"
                    alert.addButton(withTitle: "Start Timer")
                    alert.addButton(withTitle: "Mute")

                    let comboBox = NSComboBox(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                    comboBox.placeholderString = "What are you working on?"
                    comboBox.addItems(withObjectValues: Array(descriptions))
                    comboBox.isEditable = true
                    alert.accessoryView = comboBox

                    let response = alert.runModal()
                    print("Alert response: \(response.rawValue)")
                    if response == .alertFirstButtonReturn {
                        let description = comboBox.stringValue
                        print("Starting timer with description: \(description)")
                        if !description.isEmpty {
                            Task {
                                do {
                                    _ = try await self.togglService!.startTimeEntry(description: description, workspaceId: self.workspaceId!)
                                    print("Timer started")
                                } catch {
                                    print("Failed to start timer: \(error)")
                                }
                            }
                        }
                    } else if response == .alertSecondButtonReturn {
                        let muteMinutes = UserDefaults.standard.integer(forKey: "muteDuration")
                        print("Muting for \(muteMinutes) minutes")
                        self.muteFor(minutes: muteMinutes)
                    }
                } catch {
                    print("Failed to get recent entries: \(error)")
                    // Fallback to text field
                    let alert = NSAlert()
                    alert.messageText = "No Timer Running!"
                    alert.informativeText = "Please enter what you're working on:"
                    alert.addButton(withTitle: "Start Timer")
                    alert.addButton(withTitle: "Mute")

                    let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                    input.placeholderString = "What are you working on?"
                    alert.accessoryView = input

                    let response = alert.runModal()
                    print("Fallback alert response: \(response.rawValue)")
                    if response == .alertFirstButtonReturn {
                        let description = input.stringValue
                        print("Starting timer with description: \(description)")
                        if !description.isEmpty {
                            Task {
                                do {
                                    _ = try await self.togglService!.startTimeEntry(description: description, workspaceId: self.workspaceId!)
                                    print("Timer started")
                                } catch {
                                    print("Failed to start timer: \(error)")
                                }
                            }
                        }
                    } else if response == .alertSecondButtonReturn {
                        let muteMinutes = UserDefaults.standard.integer(forKey: "muteDuration")
                        print("Muting for \(muteMinutes) minutes")
                        self.muteFor(minutes: muteMinutes)
                    }
                }
            }
        }
    }

    func muteFor(minutes: Int) {
        isMuted = true
        muteEndTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    func muteFor(hours: Int) {
        muteFor(minutes: hours * 60)
    }

    func logout() {
        togglService = nil
        workspaceId = nil
        isMuted = false
        muteEndTime = nil
        currentProgress = nil
        currentTimerDescription = ""
        apiCallCount = 0
        lastApiReset = nil
        currentEntryId = nil
    }

    func changeTask(description: String) async throws {
        guard let entryId = currentEntryId, let wsId = workspaceId, let service = togglService else { return }
        // Stop current timer
        _ = try await service.stopTimeEntry(timeEntryId: entryId, workspaceId: wsId)
        // Start new timer with new description
        _ = try await service.startTimeEntry(description: description, workspaceId: wsId)
        // UI will update on next check
        DispatchQueue.main.async {
            self.currentTimerDescription = description
            self.currentEntryId = nil // Will be set on next check
        }
    }

    private func setupLaunchAgent() {
        let appPath = Bundle.main.bundlePath
        let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        try? FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

        let plistPath = launchAgentsDir.appendingPathComponent("com.annoyingtoggl.plist")
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.annoyingtoggl</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(appPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """

        try? plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
    }
}
