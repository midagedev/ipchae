import Foundation

public enum AuthStatus: Sendable, Equatable {
    case unavailable
    case anonymous
    case authenticated(userID: String, email: String?)
}

public struct AuthSnapshot: Sendable, Equatable {
    public var status: AuthStatus

    public init(status: AuthStatus) {
        self.status = status
    }

    public static let unavailable = AuthSnapshot(status: .unavailable)
    public static let anonymous = AuthSnapshot(status: .anonymous)
}

public protocol AuthServiceProtocol: Sendable {
    func sendMagicLink(email: String) async throws
    func signOut() async throws
    func refreshAuthSnapshot() async -> AuthSnapshot
    func handleOpenURL(_ url: URL) async -> AuthSnapshot
}
