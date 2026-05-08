import AppKit
import SwiftUI

// MARK: - Form Constants

enum FormConstants {
    static let fieldWidth: CGFloat = 330
    static let apiKeyFieldWidth: CGFloat = 286
}

// MARK: - Settings Components

struct SettingsRow<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            leading
            Spacer(minLength: 16)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 42)
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(@ViewBuilder leading: () -> Leading) {
        self.leading = leading()
        self.trailing = EmptyView()
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.18))
            .frame(height: 1 / max(NSScreen.main?.backingScaleFactor ?? 2, 1))
            .padding(.leading, 12)
    }
}

struct FieldLabel: View {
    let title: String
    let detail: String

    init(_ title: String, detail: String = "") {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.medium))
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SettingsSelect<Value: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Value
    let options: Options

    init(
        _ title: String,
        selection: Binding<Value>,
        @ViewBuilder options: () -> Options
    ) {
        self.title = title
        self._selection = selection
        self.options = options()
    }

    var body: some View {
        Picker("", selection: $selection) {
            options
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .controlSize(.small)
        .font(.subheadline.weight(.medium))
        .frame(minWidth: 0, alignment: .trailing)
        .accessibilityLabel(title)
    }
}

private struct SettingsCardModifier: ViewModifier {
    let title: String?
    let subtitle: String?

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.horizontal, 10)
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.34), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.08), lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func settingsCard(_ title: String? = nil, subtitle: String? = nil) -> some View {
        modifier(SettingsCardModifier(title: title, subtitle: subtitle))
    }
}
