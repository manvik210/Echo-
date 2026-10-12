import SwiftUI

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var busy = false
    @State private var error: String?
    @State private var showSettings = false
    @StateObject private var speech = SpeechManager()

    var body: some View {
        ZStack {
            Color.navy.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("Echo")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.gold)
                    Spacer()
                    Button("Settings") { showSettings = true }
                        .foregroundColor(.gold)
                }
                .padding()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(messages) { m in
                                HStack {
                                    if m.role == "user" { Spacer() }
                                    Text(m.text)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.gold.opacity(m.role == "user" ? 1 : 0.35),
                                                        lineWidth: 0.5)
                                        )
                                    if m.role != "user" { Spacer() }
                                }
                                .id(m.id)
                            }
                            if busy {
                                Text("Thinking…")
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                            if let error = error {
                                Text(error).foregroundColor(.red).font(.footnote)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last { proxy.scrollTo(last.id) }
                    }
                }

                HStack(spacing: 12) {
                    TextField("Message Echo", text: $input)
                        .padding(10)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gold, lineWidth: 0.5)
                        )
                    Button {
                        if speech.listening { speech.stop() } else { speech.start() }
                    } label: {
                        Image(systemName: speech.listening ? "stop.circle.fill" : "mic.fill")
                            .font(.title2)
                            .foregroundColor(.gold)
                    }
                    Button {
                        send(input)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gold)
                    }
                }
                .padding()
            }
        }
        .onChange(of: speech.listening) { isOn in
            if !isOn && !speech.transcript.isEmpty { send(speech.transcript) }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !busy else { return }
        input = ""
        speech.transcript = ""
        messages.append(ChatMessage(role: "user", text: t))
        busy = true
        error = nil
        Task { @MainActor in
            do {
                let reply = try await ChatService.send(messages)
                messages.append(ChatMessage(role: "assistant", text: reply))
                speech.speak(reply)
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Anthropic API key")) {
                    SecureField("sk-ant-...", text: $key)
                }
                Button("Save") {
                    Keychain.save(key, for: "apiKey")
                    dismiss()
                }
            }
            .navigationTitle("Settings")
        }
        .navigationViewStyle(.stack)
    }
}
