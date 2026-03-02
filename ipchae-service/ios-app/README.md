# iOS App Workspace (Apple Native First)

이 디렉토리는 IPCHAE의 Apple-native-first 리라이트 작업 공간입니다.

## 현재 포함
1. `CoreDomain` Swift Package
   1. Studio snapshot 계약
   2. Validation 서비스
   3. SyncQueue(actor) 포팅
   4. Editor spike benchmark CLI
2. `AppShell` Swift Package
   1. Supabase auth scaffold (magic link/sign out)
   2. SwiftUI 최소 화면(Auth/Home/Root)
   3. AuthViewModel 테스트

## 실행 방법
```bash
swift test --package-path ios-app/CoreDomain
swift run --package-path ios-app/CoreDomain EditorSpikeCLI --strokes 120 --points 120 --undo-ratio 0.2
swift test --package-path ios-app/AppShell
```

## 오케스트레이션 문서
1. `/Users/hckim/repo/ipchae/ipchae-service/APPLE_NATIVE_FIRST_APP_REWRITE_ORCHESTRATION_PLAN.md`
2. `/Users/hckim/repo/ipchae/ipchae-service/docs/orchestration/LONG_RUNNING_ORCHESTRATION_PLAYBOOK.md`
3. `/Users/hckim/repo/ipchae/ipchae-service/docs/orchestration/context/PROGRAM_STATE.md`
