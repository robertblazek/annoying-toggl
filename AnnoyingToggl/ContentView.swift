import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var checkFrequency: Int = UserDefaults.standard.integer(forKey: "checkFrequency") == 0 ? 5 : UserDefaults.standard.integer(forKey: "checkFrequency")
    @State private var muteDuration: Int = UserDefaults.standard.integer(forKey: "muteDuration") == 0 ? 120 : UserDefaults.standard.integer(forKey: "muteDuration") // minutes
    @State private var apiToken: String = UserDefaults.standard.string(forKey: "apiToken") ?? ""
    @State private var showTokenInput = false
    @State private var showChangeTask = false
    @State private var newTaskDescription = ""
    @State private var showSettings = false

    let frequencyOptions = [5, 10, 15, 20, 25, 30]
    let muteOptions = [30, 60, 90, 120] // minutes

    var body: some View {
        VStack(spacing: 12) {
            Text("Annoying Toggl")
                .font(.headline)

            if !appDelegate.currentTimerDescription.isEmpty {
                HStack {
                    Text("Current: \(appDelegate.currentTimerDescription)")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Button("Change") {
                        newTaskDescription = ""
                        showChangeTask = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Progress Bar
            if let progress = appDelegate.currentProgress {
                VStack {
                    Text(progress.label)
                        .font(.caption)
                    ProgressView(value: progress.value, total: 1.0)
                        .progressViewStyle(.linear)
                }
                .frame(width: 200)
            }
            
            // Mute Section
            if appDelegate.isMuted, let endTime = appDelegate.muteEndTime {
                Text("Muted until \(endTime.formatted(date: .omitted, time: .shortened))")
                    .foregroundColor(.orange)
            } else {
                HStack {
                    Button("Mute for \(muteDuration) min") {
                        appDelegate.muteFor(minutes: muteDuration)
                    }
                    Picker("", selection: $muteDuration) {
                        ForEach(muteOptions, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .frame(width: 80)
                    .onChange(of: muteDuration) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "muteDuration")
                    }
                }
                
                
            }

            Spacer()

            DisclosureGroup("Settings", isExpanded: $showSettings) {
                
                
                VStack(spacing: 12) {
                    // API Token Section
                    HStack {
                        if !apiToken.isEmpty {
                            Text("API Token: \(String(repeating: "•", count: min(apiToken.count, 20)))")
                            Button("Logout") {
                                logout()
                            }
                        } else {
                            Button("Add API Token") {
                                showTokenInput = true
                            }
                        }
                    }

                    // Check Frequency
                    HStack {
                        Text("Check every:")
                        Picker("", selection: $checkFrequency) {
                            ForEach(frequencyOptions, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .frame(width: 100)
                        .onChange(of: checkFrequency) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "checkFrequency")
                            appDelegate.updateCheckFrequency(minutes: newValue)
                        }
                    }
                    
                    
                    Text("API calls this hour: \(appDelegate.apiCallCount)/30")
                        .font(.caption)
                        .foregroundColor(appDelegate.apiCallCount > 25 ? .red : .secondary)
                }
            }
        }
        .padding()
        .frame(width: 250, height: 300)
        .sheet(isPresented: $showTokenInput) {
            TokenInputView(apiToken: $apiToken, isPresented: $showTokenInput)
        }
        .sheet(isPresented: $showChangeTask) {
            VStack(spacing: 20) {
                Text("Switch to New Task")
                    .font(.headline)
                TextField("New task description", text: $newTaskDescription)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") {
                        showChangeTask = false
                    }
                    Button("Switch") {
                        Task {
                            do {
                                try await appDelegate.changeTask(description: newTaskDescription)
                                showChangeTask = false
                            } catch {
                                print("Failed to switch task: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 300, height: 150)
        }
    }

    private func logout() {
        apiToken = ""
        UserDefaults.standard.removeObject(forKey: "apiToken")
        appDelegate.logout()
    }
}

struct TokenInputView: View {
    @Binding var apiToken: String
    @Binding var isPresented: Bool
    @State private var inputToken = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Toggl API Token")
                .font(.headline)

            Text("Get your API token from: https://track.toggl.com/profile")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            SecureField("API Token", text: $inputToken)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                Button("Save") {
                    if !inputToken.isEmpty {
                        apiToken = inputToken
                        UserDefaults.standard.set(inputToken, forKey: "apiToken")
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}
