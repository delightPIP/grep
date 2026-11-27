import SwiftUI

// 순수 뷰(ADR-0015). 값과 콜백만 받아 그린다. 이 타깃(`FeatureLoggedOutUI`)은 SwiftUI에만 의존하고 공유 코어와 RIBs를 모른다.
// 배치는 모바일 시안 M7(로그인 · 탭바 없음), 문구는 docs/policies/account/ACC-001-social-login-required.md "사용자 문구" 원문이다.

public enum LoggedOutNoticeKind: Equatable, Sendable {
    case cancelled
    case failed(reason: String)
    case expired
    case signedOut
}

public enum LoggedOutProviderChoice: Equatable, Sendable {
    case google
    case github
}

public struct LoggedOutView: View {
    let notice: LoggedOutNoticeKind?
    let isSigningIn: Bool
    let onSignIn: (LoggedOutProviderChoice) -> Void

    public init(
        notice: LoggedOutNoticeKind?,
        isSigningIn: Bool,
        onSignIn: @escaping (LoggedOutProviderChoice) -> Void
    ) {
        self.notice = notice
        self.isSigningIn = isSigningIn
        self.onSignIn = onSignIn
    }

    private let palette = TerminalPalette.dark

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(palette.line)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    banner
                    statusLines
                    if isSigningIn {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(palette.command)
                            Text("로그인 창 여는 중…")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(palette.inkMuted)
                        }
                        .accessibilityIdentifier("signingInIndicator")
                    }
                    actionCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.bg)
        }
        .background(palette.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack(spacing: 4) {
            Text("그렙")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.prompt)
            Text("— 로그인")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(palette.surfaceRaised.ignoresSafeArea(edges: .top))
    }

    private var banner: some View {
        HStack(alignment: .center, spacing: 12) {
            MoleMascotView(size: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("그렙 ~ $")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.prompt)
                Text("담기 → 찾기 → 넘기기")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(palette.inkMuted)
            }
        }
    }

    @ViewBuilder
    private var statusLines: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let notice {
                noticeLine(notice)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("그렙 ~ $")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.prompt)
                    Text("로그인 필요")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.ink)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("loggedOutPrompt")
            }
        }
    }

    @ViewBuilder
    private func noticeLine(_ notice: LoggedOutNoticeKind) -> some View {
        let presentation = noticePresentation(for: notice)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(presentation.symbol)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(presentation.color)
                .accessibilityHidden(true)
            presentation.text
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(palette.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("loggedOutNotice")
    }

    private var actionCard: some View {
        HStack(spacing: 10) {
            providerButton(title: "Google로 계속", choice: .google, identifier: "googleSignInButton")
            providerButton(title: "GitHub로 계속", choice: .github, identifier: "githubSignInButton")
        }
        .padding(12)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(palette.line, lineWidth: 1)
        )
    }

    private func providerButton(
        title: String,
        choice: LoggedOutProviderChoice,
        identifier: String
    ) -> some View {
        Button {
            onSignIn(choice)
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(isSigningIn ? palette.inkMuted : palette.command)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(palette.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(palette.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isSigningIn)
        .accessibilityIdentifier(identifier)
    }

    private func noticePresentation(for notice: LoggedOutNoticeKind) -> (symbol: String, color: Color, text: Text) {
        switch notice {
        case .cancelled:
            return (
                "✗",
                palette.danger,
                Text("로그인 취소됨").bold().foregroundStyle(palette.danger)
            )
        case .failed(let reason):
            return (
                "✗",
                palette.danger,
                Text("로그인 실패:").bold().foregroundStyle(palette.danger) + Text(" \(reason)")
            )
        case .expired:
            return (
                "!",
                palette.notice,
                Text("로그인 만료").bold().foregroundStyle(palette.notice) + Text(" → 다시 로그인")
            )
        case .signedOut:
            return (
                "✓",
                palette.prompt,
                Text("로그아웃됨").bold()
            )
        }
    }
}

/// 그렙 두더지 기본 모습(16x16). 시안 `web/ui/grep.tsx`의 `MOLE_IDLE`, `MOLE_PALETTE`와 동일하다.
private struct MoleMascotView: View {
    let size: CGFloat

    private static let rows = [
        "................", "................", ".....oooooo.....", "....ommmmmmo....",
        "...ommmmmmmmo...", "...omommmmomo...", "..ommomssmommo..", "..ommmssssmmmo..",
        "..ohhmmmmmmhho..", ".ohhhmmMMmmhhho.", ".ommmmMMMMmmmmo.", "..ommmmmmmmmmo..",
        ".rrommmmmmmmorr.", "rrrRrrrrrrRrrrrr", ".rrrrrRrrrrrrrr.", "................",
    ]

    private static let colors: [Character: Color] = [
        "M": Color(red: 0x4a / 255, green: 0x44 / 255, blue: 0x60 / 255),
        "R": Color(red: 0x6a / 255, green: 0x42 / 255, blue: 0x28 / 255),
        "h": Color(red: 0xf5 / 255, green: 0xc9 / 255, blue: 0xa3 / 255),
        "m": Color(red: 0x6c / 255, green: 0x65 / 255, blue: 0x85 / 255),
        "o": Color(red: 0x16 / 255, green: 0x12 / 255, blue: 0x0f / 255),
        "r": Color(red: 0x8a / 255, green: 0x5a / 255, blue: 0x3a / 255),
        "s": Color(red: 0xf2 / 255, green: 0xa0 / 255, blue: 0xa8 / 255),
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let cell = canvasSize.width / 16
            for (y, row) in Self.rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard let color = Self.colors[ch] else { continue }
                    let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

private struct TerminalPalette {
    let bg: Color
    let surface: Color
    let surfaceRaised: Color
    let line: Color
    let ink: Color
    let inkMuted: Color
    let prompt: Color
    let command: Color
    let notice: Color
    let danger: Color

    static let dark = TerminalPalette(
        bg: Color(red: 0x0b / 255, green: 0x0d / 255, blue: 0x10 / 255),
        surface: Color(red: 0x14 / 255, green: 0x17 / 255, blue: 0x1c / 255),
        surfaceRaised: Color(red: 0x1c / 255, green: 0x20 / 255, blue: 0x27 / 255),
        line: Color(red: 0x2e / 255, green: 0x34 / 255, blue: 0x3d / 255),
        ink: Color(red: 0xe7 / 255, green: 0xe9 / 255, blue: 0xec / 255),
        inkMuted: Color(red: 0x99 / 255, green: 0xa2 / 255, blue: 0xad / 255),
        prompt: Color(red: 0x7f / 255, green: 0xe0 / 255, blue: 0xa3 / 255),
        command: Color(red: 0x86 / 255, green: 0xc8 / 255, blue: 0xff / 255),
        notice: Color(red: 0xf2 / 255, green: 0xc8 / 255, blue: 0x6b / 255),
        danger: Color(red: 0xff / 255, green: 0x8f / 255, blue: 0x86 / 255)
    )
}

#Preview("기본") {
    LoggedOutView(notice: nil, isSigningIn: false, onSignIn: { _ in })
}

#Preview("만료") {
    LoggedOutView(notice: .expired, isSigningIn: false, onSignIn: { _ in })
}
