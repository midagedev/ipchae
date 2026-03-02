import Foundation

public struct AppEnvironment: Sendable, Equatable {
    public var supabaseURL: URL
    public var supabaseAnonKey: String
    public var magicLinkRedirectURL: URL?

    public init(supabaseURL: URL, supabaseAnonKey: String, magicLinkRedirectURL: URL? = nil) {
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
        self.magicLinkRedirectURL = magicLinkRedirectURL
    }
}

public enum AppEnvironmentError: Error {
    case missingValue(String)
    case invalidURL(String)
}

public enum AppEnvironmentLoader {
    // Reads from process env for local/dev automation.
    // iOS app target should map this from secure runtime config (plist/remote config).
    public static func fromProcessEnvironment() throws -> AppEnvironment {
        let env = ProcessInfo.processInfo.environment

        guard let urlText = env["SUPABASE_URL"], !urlText.isEmpty else {
            throw AppEnvironmentError.missingValue("SUPABASE_URL")
        }
        guard let key = env["SUPABASE_ANON_KEY"], !key.isEmpty else {
            throw AppEnvironmentError.missingValue("SUPABASE_ANON_KEY")
        }
        guard let url = URL(string: urlText) else {
            throw AppEnvironmentError.invalidURL("SUPABASE_URL")
        }

        let redirectURL: URL?
        if let redirectText = env["APP_MAGIC_LINK_REDIRECT_URL"], !redirectText.isEmpty {
            redirectURL = URL(string: redirectText)
        } else {
            redirectURL = nil
        }

        return AppEnvironment(
            supabaseURL: url,
            supabaseAnonKey: key,
            magicLinkRedirectURL: redirectURL
        )
    }
}
