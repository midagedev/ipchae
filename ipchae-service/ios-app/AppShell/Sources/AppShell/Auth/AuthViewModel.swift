import Foundation

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public var email: String = ""
    @Published public var statusMessage: String = ""
    @Published public var snapshot: AuthSnapshot = .anonymous
    @Published public var loading: Bool = false

    private let service: AuthServiceProtocol

    public init(service: AuthServiceProtocol) {
        self.service = service
    }

    public func refresh() async {
        snapshot = await service.refreshAuthSnapshot()
    }

    public func requestMagicLink() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            statusMessage = "이메일을 입력해 주세요."
            return
        }

        loading = true
        defer { loading = false }

        do {
            try await service.sendMagicLink(email: trimmedEmail)
            statusMessage = "로그인 링크를 전송했습니다. 메일함을 확인해 주세요."
        } catch {
            statusMessage = "링크 전송에 실패했습니다: \(error.localizedDescription)"
        }
    }

    public func signOut() async {
        loading = true
        defer { loading = false }

        do {
            try await service.signOut()
            snapshot = .anonymous
            statusMessage = "로그아웃되었습니다."
        } catch {
            statusMessage = "로그아웃 실패: \(error.localizedDescription)"
        }
    }

    public func handleOpenURL(_ url: URL) async {
        snapshot = await service.handleOpenURL(url)
        if case .authenticated = snapshot.status {
            statusMessage = "로그인 세션이 확인되었습니다."
        }
    }
}
