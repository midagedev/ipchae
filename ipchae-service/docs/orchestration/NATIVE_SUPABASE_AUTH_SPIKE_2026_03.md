# Native Supabase Auth Spike (iOS/iPadOS)

Date: 2026-03-01

## 1. Goal
1. Add a native auth scaffold for Apple-first app
2. Keep implementation testable and decoupled from UI
3. Prepare OTP magic-link login flow for Phase B

## 2. Implemented
1. `ios-app/AppShell` Swift package created
2. Supabase client-backed auth service scaffold added:
   1. `sendMagicLink(email)`
   2. `signOut()`
   3. `refreshAuthSnapshot()` with current session/user lookup + refresh attempt
   4. `handleOpenURL(_:)` callback handling via `supabase.auth.session(from:)`
3. SwiftUI minimal shell added:
   1. `AuthScreen`
   2. `HomeScreen`
   3. `RootAppView`
4. ViewModel tests added for auth interaction

## 3. Open Items
1. URL callback handler wiring in actual iOS app target lifecycle (package 밖)
2. session restoration from secure storage 정책 명확화
3. OTP verification UX(만료/오류) 상세 처리
4. telemetry events for auth funnel

## 4. Sources
1. Supabase Swift docs: [https://supabase.com/docs/reference/swift/introduction](https://supabase.com/docs/reference/swift/introduction)
2. Supabase Swift auth sign-in docs: [https://supabase.com/docs/reference/swift/v1/auth-signinwithotp](https://supabase.com/docs/reference/swift/v1/auth-signinwithotp)
3. Supabase Swift auth sign-out docs: [https://supabase.com/docs/reference/swift/auth-signout](https://supabase.com/docs/reference/swift/auth-signout)
