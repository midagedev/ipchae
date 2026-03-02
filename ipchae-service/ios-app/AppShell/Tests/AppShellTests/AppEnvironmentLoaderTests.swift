import AppShell
import XCTest

final class AppEnvironmentLoaderTests: XCTestCase {
    func testInitWithExplicitValues() {
        let env = AppEnvironment(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseAnonKey: "anon",
            magicLinkRedirectURL: URL(string: "ipchae://auth-callback")
        )

        XCTAssertEqual(env.supabaseURL.absoluteString, "https://example.supabase.co")
        XCTAssertEqual(env.supabaseAnonKey, "anon")
        XCTAssertEqual(env.magicLinkRedirectURL?.absoluteString, "ipchae://auth-callback")
    }
}
