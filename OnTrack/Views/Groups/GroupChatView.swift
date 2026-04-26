import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
final class GroupChatViewModel {

    struct ChatMessage: Identifiable {
        let id: UUID
        let userId: UUID
        let senderName: String
        let content: String
        let createdAt: Date
        var reads: [String] = []
    }

    var messages: [ChatMessage] = []
    var inputText = ""
    var isLoading = false
    var errorMessage: String? = nil
    var memberInitials: [UUID: String] = [:]

    private var realtimeTask: Task<Void, Never>? = nil
    private var channel: RealtimeChannelV2? = nil

    // MARK: - Decode struct (with joined profile)

    private struct GroupMessageRow: Decodable {
        let id: UUID
        let groupId: UUID
        let userId: UUID
        let content: String
        let createdAt: Date
        let profiles: ProfileName

        struct ProfileName: Decodable {
            let displayName: String
            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
            }
        }

        enum CodingKeys: String, CodingKey {
            case id
            case groupId = "group_id"
            case userId = "user_id"
            case content
            case createdAt = "created_at"
            case profiles
        }
    }

    // MARK: - Load

    func load(groupId: UUID) async {
        isLoading = true
        await fetchMessagesWithReads(groupId: groupId)
        isLoading = false
        subscribeToRealtime(groupId: groupId)
    }

    func fetchMessages(groupId: UUID) async {
        do {
            let rows: [GroupMessageRow] = try await supabase
                .from("group_messages")
                .select("*, profiles(display_name)")
                .eq("group_id", value: groupId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            self.messages = rows.map {
                ChatMessage(
                    id: $0.id,
                    userId: $0.userId,
                    senderName: $0.profiles.displayName,
                    content: $0.content,
                    createdAt: $0.createdAt
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Send

    func sendMessage(groupId: UUID, userId: UUID) async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        errorMessage = nil
        do {
            try await supabase
                .from("group_messages")
                .insert([
                    "group_id": groupId.uuidString,
                    "user_id": userId.uuidString,
                    "content": text
                ])
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Read Receipts

    func markMessagesAsRead(groupId: UUID, userId: UUID) async {
        do {
            // Get IDs of messages not yet read by this user
            let unread = messages.filter { !$0.reads.contains(String($0.senderName.prefix(1)).uppercased()) || true }
            for message in messages {
                try? await supabase
                    .from("message_reads")
                    .upsert([
                        "message_id": message.id.uuidString,
                        "user_id": userId.uuidString
                    ], onConflict: "message_id,user_id")
                    .execute()
            }
            await fetchMessagesWithReads(groupId: groupId)
        }
    }

    func fetchMessagesWithReads(groupId: UUID) async {
        do {
            let rows: [GroupMessageRow] = try await supabase
                .from("group_messages")
                .select("*, profiles(display_name)")
                .eq("group_id", value: groupId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            // Fetch all reads for this group's messages
            struct ReadRow: Decodable {
                let messageId: UUID
                let userId: UUID
                let profiles: ProfileInitial
                struct ProfileInitial: Decodable {
                    let displayName: String
                    enum CodingKeys: String, CodingKey { case displayName = "display_name" }
                }
                enum CodingKeys: String, CodingKey {
                    case messageId = "message_id"
                    case userId = "user_id"
                    case profiles
                }
            }

            let messageIds = rows.map { $0.id.uuidString }
            var readsByMessage: [UUID: [String]] = [:]

            if !messageIds.isEmpty {
                let reads: [ReadRow] = try await supabase
                    .from("message_reads")
                    .select("message_id, user_id, profiles(display_name)")
                    .in("message_id", values: messageIds)
                    .execute()
                    .value
                for read in reads {
                    let initial = String(read.profiles.displayName.prefix(1)).uppercased()
                    readsByMessage[read.messageId, default: []].append(initial)
                }
            }

            self.messages = rows.map {
                ChatMessage(
                    id: $0.id,
                    userId: $0.userId,
                    senderName: $0.profiles.displayName,
                    content: $0.content,
                    createdAt: $0.createdAt,
                    reads: readsByMessage[$0.id] ?? []
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    func deleteMessage(id: UUID) async {
        messages.removeAll { $0.id == id }
        do {
            try await supabase
                .from("group_messages")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Realtime

    private func subscribeToRealtime(groupId: UUID) {
        let ch = supabase.realtimeV2.channel("group-chat-\(groupId.uuidString)")

        let insertions = ch.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "group_messages",
            filter: .eq("group_id", value: groupId.uuidString)
        )

        realtimeTask = Task {
            try? await ch.subscribeWithError()
            for await _ in insertions {
                await fetchMessagesWithReads(groupId: groupId)
            }
        }

        channel = ch
    }

    func unsubscribe() {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let ch = channel {
            Task { await supabase.realtimeV2.removeChannel(ch) }
            channel = nil
        }
    }
}

// MARK: - View

struct GroupChatView: View {
    let group: AppGroup
    @EnvironmentObject private var appState: AppState
    @State private var vm = GroupChatViewModel()

    private let gradientStart = Color(red: 0.08, green: 0.35, blue: 0.45)
    private let gradientEnd   = Color(red: 0.15, green: 0.55, blue: 0.38)

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                List {
                    if vm.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.top, 40)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else if vm.messages.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No messages yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(vm.messages) { message in
                            let isOwn = message.userId == appState.currentUser?.id
                            MessageBubble(
                                message: message,
                                isOwn: isOwn,
                                gradientStart: gradientStart,
                                gradientEnd: gradientEnd,
                                reads: message.reads
                            )
                            .id(message.id)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .if(isOwn) { view in
                                view.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task { await vm.deleteMessage(id: message.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onChange(of: vm.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(vm.messages.last?.id, anchor: .bottom)
                    }
                }
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

            Divider()

            // Input bar
            HStack(spacing: 10) {
                TextField("Message...", text: $vm.inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    guard let userId = appState.currentUser?.id else { return }
                    Task { await vm.sendMessage(groupId: group.id, userId: userId) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(
                            vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AnyShapeStyle(Color.secondary)
                                : AnyShapeStyle(LinearGradient(
                                    colors: [gradientStart, gradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  ))
                        )
                }
                .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load(groupId: group.id)
            if let userId = appState.currentUser?.id {
                await vm.markMessagesAsRead(groupId: group.id, userId: userId)
            }
        }
        .onDisappear {
            vm.unsubscribe()
        }
    }
}

// MARK: - View extension for conditional modifier

private extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: GroupChatViewModel.ChatMessage
    let isOwn: Bool
    let gradientStart: Color
    let gradientEnd: Color
    let reads: [String]

    private var initial: String {
        String(message.senderName.prefix(1)).uppercased()
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwn {
                Spacer(minLength: 64)
            } else {
                avatarCircle
            }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 3) {
                if !isOwn {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }

                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(isOwn ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        if isOwn {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(LinearGradient(
                                    colors: [gradientStart, gradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        } else {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.regularMaterial)
                        }
                    }

                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                if !reads.isEmpty {
                    HStack(spacing: -6) {
                        ForEach(reads.prefix(5), id: \.self) { initial in
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [gradientStart, gradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 18, height: 18)
                                Text(initial)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            if isOwn {
                avatarCircle
            } else {
                Spacer(minLength: 64)
            }
        }
    }

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [gradientStart, gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 32, height: 32)
            Text(initial)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }
}
