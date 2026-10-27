import SwiftUI

enum Theme {
    static let background = Color(red: 0x0b / 255, green: 0x0b / 255, blue: 0x0c / 255)
    static let panel = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x16 / 255)
    static let border = Color(red: 0x28 / 255, green: 0x28 / 255, blue: 0x2a / 255)
    static let textSecondary = Color(red: 0xc4 / 255, green: 0xc2 / 255, blue: 0xc3 / 255)
    static let textMuted = Color(red: 0x9a / 255, green: 0x9a / 255, blue: 0x9c / 255)
    static let accent = Color(red: 0x6e / 255, green: 0xe7 / 255, blue: 0xb7 / 255)
    static let warning = Color(red: 0xf5 / 255, green: 0xb2 / 255, blue: 0x5b / 255)
    static let danger = Color(red: 0xd0 / 255, green: 0x5a / 255, blue: 0x5a / 255)
}

struct OverlayView: View {
    @ObservedObject var model: AskViewModel
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(model.status.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("Esc to close")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)
            }

            TextField("Type a request (voice arrives in a later milestone)", text: $model.input)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(8)
                .background(Theme.panel)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                .onSubmit { model.submit() }

            if case .error(let message) = model.status {
                Text(message).font(.system(size: 12)).foregroundColor(Theme.warning)
            }

            if !model.reply.isEmpty {
                // No ScrollView: it collapses to zero height in an auto-sizing window.
                // Replies are spoken-length (a few sentences), so plain wrapping text is enough.
                Text(model.reply)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .lineLimit(12)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            if !model.tokenSummary.isEmpty {
                Text(model.tokenSummary).font(.system(size: 11)).foregroundColor(Theme.textMuted)
            }
        }
        .padding(16)
        .frame(width: 460)
        .background(Theme.background)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onExitCommand { onClose() }
    }

    private var statusColor: Color {
        switch model.status {
        case .idle: return Theme.accent
        case .thinking: return Theme.warning
        case .error: return Theme.danger
        }
    }
}
