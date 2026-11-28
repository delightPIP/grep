#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import GrepCore
import GrepData
import TerminalCommandKit
import TerminalDomain

/// `담기`·붙여 넣기·끌어다 놓기·`가져오기`·샘플(commands 3·6절, ARC-005, COM-004, ARC-010).
/// 가져오기·샘플은 같은 이름의 확장 파일에 있다.
public final class TerminalSaveCommands: TerminalCommandBase, TerminalCommand {
    /// 실패해 입력줄에 되돌린 저장 줄과 그때의 멱등성 키. 같은 줄을 다시 치면 같은 키로 보낸다.
    /// 응답 없음 뒤 서버가 이미 저장했어도 두 번 만들지 않는다(글은 COM-001 판정이 없다).
    private var retryableSave: (typed: String, key: UUID)?
    /// `가져오기`를 치고 북마크 파일을 기다린다. 다른 입력을 치면 놓는다.
    var isAwaitingImport = false
    /// `가져오기`를 제안한 북마크 파일(#172). 다음 입력이 `가져오기`면 이 파일을 보내고, 다른 입력이면 놓는다.
    var suggestedImport: DroppedFile?
    /// `POST /samples` 중복 실행 방지.
    var isSavingSamples = false

    /// 엔터로 친 줄. 북마크 파일 기다림을 놓고, `가져오기`가 아니면 제안한 파일도 놓는다.
    public func noteSubmitted(_ text: String) {
        isAwaitingImport = false
        if !Self.isBareImport(text) { forgetSuggestedImport() }
    }

    /// 인자 없는 `가져오기`. 북마크 파일을 기다린다.
    public func awaitImport(typed: String) {
        isAwaitingImport = true
        update(viewState.appending(lines: [.prompt(typed), .importPrompt]).with(input: ""))
    }

    /// 저장 요청. 친 줄은 바로 찍고 입력줄을 비운다. 실패하면 친 줄을 입력줄에 되돌린다(ARC-005 규칙 2).
    /// `담기 <링크 또는 글>`.
    public func keep(_ argument: String, typed: String) {
        keep(KeepCommand.request(for: argument), typed: typed)
    }

