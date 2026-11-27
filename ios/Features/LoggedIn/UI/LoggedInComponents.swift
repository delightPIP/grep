import SwiftUI

// `/Users/carti/Desktop/grep-design` 공용 모바일 부품(MTopBar · UiButton · UiSettingRow · MPickBar · MSheet).

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

/// 시안 `MTopBar.dc.html`.
struct GrepTopBar: View {
    let title: String
    let status: String
    let plain: Bool
    let statusAccessibilityId: String?

    init(
        title: String,
        status: String = "",
        plain: Bool = false,
        statusAccessibilityId: String? = nil
    ) {
        self.title = title
        self.status = status
        self.plain = plain
        self.statusAccessibilityId = statusAccessibilityId
    }

    private let palette = LoggedInPalette.dark

    var body: some View {
        HStack(spacing: 8) {
            if plain {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
            } else {
                HStack(spacing: 4) {
                    Text("그렙")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.prompt)
                    Text("— \(title)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if !status.isEmpty {
                let statusText = Text(status)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
                    .lineLimit(1)
                if let statusAccessibilityId {
                    statusText.accessibilityIdentifier(statusAccessibilityId)
                } else {
                    statusText
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(palette.surfaceRaised.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.line).frame(height: 1)
        }
    }
}

/// 시안 `UiSettingRow.dc.html`.
struct GrepSettingRow: View {
    let label: String
    let sub: String
    let actionLabel: String?
    let actionKind: GrepButtonKind
    let isActionDisabled: Bool
    let actionAccessibilityId: String?
    let onAction: (() -> Void)?

    private let palette = LoggedInPalette.dark

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(palette.ink)
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let actionLabel, !actionLabel.isEmpty {
                let button = GrepUIButton(
                    actionLabel,
                    kind: actionKind,
                    size: .sm,
                    isDisabled: isActionDisabled || onAction == nil
                ) {
                    onAction?()
                }
                if let actionAccessibilityId {
                    button.accessibilityIdentifier(actionAccessibilityId)
                } else {
                    button
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.line).frame(height: 1)
        }
    }
}

/// 시안 `MPickBar.dc.html` (summary 모드).
struct GrepPickBar: View {
    let count: Int
    let summary: String
    let onMoveToTerminal: () -> Void
    let onClear: () -> Void

    private let palette = LoggedInPalette.dark

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("선택 \(count)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.command)
                Text(summary)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 8) {
                GrepUIButton(
                    "터미널에서 넘기기",
                    kind: .primary,
                    size: .md,
                    fullWidth: true,
                    icon: "square.and.arrow.up"
                ) {
                    onMoveToTerminal()
                }
                .accessibilityIdentifier("pickBarHandoffButton")

                GrepUIButton(
                    "해제",
                    kind: .secondary,
                    size: .md
                ) {
                    onClear()
                }
                .accessibilityIdentifier("pickBarClearButton")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(palette.surfaceRaised.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(palette.line).frame(height: 1)
        }
        .accessibilityIdentifier("archivePickBar")
    }
}

/// 시안 `MSheet.dc.html`.
struct GrepBottomSheet: View {
    let title: String
    let lines: [String]
    let primaryLabel: String
    let primaryKind: GrepButtonKind
    let cancelLabel: String
    let onPrimary: () -> Void
    let onCancel: () -> Void

    private let palette = LoggedInPalette.dark

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityLabel("시트 닫기")

            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(palette.line)
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.ink)

                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    GrepUIButton(primaryLabel, kind: primaryKind, size: .lg, fullWidth: true) {
                        onPrimary()
                    }
                    .accessibilityIdentifier("sheetPrimaryButton")

                    GrepUIButton(cancelLabel, kind: .secondary, size: .lg, fullWidth: true) {
                        onCancel()
                    }
                    .accessibilityIdentifier("sheetCancelButton")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface.ignoresSafeArea(edges: .bottom))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8))
            .overlay(alignment: .top) {
                Rectangle().fill(palette.line).frame(height: 1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("confirmBottomSheet")
    }
}
