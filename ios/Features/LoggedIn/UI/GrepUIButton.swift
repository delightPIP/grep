import SwiftUI

// `/Users/carti/Desktop/grep-design` 공용 모바일 부품.

enum GrepButtonKind {
    case primary
    case secondary
    case danger
    case ghost
    case quiet
}

enum GrepButtonSize {
    case sm
    case md
    case lg

    var minHeight: CGFloat {
        switch self {
        case .sm: 36
        case .md: 44
        case .lg: 48
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .sm: 12
        case .md, .lg: 16
        }
    }
}

/// 시안 `UiButton.dc.html`.
struct GrepUIButton: View {
    let label: String
    let kind: GrepButtonKind
    let size: GrepButtonSize
    let fullWidth: Bool
    let isDisabled: Bool
    let icon: String?
    let action: () -> Void

    init(
        _ label: String,
        kind: GrepButtonKind = .secondary,
        size: GrepButtonSize = .md,
        fullWidth: Bool = false,
        isDisabled: Bool = false,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.kind = kind
        self.size = size
        self.fullWidth = fullWidth
        self.isDisabled = isDisabled
        self.icon = icon
        self.action = action
    }

    private let palette = LoggedInPalette.dark

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 14, weight: kind == .quiet ? .regular : .bold, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: size.minHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(isDisabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary: palette.surface
        case .secondary, .ghost: palette.command
        case .danger: palette.danger
        case .quiet: palette.ink
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .primary: palette.prompt
        case .secondary, .danger: palette.surface
        case .ghost: .clear
        case .quiet: palette.surfaceRaised
        }
    }

    private var borderColor: Color {
        switch kind {
        case .primary: palette.prompt
        case .secondary, .danger, .quiet: palette.line
        case .ghost: .clear
        }
    }
}
