import AppShell
import XCTest

private actor MockAuthService: AuthServiceProtocol {
    var shouldFailMagicLink = false
    var signOutCalled = false
    var sentEmails: [String] = []

    func sendMagicLink(email: String) async throws {
        if shouldFailMagicLink {
            struct MockError: Error {}
            throw MockError()
        }
        sentEmails.append(email)
    }

    func signOut() async throws {
        signOutCalled = true
    }

    func refreshAuthSnapshot() async -> AuthSnapshot {
        .anonymous
    }

    func handleOpenURL(_ url: URL) async -> AuthSnapshot {
        .anonymous
    }

    func allEmails() -> [String] {
        sentEmails
    }

    func didCallSignOut() -> Bool {
        signOutCalled
    }
}

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testRequestMagicLinkSendsEmail() async {
        let service = MockAuthService()
        let viewModel = AuthViewModel(service: service)
        viewModel.email = "hello@example.com"

        await viewModel.requestMagicLink()

        let sent = await service.allEmails()
        XCTAssertEqual(sent, ["hello@example.com"])
        XCTAssertTrue(viewModel.statusMessage.contains("전송"))
    }

    func testRequestMagicLinkRequiresEmail() async {
        let service = MockAuthService()
        let viewModel = AuthViewModel(service: service)
        viewModel.email = "   "

        await viewModel.requestMagicLink()

        let sent = await service.allEmails()
        XCTAssertEqual(sent.count, 0)
        XCTAssertTrue(viewModel.statusMessage.contains("이메일"))
    }

    func testSignOutUpdatesStatusMessage() async {
        let service = MockAuthService()
        let viewModel = AuthViewModel(service: service)

        await viewModel.signOut()

        let didCallSignOut = await service.didCallSignOut()
        XCTAssertEqual(viewModel.snapshot, .anonymous)
        XCTAssertTrue(viewModel.statusMessage.contains("로그아웃"))
        XCTAssertTrue(didCallSignOut)
    }

    func testHandleOpenURLSetsSnapshotWhenAuthenticated() async {
        actor AuthenticatedService: AuthServiceProtocol {
            func sendMagicLink(email: String) async throws {}
            func signOut() async throws {}
            func refreshAuthSnapshot() async -> AuthSnapshot { .anonymous }
            func handleOpenURL(_ url: URL) async -> AuthSnapshot {
                AuthSnapshot(status: .authenticated(userID: "user-1", email: "hello@example.com"))
            }
        }

        let viewModel = AuthViewModel(service: AuthenticatedService())
        await viewModel.handleOpenURL(URL(string: "ipchae://auth-callback")!)

        if case .authenticated(let userID, let email) = viewModel.snapshot.status {
            XCTAssertEqual(userID, "user-1")
            XCTAssertEqual(email, "hello@example.com")
        } else {
            XCTFail("Expected authenticated snapshot")
        }
    }
}
