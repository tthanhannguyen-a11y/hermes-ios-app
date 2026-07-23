import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                assistantAvatar
            } else {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .foregroundStyle(bubbleForeground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .textSelection(.enabled)

                HStack(spacing: 4) {
                    Text(message.role == .user ? "You" : "Hermes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 6)
            }
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.content
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }

            if message.role == .user {
                userAvatar
            } else {
                Spacer()
            }
        }
    }

    private var bubbleBackground: some ShapeStyle {
        message.role == .user ? AnyShapeStyle(.blue) : AnyShapeStyle(.secondary.opacity(0.15))
    }

    private var bubbleForeground: Color {
        message.role == .user ? .white : .primary
    }

    private var assistantAvatar: some View {
        Image(systemName: "brain.head.profile")
            .font(.title3)
            .foregroundStyle(.purple)
            .frame(width: 28, height: 28)
            .background(.purple.opacity(0.15), in: Circle())
    }

    private var userAvatar: some View {
        Image(systemName: "person.circle.fill")
            .font(.title3)
            .foregroundStyle(.blue)
            .frame(width: 28, height: 28)
    }
}
