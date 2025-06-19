import SwiftUI
import Combine
import ComposableArchitecture

// MARK: - Chat View (Modern TCA Implementation)
@ViewAction(for: ChatFeature.self)
struct ChatView: View {
    @Bindable var store: StoreOf<ChatFeature>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages List
                MessagesListView(store: store)
                
                // Input Section
                InputSectionView(store: store)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Deep Sleep Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Clear Messages", role: .destructive) {
                            send(.clearMessages)
                        }
                        
                        Button("New Session") {
                            send(.startNewSession)
                        }
                        
                        Button("Load Previous") {
                            send(.loadPreviousMessages)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Error", isPresented: .constant(store.error != nil)) {
                Button("OK") {
                    send(.dismissError)
                }
            } message: {
                if let error = store.error {
                    Text(error)
                }
            }
            .alert("Feedback", isPresented: $store.showFeedbackAlert) {
                TextField("Your feedback", text: .constant(""))
                Button("Submit") {
                    send(.submitFeedback("User feedback"))
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let prompt = store.feedbackPrompt {
                    Text(prompt)
                }
            }
        }
    }
}

// MARK: - Messages List View
private struct MessagesListView: View {
    let store: StoreOf<ChatFeature>
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.messages) { message in
                    MessageBubbleView(message: message)
                        .id(message.id)
                }
                
                if store.isLoading {
                    TypingIndicatorView()
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .defaultScrollAnchor(.bottom)
    }
}

// MARK: - Message Bubble View
private struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.type == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.type == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.type == .user ? Color.blue : Color(.systemGray6))
                    )
                    .foregroundColor(message.type == .user ? .white : .primary)
                
                HStack(spacing: 4) {
                    if let emotion = message.emotion {
                        Text(emotion.emoji)
                            .font(.caption2)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if message.type == .ai {
                Spacer(minLength: 60)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: message.id)
    }
}

// MARK: - Typing Indicator View
private struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: animationPhase
                        )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animationPhase = 1
        }
    }
}

// MARK: - Input Section View
@ViewAction(for: ChatFeature.self)
private struct InputSectionView: View {
    @Bindable var store: StoreOf<ChatFeature>
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Emotion Selector
            EmotionSelectorView(store: store)
            
            // Recommendations View
            if !store.soundRecommendations.isEmpty {
                RecommendationsView(store: store)
            }
            
            // Analysis Status
            if store.isAnalyzing {
                AnalysisStatusView(store: store)
            }
            
            // Text Input
            HStack(spacing: 8) {
                TextField(
                    "Type your thoughts...",
                    text: $store.currentText,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .lineLimit(1...4)
                .onSubmit {
                    if !store.currentText.isEmpty {
                        send(.sendMessage)
                    }
                }
                
                Button {
                    send(.sendMessage)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(store.currentText.isEmpty ? .gray : .blue)
                }
                .disabled(store.currentText.isEmpty || store.isLoading)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Emotion Selector View
@ViewAction(for: ChatFeature.self)
private struct EmotionSelectorView: View {
    @Bindable var store: StoreOf<ChatFeature>
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(EmotionType.allCases, id: \.self) { emotion in
                    EmotionButton(
                        emotion: emotion,
                        isSelected: store.selectedEmotion == emotion
                    ) {
                        send(.selectEmotion(store.selectedEmotion == emotion ? nil : emotion))
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Emotion Button
private struct EmotionButton: View {
    let emotion: EmotionType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emotion.emoji)
                    .font(.title2)
                
                Text(emotion.localizedName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Recommendations View
@ViewAction(for: ChatFeature.self)
private struct RecommendationsView: View {
    @Bindable var store: StoreOf<ChatFeature>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sound Recommendations")
                    .font(.headline)
                
                Spacer()
                
                Button("Refresh") {
                    send(.regenerateRecommendations)
                }
                .font(.caption)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(store.soundRecommendations) { recommendation in
                        RecommendationCard(recommendation: recommendation)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

// MARK: - Recommendation Card
private struct RecommendationCard: View {
    let recommendation: SoundRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recommendation.soundName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text("Match: \(Int(recommendation.emotionMatch * 100))%")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Button("Play") {
                    // Play sound action
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(10)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        )
    }
}

// MARK: - Analysis Status View
private struct AnalysisStatusView: View {
    let store: StoreOf<ChatFeature>
    
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            
            Text("Analyzing emotions and generating recommendations...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

// MARK: - Legacy ChatView (UIKit Interop)
struct LegacyChatView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ChatViewModel
    
    func makeUIViewController(context: Context) -> ChatViewController {
        let controller = ChatViewController()
        controller.viewModel = viewModel
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ChatViewController, context: Context) {
        // Update UI if needed
    }
}

// MARK: - Preview
#Preview {
    ChatView(
        store: Store(initialState: ChatFeature.State()) {
            ChatFeature()
        }
    )
}

#Preview("With Messages") {
    ChatView(
        store: Store(
            initialState: ChatFeature.State(
                messages: [
                    ChatMessage(
                        id: UUID(),
                        content: "I'm feeling stressed today",
                        type: .user,
                        timestamp: Date(),
                        emotion: .stressed
                    ),
                    ChatMessage(
                        id: UUID(),
                        content: "I understand you're feeling stressed. Let me recommend some calming sounds that might help.",
                        type: .ai,
                        timestamp: Date()
                    )
                ],
                selectedEmotion: .stressed,
                soundRecommendations: [
                    SoundRecommendation(
                        id: UUID(),
                        soundName: "Ocean Waves",
                        description: "Gentle waves for relaxation",
                        emotionMatch: 0.9,
                        filePath: "ocean.mp3"
                    ),
                    SoundRecommendation(
                        id: UUID(),
                        soundName: "Rain Sounds",
                        description: "Peaceful rainfall",
                        emotionMatch: 0.85,
                        filePath: "rain.mp3"
                    )
                ]
            )
        ) {
            ChatFeature()
        }
    )
} 