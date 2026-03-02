# IPCHAE 장기작업 오케스트레이션 운영 매뉴얼

기준일: 2026-03-01  
대상 레포: `/Users/hckim/repo/ipchae/ipchae-service`

## 1. 목적
이 문서는 "Apple-native-first 앱 리라이트"를 장기 실행할 때,
1. 작업을 구체화하고
2. 병렬 트랙을 충돌 없이 운용하며
3. 컨텍스트 손실 없이 루프를 반복하는
실행 표준을 정의한다.

## 2. 핵심 원칙
1. **작은 루프, 짧은 검증**: 하루 단위 루프로 계획/구현/검증/기록을 닫는다.
2. **결정은 즉시 문서화**: 설계/정책 결정은 ADR로 남겨 재논의 비용을 줄인다.
3. **컨텍스트는 파일에 고정**: 상태를 채팅 기억에 의존하지 않고 레포 문서에 저장한다.
4. **WIP 제한**: 동시에 진행 중인 in-progress 항목은 트랙당 1개로 제한한다.
5. **관측 가능성 우선**: 모든 루프는 테스트 결과와 메트릭(성공/실패 사유)을 남긴다.

## 3. 오케스트레이션 아티팩트 (Single Source of Truth)
1. 전략/구조: `/Users/hckim/repo/ipchae/ipchae-service/APPLE_NATIVE_FIRST_APP_REWRITE_ORCHESTRATION_PLAN.md`
2. 운영 매뉴얼(본 문서): `/Users/hckim/repo/ipchae/ipchae-service/docs/orchestration/LONG_RUNNING_ORCHESTRATION_PLAYBOOK.md`
3. 현재 상태: `/Users/hckim/repo/ipchae/ipchae-service/docs/orchestration/context/PROGRAM_STATE.md`
4. 백로그: `/Users/hckim/repo/ipchae/ipchae-service/docs/orchestration/context/BACKLOG.md`
5. 결정 기록(ADR): `/Users/hckim/repo/ipchae/ipchae-service/docs/orchestration/context/DECISIONS.md`
6. 루프 실행 로그: `/Users/hckim/repo/ipchae/ipchae-service/docs/orchestration/context/LOOP_LOG.md`

## 4. 루프 실행 프로토콜
각 루프는 아래 8단계를 순서대로 수행한다.

1. **Load**: 컨텍스트 4종(`PROGRAM_STATE`, `BACKLOG`, `DECISIONS`, `LOOP_LOG`)을 읽는다.
2. **Select**: 우선순위가 가장 높은 "Ready" 작업 1~3개를 선택한다.
3. **Contract**: 스키마/인터페이스 변화가 있으면 먼저 ADR과 계약 파일부터 수정한다.
4. **Build**: 코드/문서/스크립트 구현.
5. **Verify**: 최소 검증 세트 실행 (`npm run test`, `npm run check`, Swift 테스트).
6. **Record**: 결과를 `LOOP_LOG`에 남기고 `PROGRAM_STATE`를 갱신한다.
7. **Reorder**: `BACKLOG` 상태와 우선순위를 재정렬한다.
8. **Handoff**: 다음 루프에서 바로 실행할 "Next 3"를 명시한다.

## 5. 컨텍스트 관리 규칙
1. **요약 저장 규칙**: 긴 논의는 최대 10줄의 요약으로 `PROGRAM_STATE`에 남긴다.
2. **변경 근거 링크**: 모든 결정은 파일 경로/커밋/테스트 결과를 같이 기록한다.
3. **결정-실행 분리**: "왜"는 `DECISIONS`, "무엇/언제"는 `BACKLOG`, "무슨 결과"는 `LOOP_LOG`에 기록한다.
4. **재현 가능성**: 명령은 복붙 실행 가능 형태로 기록한다.
5. **중단 복구**: 중단 시 `PROGRAM_STATE`의 "Recovery" 섹션만 읽고 바로 재개 가능해야 한다.

## 6. 병렬 트랙 운영 규칙
1. 트랙: W0(거버넌스), W1(에디터 커널), W2(도메인 포팅), W3(데이터/Supabase), W4(App Shell), W5(QA/Perf), W6(Android 준비).
2. 브랜치: `codex/w{트랙번호}-{topic}`.
3. 계약 우선: 계약 변경 PR이 기능 PR보다 먼저 병합되어야 한다.
4. 충돌 방지: 공통 파일은 하루 1회 통합 창구에서만 수정한다.
5. 병합 게이트: 테스트/타입체크/필수 스모크 실패 시 병합 금지.

## 7. 품질 게이트
1. **Gate 0 (항상)**: `npm run test`, `npm run check` 통과.
2. **Gate A (초기 iOS 스파이크)**: 에디터 스파이크 벤치 리포트 생성.
3. **Gate B (코어 MVP)**: 편집-저장-복원-내보내기 E2E 경로 통과.
4. **Gate C (제품 기능)**: Share/Parts/Collab 핵심 경로 통합 테스트 통과.
5. **Gate D (릴리즈 후보)**: 성능/안정성 기준 통과 + 배포 체크리스트 완료.

## 8. 루프 완료 정의 (Loop DoD)
각 루프는 아래를 모두 충족해야 완료로 간주한다.
1. 산출물 파일/코드가 실제로 반영됨.
2. 검증 명령 결과가 기록됨.
3. 백로그 상태가 업데이트됨.
4. 다음 루프의 시작점이 명확함.

## 9. 운영 체크리스트 (매 루프 시작/종료)
시작:
1. `PROGRAM_STATE` 읽기
2. `BACKLOG`에서 Ready 1~3 선택
3. 위험요소/의존성 확인

종료:
1. 테스트 실행
2. `LOOP_LOG` 기록
3. `PROGRAM_STATE` 갱신
4. `BACKLOG` 재정렬

## 10. 참고 자료
1. Scrum Guide (반복 개발과 백로그 관리): [https://scrumguides.org/scrum-guide.html](https://scrumguides.org/scrum-guide.html)
2. ADR Practice (결정 기록 패턴): [https://www.atlassian.com/architecture/architecture-decision-record](https://www.atlassian.com/architecture/architecture-decision-record)
3. Google SRE (toil 감소와 자동화 원칙): [https://sre.google/sre-book/eliminating-toil/](https://sre.google/sre-book/eliminating-toil/)
4. OpenAI tracing docs (에이전트 실행 관측): [https://platform.openai.com/docs/guides/tracing](https://platform.openai.com/docs/guides/tracing)

