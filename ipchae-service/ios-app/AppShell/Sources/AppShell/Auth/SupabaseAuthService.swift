import Foundation
import Supabase

public actor SupabaseAuthService: AuthServiceProtocol {
    private let environment: AppEnvironment
    private let client: SupabaseClient

    public init(environment: AppEnvironment) {
        self.environment = environment
        self.client = SupabaseClient(
            supabaseURL: environment.supabaseURL,
            supabaseKey: environment.supabaseAnonKey
        )
    }

    public func sendMagicLink(email: String) async throws {
        try await client.auth.signInWithOTP(
            email: email,
            redirectTo: environment.magicLinkRedirectURL
        )
    }

    public func signOut() async throws {
        try await client.auth.signOut()
    }

    public func refreshAuthSnapshot() async -> AuthSnapshot {
        do {
            if let currentUser = client.auth.currentUser {
                if let session = client.auth.currentSession, session.isExpired {
                    let refreshed = try await client.auth.session
                    return mapSnapshot(userID: refreshed.user.id, email: refreshed.user.email)
                }
                return mapSnapshot(userID: currentUser.id, email: currentUser.email)
            }

            let session = try await client.auth.session
            return mapSnapshot(userID: session.user.id, email: session.user.email)
        } catch {
            return .anonymous
        }
    }

    public func handleOpenURL(_ url: URL) async -> AuthSnapshot {
        do {
            _ = try await client.auth.session(from: url)
            return await refreshAuthSnapshot()
        } catch {
            return .anonymous
        }
    }

    private func mapSnapshot(userID: any CustomStringConvertible, email: String?) -> AuthSnapshot {
        AuthSnapshot(status: .authenticated(userID: String(describing: userID), email: email))
    }
}
