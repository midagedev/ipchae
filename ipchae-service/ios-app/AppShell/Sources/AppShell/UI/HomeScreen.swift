import SwiftUI

public struct HomeScreen: View {
    private let email: String?
    private let isGuest: Bool
    @StateObject private var pricingViewModel: PricingGateViewModel
    @State private var showStudioSandbox: Bool = false
    @AppStorage("ipchae.guest.did-autostart-studio.v1") private var didAutostartGuestStudio: Bool = false
    private let onRequestSignIn: (() -> Void)?
    private let onSignOut: () -> Void

    public init(
        email: String?,
        userID: String,
        isGuest: Bool = false,
        pricingTelemetrySink: (any PricingTelemetrySinkProtocol)? = nil,
        onRequestSignIn: (() -> Void)? = nil,
        onSignOut: @escaping () -> Void
    ) {
        self.email = email
        self.isGuest = isGuest
        _pricingViewModel = StateObject(
            wrappedValue: PricingGateViewModel(
                userID: userID,
                telemetrySink: pricingTelemetrySink
            )
        )
        self.onRequestSignIn = onRequestSignIn
        self.onSignOut = onSignOut
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("IPCHAE Studio")
                .font(.largeTitle.bold())

            Text(sessionLabel)
                .foregroundStyle(.secondary)

            Text("Apple-native-first rewrite in progress")
                .font(.headline)

            if isGuest {
                VStack(alignment: .leading, spacing: 8) {
                    Text("게스트 모드")
                        .font(.subheadline.weight(.semibold))
                    Text("지금 바로 핵심 기능을 써보고, 원할 때 계정을 연결하세요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let onRequestSignIn {
                        Button("계정 연결하기") {
                            onRequestSignIn()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Button(isGuest ? "지금 바로 스튜디오 시작" : "스튜디오 시작") {
                showStudioSandbox = true
            }
            .buttonStyle(.borderedProminent)

            VStack(alignment: .leading, spacing: 10) {
                Text("Pricing Gate Demo (Free tier)")
                    .font(.subheadline.weight(.semibold))

                Button("Try Advanced Export") {
                    Task { await pricingViewModel.attemptAction(.exportAdvancedFormat) }
                }
                .buttonStyle(.borderedProminent)

                Button("Try Share Link (at free limit)") {
                    Task { await pricingViewModel.attemptAction(.createShareLink) }
                }
                .buttonStyle(.bordered)
            }

            if !pricingViewModel.statusMessage.isEmpty {
                Text(pricingViewModel.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isGuest {
                if let onRequestSignIn {
                    Button("로그인/가입", action: onRequestSignIn)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                Button("Sign Out", action: onSignOut)
                    .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(20)
        .sheet(isPresented: $pricingViewModel.showPaywall) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upgrade Required")
                    .font(.title3.bold())
                Text(pricingViewModel.pendingDecision?.reasonCode ?? "upgrade_required")
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Later") {
                        pricingViewModel.dismissPaywall()
                    }
                    .buttonStyle(.bordered)

                    Button("Upgrade") {
                        Task { await pricingViewModel.tapUpgrade() }
                        pricingViewModel.dismissPaywall()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        .modifier(StudioSandboxPresenter(isPresented: $showStudioSandbox))
        .onAppear {
            guard isGuest else { return }
            guard !didAutostartGuestStudio else { return }
            didAutostartGuestStudio = true
            showStudioSandbox = true
        }
    }

    private var sessionLabel: String {
        if isGuest {
            return "Guest session"
        }
        return email.map { "Logged in as \($0)" } ?? "Logged in"
    }
}

private struct StudioSandboxPresenter: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: $isPresented) {
            StudioSandboxView()
        }
        #else
        content.sheet(isPresented: $isPresented) {
            StudioSandboxView()
        }
        #endif
    }
}
