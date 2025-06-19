import SwiftUI
import Combine

// MARK: - Chat View (SwiftUI)

public struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText: String = ""
    @State private var showingAlert = false
    @FocusState private var isTextFieldFocused: Bool
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageBubbleView(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isTyping {
                                TypingIndicatorView()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .onChange(of: viewModel.messages) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.isTyping) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
                
                Divider()
                
                // Input Section
                VStack(spacing: 12) {
                    // Quick Action Button
                    Button(action: {
                        Task {
                            await viewModel.requestRecommendation()
                        }
                    }) {
                        HStack {
                            Image(systemName: "music.note")
                            Text("지금 기분에 맞는 사운드 추천받기")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    
                    // Message Input
                    HStack(spacing: 12) {
                        TextField("마음을 편하게 말해보세요...", text: $messageText, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTextFieldFocused)
                            .lineLimit(1...4)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                                .clipShape(Circle())
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("AI 대화")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("대화 기록 지우기") {
                            viewModel.clearSession()
                        }
                        Button("설정") {
                            // Settings action
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("오류", isPresented: $showingAlert) {
            Button("확인", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { errorMessage in
            showingAlert = errorMessage != nil
        }
    }
    
    // MARK: - Private Methods
    
    private func sendMessage() {
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        
        messageText = ""
        isTextFieldFocused = false
        
        Task {
            await viewModel.sendMessage(message)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewReader) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if viewModel.isTyping {
                    proxy.scrollTo("typing", anchor: .bottom)
                } else if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Chat Message Bubble View

public struct ChatMessageBubbleView: View {
    let message: ChatMessageViewModel
    
    public var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .cornerRadius(4, corners: .bottomTrailing)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        // AI Avatar
                        Circle()
                            .fill(Color.green.gradient)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text("AI")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        
                        // Message Content
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message.content)
                                .padding(12)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(16)
                                .cornerRadius(4, corners: .bottomLeading)
                            
                            // Special UI for recommendations
                            if message.messageType == .presetRecommendation {
                                Button("사용해보기") {
                                    // Handle preset application
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 40)
                }
                
                Spacer(minLength: 50)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Typing Indicator View

public struct TypingIndicatorView: View {
    @State private var animationAmount = 0.0
    
    public var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 8) {
                // AI Avatar
                Circle()
                    .fill(Color.green.gradient)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text("AI")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                
                // Typing Animation
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 8, height: 8)
                            .scaleEffect(animationAmount)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: animationAmount
                            )
                    }
                }
                .padding(12)
                .background(Color(.systemGray5))
                .cornerRadius(16)
                .cornerRadius(4, corners: .bottomLeading)
            }
            
            Spacer(minLength: 50)
        }
        .onAppear {
            animationAmount = 1.5
        }
    }
}

// MARK: - View Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#if DEBUG
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
#endif 