    private func keep(_ request: ItemsAPI.SaveRequest, typed: String) {
        update(viewState.appending(lines: [.prompt(typed)]).with(input: ""))
        let key = retryableSave.flatMap { $0.typed == typed ? $0.key : nil } ?? UUID()
        retryableSave = nil
        startTask { [weak self] in
            guard let self else { return }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                restoreInput(typed)
                expire()
                return
            }
            let outcome = await ItemsAPI.save(
                request, transport: httpTransport, accessToken: token, idempotencyKey: key
            )
            guard !Task.isCancelled else { return }
            switch outcome {
            case .saved, .duplicate, .inTrash:
                showStored(outcome)
            case .failed(let reason):
                // 그새 친 글이 있으면 입력줄을 덮지 않고 다시 칠 명령을 보인다(#57 사용자 결정).
                let recovery: SaveRecovery = viewState.input.isEmpty ? .inputKept : .retry(typed)
                update(viewState.appending(lines: [.saveFailed(reason, recovery)]))
                retryableSave = (typed, key)
                restoreInput(typed)
            case .sessionExpired:
                restoreInput(typed)
                expire()
            case .cancelled:
                break
            }
        }
    }

    /// 붙여 넣은 링크·글은 `담기 <붙인 것>`을 친 것과 같다(user-flow 3절 1단계). 줄바꿈은 살린다.
    public func paste(_ text: String) {
        let content = text.trimmingWhitespace()
        guard !content.isEmpty else { return }
        forgetSuggestedImport()
        context?.beginUserInput()
        keep(KeepCommand.request(for: content), typed: "담기 \(content)")
    }

    /// 끌어다 놓은 파일을 하나씩 저장한다. 한 파일이 실패해도 나머지는 저장한다(COM-004 규칙 3·8).
    /// 원본은 사용자 기기에 있으니 입력줄에 되돌릴 것은 없다. 다 쓴 파일은 바로 놓는다.
    /// shortcut: `GET /uploads/limits`로 보내기 전에 거르지 않고 서버 판정(413·415)만 쓴다. 큰 파일을 올리기 전에 막아야 할 때 더한다.
    public func drop(_ dropped: [DroppedFile]) {
        guard !dropped.isEmpty else { return }
        forgetSuggestedImport()
        if isAwaitingImport {
            isAwaitingImport = false
            importBookmarks(dropped)
            return
        }
        context?.beginUserInput()
        update(viewState.appending(lines: [.prompt((["담기"] + dropped.map(\.name)).joined(separator: " "))]))
        startTask { [weak self] in
            guard let self else { return }
            var remaining = dropped[...]
            defer { remaining.forEach { self.files.release($0.id) } }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                expire()
                return
            }
            while let file = remaining.popFirst() {
                let outcome = await saveFile(file, accessToken: token)
                // 북마크 파일이면 `가져오기`에 쓰려고 놓지 않는다(#172).
                let suggestsImport = !Task.isCancelled && Self.suggestsImport(outcome)
                if !suggestsImport { files.release(file.id) }
                guard !Task.isCancelled else { return }
                switch outcome {
                case .failed(let reason) where suggestsImport:
                    suggestImport(of: file, reason: reason)
                case .saved, .duplicate, .inTrash:
                    showStored(outcome)
                case .failed(let reason):
                    update(viewState.appending(lines: [.saveFailed(reason, .file(name: file.name))]))
                case .sessionExpired:
                    expire()
                    return
                case .cancelled:
                    return
                }
            }
        }
    }

    /// 업로드 자리 받기 → 서명 URL로 올리기 → `POST /items {kind: file}`(api/openapi.yaml `createUpload`).
    private func saveFile(_ file: DroppedFile, accessToken: String) async -> ItemsAPI.SaveOutcome {
        let upload = await ItemsAPI.createUpload(
            fileName: file.name, size: file.size, transport: httpTransport, accessToken: accessToken
        )
        let uploadID: String
        switch upload {
        case .created(let id, let url):
            do {
                try await files.upload(file.id, to: url)
            } catch {
                return Self.outcome(of: error)
            }
            uploadID = id
        case .sessionExpired: return .sessionExpired
        case .failed(let reason): return .failed(reason)
        case .cancelled: return .cancelled
        }
        guard !Task.isCancelled else { return .cancelled }
        return await ItemsAPI.save(
            .file(uploadID: uploadID), transport: httpTransport, accessToken: accessToken, idempotencyKey: UUID()
        )
    }

    private static func outcome(of error: FileUploadError) -> ItemsAPI.SaveOutcome {
        switch error {
        case .cancelled: .cancelled
        case .unreachable: .failed(.disconnected)
        case .timedOut: .failed(.timedOut)
        case .rejected, .missingFile: .failed(.serverError)
        }
    }

    /// 서버가 자료를 가진 결과(새로 저장, 이미 있음, 휴지통에 있음)를 줄로 찍는다.
    private func showStored(_ outcome: ItemsAPI.SaveOutcome) {
        switch outcome {
        case .saved(let item):
            // shortcut: /me 응답과 순서가 엇갈리면 한 건 어긋날 수 있다. 상태줄 갱신을 정하는 #60에서 맞춘다.
            update(viewState.appending(lines: [.saved(item)]).with(itemCount: viewState.itemCount.map { $0 + 1 }))
            notifyItemsChanged()
        case .duplicate(let item):
            update(viewState.appending(lines: [.alreadySaved(item)]))
        case .inTrash(let item):
            update(viewState.appending(lines: [.inTrash(number: item.number)]))
        case .failed, .sessionExpired, .cancelled:
            break
        }
    }
}
