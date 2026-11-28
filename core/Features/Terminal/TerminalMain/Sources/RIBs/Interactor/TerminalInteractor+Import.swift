import FeatureTerminalInterface
import TerminalDomain
import GrepCore
import GrepData

// MARK: 북마크 가져오기(#127, F8, user-flow 10절)

extension TerminalInteractor {
    /// 진행을 묻는 주기. 처리 중 자료 폴링(ARC-005 규칙 10)과 같은 2초.
    private static let importPollInterval: Duration = .seconds(2)
    /// 실패 줄의 `→ 다시`에 쓰는 명령.
    private static let importRetry = "가져오기"

    /// `가져오기` 뒤에 놓은 첫 파일을 HTML 글로 읽어 보낸다. 나머지 파일은 쓰지 않는다.
    /// 시작한 뒤에는 다른 명령을 쳐도 진행을 계속 묻고, 진행 줄은 제자리에서 고친다.
    func importBookmarks(_ dropped: [DroppedFile]) {
        guard let file = dropped.first else { return }
        startTask { [weak self] in
            guard let self else { return }
            let html: String
            do {
                html = try await files.readText(file.id)
            } catch {
                dropped.forEach { files.release($0.id) }
                showImportFailure(.serverError)
                return
            }
            // 글을 읽었으면 파일은 더 쓰지 않는다. 진행을 묻는 동안 잡고 있지 않는다.
            dropped.forEach { files.release($0.id) }
            guard !Task.isCancelled else { return }
            let token = await authService.accessToken()
            guard !Task.isCancelled else { return }
            guard let token else {
                expire()
                return
            }
            let outcome = await ImportAPI.start(html: html, transport: httpTransport, accessToken: token)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .status(let status) where status.isFinished:
                update(viewState.appending(lines: [Self.finishedLine(status)]))
            case .status(let status):
                update(viewState.appending(lines: [.importProgress(done: status.done, total: status.total)]))
                await followImport(status.id, progressIndex: viewState.lines.count - 1, accessToken: token)
            case .notFound:
                showImportFailure(.serverError)
            case .failed(let reason):
                showImportFailure(reason)
            case .sessionExpired:
                expire()
            case .cancelled:
                break
            }
        }
    }

    /// 끝날 때까지 묻는다. 서버에 닿지 못하면 다음 주기에 다시 묻는다. 404·만료면 멈춘다.
    private func followImport(_ id: String, progressIndex: Int, accessToken: String) async {
        while true {
            await sleeper.sleep(for: Self.importPollInterval)
            guard !Task.isCancelled else { return }
            let outcome = await ImportAPI.status(id: id, transport: httpTransport, accessToken: accessToken)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .status(let status):
                update(viewState.replacingLine(
                    at: progressIndex, with: .importProgress(done: status.done, total: status.total)
                ))
                if status.isFinished {
                    update(viewState.appending(lines: [Self.finishedLine(status)]))
                    return
                }
            case .failed:
                continue
            case .notFound, .cancelled:
                return
            case .sessionExpired:
                expire()
                return
            }
        }
    }

    // MARK: 북마크 파일 제안(#172)

    /// 받지 않는 형식이어도 북마크 파일일 수 있는 확장자. 점 없이, 소문자.
    private static let bookmarkExtensions: Set<String> = ["html", "htm"]

    /// 저장 결과가 받지 않는 형식이고 확장자가 `html`·`htm`이면 `가져오기`를 제안한다.
    static func suggestsImport(_ outcome: ItemsAPI.SaveOutcome) -> Bool {
        guard case .failed(.unsupportedFormat(let fileExtension)) = outcome else { return false }
        return bookmarkExtensions.contains(fileExtension.lowercased())
    }

    /// 인자 없는 `가져오기`(`bring`)인지.
    static func isBareImport(_ text: String) -> Bool {
        guard let command = InputCommand(text) else { return false }
        return command.name == .bring && command.argument.isEmpty
    }

    /// 실패 줄 다음에 제안 줄을 찍고 그 파일을 기억한다. 앞서 기억한 파일은 놓는다.
    func suggestImport(of file: DroppedFile, reason: SaveFailure) {
        forgetSuggestedImport()
        suggestedImport = file
        update(viewState.appending(lines: [
            .saveFailed(reason, .file(name: file.name)), .importSuggest(fileName: file.name),
        ]))
    }

    /// 제안한 파일이 있으면 친 줄을 찍고 그 파일 내용으로 바로 가져온다. 없으면 false.
    func importSuggested(typed: String) -> Bool {
        guard let file = suggestedImport else { return false }
        suggestedImport = nil
        update(viewState.appending(lines: [.prompt(typed)]).with(input: ""))
        importBookmarks([file])
        return true
    }

    /// 기억한 파일을 놓는다. `가져오기`가 아닌 입력이 오면 부른다.
    func forgetSuggestedImport() {
        guard let file = suggestedImport else { return }
        suggestedImport = nil
        files.release(file.id)
    }

    private func showImportFailure(_ reason: CommandFailure) {
        update(viewState.appending(lines: [
            .commandFailed(command: .bring, reason: reason, retry: Self.importRetry),
        ]))
    }

    private static func finishedLine(_ status: ImportAPI.Status) -> TerminalViewState.Line {
        .importFinished(
            saved: status.saved, skipped: status.skipped, failed: status.failed,
            overLimit: status.overLimit, failedUrls: status.failedUrls
        )
    }
}

extension TerminalViewState {
    /// `index`의 줄을 바꾼다. 없는 자리면 그대로 둔다.
    func replacingLine(at index: Int, with line: Line) -> TerminalViewState {
        guard lines.indices.contains(index) else { return self }
        var next = self
        next.lines[index] = line
        return next
    }
}
