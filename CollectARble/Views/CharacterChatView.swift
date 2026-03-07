import SwiftUI
import Speech
import AVFoundation
import Combine

struct CharacterChatView: View {
    let creature: Creature
    @Binding var isPresented: Bool
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var isRecording: Bool = false
    @State private var showTextInput: Bool = false
    @State private var transcribedText: String = ""
    @StateObject private var speechRecognizer = SpeechRecognizer()
    private let chatService = CharacterChatService()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: creature.element.symbolName)
                    .foregroundStyle(creature.element.displayColor)
                Text("Chat with \(creature.name)")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Welcome message
                        if messages.isEmpty {
                            welcomeMessage
                        }

                        ForEach(messages) { message in
                            ChatBubble(message: message, creature: creature)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                TypingIndicator(color: creature.element.displayColor)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input area
            VStack(spacing: 8) {
                // Transcribed text preview while recording
                if isRecording && !transcribedText.isEmpty {
                    Text(transcribedText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Text input (shown when keyboard button is tapped)
                if showTextInput {
                    HStack(spacing: 12) {
                        TextField("Type a message...", text: $inputText)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(.systemGray6), in: .capsule)
                            .submitLabel(.send)
                            .onSubmit(sendMessage)

                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title)
                                .foregroundStyle(inputText.isEmpty ? .secondary : creature.element.displayColor)
                        }
                        .disabled(inputText.isEmpty || isLoading)
                    }
                    .padding(.horizontal)
                }

                // Main voice input controls
                HStack(spacing: 16) {
                    // Keyboard toggle button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showTextInput.toggle()
                        }
                    } label: {
                        Image(systemName: showTextInput ? "mic.fill" : "keyboard")
                            .font(.title3)
                            .foregroundStyle(creature.element.displayColor.opacity(0.8))
                            .frame(width: 40, height: 40)
                    }

                    // Main microphone button
                    Button {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red : creature.element.displayColor)
                                .frame(width: 56, height: 56)
                                .shadow(color: (isRecording ? Color.red : creature.element.displayColor).opacity(0.3), radius: 8)

                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(isRecording ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)
                    }
                    .disabled(isLoading)

                    // Send button or spacer
                    if isRecording && !transcribedText.isEmpty {
                        Button {
                            sendVoiceMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(creature.element.displayColor)
                                .frame(width: 40, height: 40)
                        }
                    } else {
                        Color.clear
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.vertical, 8)

                // Voice hint text
                if !showTextInput && !isRecording {
                    Text("Tap to speak with \(creature.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .background(.regularMaterial)
        }
        .background(Color(.systemBackground).opacity(0.95))
        .clipShape(.rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }

    private var welcomeMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: creature.element.symbolName)
                .font(.largeTitle)
                .foregroundStyle(creature.element.displayColor)

            Text("\(creature.name) wants to chat!")
                .font(.headline)

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                    Text("Tap the mic to talk")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(creature.element.displayColor)

                Text("Ask me anything about myself, my abilities, or just say hi!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(creature.element.displayColor.opacity(0.1), in: .rect(cornerRadius: 16))
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        Task {
            do {
                let response = try await chatService.chat(userMessage: text, character: creature)
                await MainActor.run {
                    let characterMessage = ChatMessage(role: .character, content: response)
                    messages.append(characterMessage)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(role: .character, content: "Hmm, I couldn't respond. \(error.localizedDescription)")
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }

    private func startRecording() {
        transcribedText = ""

        // If permissions not checked yet, check them first
        if !speechRecognizer.permissionsChecked {
            speechRecognizer.checkAndRequestPermissions { [self] granted in
                if granted {
                    self.beginRecording()
                } else {
                    // Fall back to text input
                    withAnimation {
                        self.showTextInput = true
                    }
                }
            }
            return
        }

        // Check if authorized
        guard speechRecognizer.isAuthorized && speechRecognizer.isMicrophoneAuthorized else {
            showTextInput = true
            return
        }

        beginRecording()
    }

    private func beginRecording() {
        speechRecognizer.startRecording { text in
            transcribedText = text
        }
        withAnimation {
            isRecording = true
        }
    }

    private func stopRecording() {
        speechRecognizer.stopRecording()
        withAnimation {
            isRecording = false
        }

        // If we have transcribed text, send it
        if !transcribedText.isEmpty {
            sendVoiceMessage()
        }
    }

    private func sendVoiceMessage() {
        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        speechRecognizer.stopRecording()
        isRecording = false

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        transcribedText = ""
        isLoading = true

        Task {
            do {
                let response = try await chatService.chat(userMessage: text, character: creature)
                await MainActor.run {
                    let characterMessage = ChatMessage(role: .character, content: response)
                    messages.append(characterMessage)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(role: .character, content: "Hmm, I couldn't respond. \(error.localizedDescription)")
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    let creature: Creature

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor, in: bubbleShape)
                    .foregroundStyle(message.role == .user ? .white : .primary)
            }

            if message.role == .character {
                Spacer(minLength: 60)
            }
        }
    }

    private var bubbleColor: Color {
        message.role == .user ? .blue : creature.element.displayColor.opacity(0.2)
    }

    private var bubbleShape: some Shape {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }
}

struct TypingIndicator: View {
    let color: Color
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: animationPhase
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(color.opacity(0.2), in: .capsule)
        .onAppear {
            animationPhase = 1
        }
    }
}

// Floating speech bubble for AR overlay
struct ARSpeechBubble: View {
    let message: String
    let creature: Creature
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 0) {
                Text(message)
                    .font(.subheadline)
                    .padding(12)
                    .background(creature.element.displayColor.opacity(0.9), in: .rect(cornerRadius: 12))
                    .foregroundStyle(.white)

                // Bubble tail
                Triangle()
                    .fill(creature.element.displayColor.opacity(0.9))
                    .frame(width: 16, height: 10)
                    .rotationEffect(.degrees(180))
                    .offset(x: 20)
            }
            .transition(.scale.combined(with: .opacity))
            .onTapGesture {
                withAnimation {
                    isVisible = false
                }
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Speech Recognizer

class SpeechRecognizer: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?

    @Published var isAuthorized: Bool = false
    @Published var isMicrophoneAuthorized: Bool = false
    @Published var permissionsChecked: Bool = false

    init() {
        // Don't check permissions on init - wait until user taps mic
    }

    func checkAndRequestPermissions(completion: @escaping (Bool) -> Void) {
        // Request microphone permission first
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] micGranted in
                self?.handleMicPermission(granted: micGranted, completion: completion)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] micGranted in
                self?.handleMicPermission(granted: micGranted, completion: completion)
            }
        }
    }

    private func handleMicPermission(granted micGranted: Bool, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.isMicrophoneAuthorized = micGranted

            if micGranted {
                // Then request speech recognition
                SFSpeechRecognizer.requestAuthorization { [weak self] status in
                    DispatchQueue.main.async {
                        let speechGranted = status == .authorized
                        self?.isAuthorized = speechGranted
                        self?.permissionsChecked = true

                        if speechGranted {
                            self?.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
                        }

                        completion(micGranted && speechGranted)
                    }
                }
            } else {
                self?.permissionsChecked = true
                completion(false)
            }
        }
    }

    func requestPermissions() {
        checkAndRequestPermissions { _ in }
    }

    func startRecording(onTranscription: @escaping (String) -> Void) {
        // If permissions not checked yet, request them first
        guard permissionsChecked else {
            checkAndRequestPermissions { [weak self] granted in
                if granted {
                    self?.startRecording(onTranscription: onTranscription)
                }
            }
            return
        }

        // Check permissions
        guard isAuthorized && isMicrophoneAuthorized else {
            print("Speech or microphone not authorized")
            return
        }

        guard speechRecognizer != nil else {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            return
        }

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    onTranscription(transcription)
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopRecording()
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
}

#Preview {
    CharacterChatView(
        creature: Creature.allCreatures[0],
        isPresented: .constant(true)
    )
    .frame(height: 500)
    .padding()
}
