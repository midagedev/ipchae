# IPCHAE iOS App Sample Target

이 디렉토리는 AppShell deep-link lifecycle 연결을 위한 최소 iOS 앱 타깃 스캐폴드입니다.

## 생성 방법
```bash
./scripts/ios/generate_xcodeproj.sh
```

## 실행 전 환경변수
1. `SUPABASE_URL`
2. `SUPABASE_ANON_KEY`
3. optional: `APP_MAGIC_LINK_REDIRECT_URL` (예: `ipchae://auth-callback`)

## 핵심 경로
1. `App/IPCHAEApp.swift` - RootAppView 연결
2. `RootAppView`의 `.onOpenURL`에서 Supabase callback 처리

## Deep Link E2E (Simulator)
```bash
xcrun simctl openurl booted "ipchae://auth-callback#access_token=fake&refresh_token=fake&type=magiclink"
```

## 주의
1. 이 샘플은 orchestration 목적의 최소 구성이다.
2. 실제 프로덕션 앱에서는 보안 저장소/환경 주입/테스트 키 분리가 필요하다.
