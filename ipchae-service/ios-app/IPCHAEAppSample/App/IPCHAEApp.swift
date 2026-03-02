import AppShell
import Foundation
import SwiftUI

@main
struct IPCHAEApp: App {
    private let viewModel: AuthViewModel
    private let pricingTelemetrySink: (any PricingTelemetrySinkProtocol)?

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-reset-defaults") {
            let bundleID = Bundle.main.bundleIdentifier ?? "com.ipchae.sample"
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        let appEnvironment = try? AppEnvironmentLoader.fromProcessEnvironment()
        viewModel = AuthViewModel(service: IPCHAEApp.makeAuthService(appEnvironment: appEnvironment))
        pricingTelemetrySink = appEnvironment.map {
            SupabasePricingTelemetrySink(environment: $0, appBuild: "ipchae-ios-sample")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootAppView(viewModel: viewModel, pricingTelemetrySink: pricingTelemetrySink)
        }
    }

    private static func makeAuthService(appEnvironment: AppEnvironment?) -> any AuthServiceProtocol {
        guard let appEnvironment else {
            return FallbackAuthService()
        }
        return SupabaseAuthService(environment: appEnvironment)
    }
}

private actor FallbackAuthService: AuthServiceProtocol {
    func sendMagicLink(email: String) async throws {}

    func signOut() async throws {}

    func refreshAuthSnapshot() async -> AuthSnapshot {
        .anonymous
    }

    func handleOpenURL(_ url: URL) async -> AuthSnapshot {
        .anonymous
    }
}
