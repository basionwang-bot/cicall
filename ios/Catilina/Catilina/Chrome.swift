import SwiftUI

enum CatilinaColor {
    static let accent = Color(red: 11.0 / 255.0, green: 110.0 / 255.0, blue: 79.0 / 255.0)
    static let danger = Color(red: 1, green: 59.0 / 255.0, blue: 48.0 / 255.0)
}

struct SectionLabel: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 22)
            .padding(.bottom, 8)
    }
}

struct CatilinaCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }
}

struct FieldLabel: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
    }
}

struct StatusCapsule: View {
    var result: RemoteAttempt?

    var body: some View {
        Text(AgentCopy.statusTitle(for: result))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        switch result {
        case .sessionCreated:
            return CatilinaColor.accent
        case .failed:
            return CatilinaColor.danger
        case nil, .notConnected:
            return Color(.systemGray)
        }
    }
}

struct PrimaryButton: View {
    var title: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(CatilinaColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, 16)
    }
}

struct Footnote: View {
    var text: String
    var danger: Bool = false

    var body: some View {
        Group {
            if danger {
                Text(text).foregroundStyle(CatilinaColor.danger)
            } else {
                Text(text).foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.top, 8)
    }
}
