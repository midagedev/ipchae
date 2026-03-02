import SwiftUI

public struct RootAppView: View {
    @StateObject private var viewModel: AuthViewModel
    @State private var showAuthSheet: Bool = false
    private let pricingTelemetrySink: (any PricingTelemetrySinkProtocol)?

    public init(
        viewModel: @autoclosure @escaping () -> AuthViewModel,
        pricingTelemetrySink: (any PricingTelemetrySinkProtocol)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.pricingTelemetrySink = pricingTelemetrySink
    }

    public var body: some View {
        Group {
            switch viewModel.snapshot.status {
            case .authenticated(let userID, let email):
                HomeScreen(
                    email: email,
                    userID: userID,
                    isGuest: false,
                    pricingTelemetrySink: pricingTelemetrySink
                ) {
                    Task { await viewModel.signOut() }
                }
            case .unavailable, .anonymous:
                HomeScreen(
                    email: nil,
                    userID: "guest-local",
                    isGuest: true,
                    pricingTelemetrySink: nil,
                    onRequestSignIn: {
                        showAuthSheet = true
                    },
                    onSignOut: {}
                )
            }
        }
        .onOpenURL { url in
            Task { await viewModel.handleOpenURL(url) }
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthScreen(viewModel: viewModel)
        }
    }
}
