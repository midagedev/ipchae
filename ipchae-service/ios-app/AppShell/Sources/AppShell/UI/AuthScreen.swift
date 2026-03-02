import SwiftUI

private struct PlatformEmailFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
        #else
        content
        #endif
    }
}

public struct AuthScreen: View {
    @StateObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: @autoclosure @escaping () -> AuthViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("IPCHAE")
                .font(.largeTitle.bold())

            Text("이메일로 로그인 링크를 받아 시작하세요.")
                .foregroundStyle(.secondary)

            Button("게스트로 계속 사용") {
                dismiss()
            }
            .buttonStyle(.bordered)

            TextField("you@example.com", text: $viewModel.email)
                .modifier(PlatformEmailFieldModifier())
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button(action: {
                Task { await viewModel.requestMagicLink() }
            }) {
                Text(viewModel.loading ? "전송 중..." : "로그인 링크 전송")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.loading)

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .task {
            await viewModel.refresh()
        }
    }
}
