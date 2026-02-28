# 입채 (IPCHAE) Starter Scaffold Catalog Spec

## 1. 목표
초등학생이 첫 60초 안에 캐릭터 베이스를 만들 수 있도록, 즉시 시작 가능한 템플릿/파츠 재료를 제공한다.

---

## 2. MVP 수량 목표
1. Starter Pack: 최소 8개
2. Template: 최소 40개
3. Official Parts: 최소 220개

권장 목표:
1. Starter Pack 10개
2. Template 60개
3. Official Parts 350개

---

## 3. 카탈로그 구조
1. Pack: 스타일 분류 단위
2. Template: 바로 삽입 가능한 시작 몸체
3. Official Part: 운영팀 제공 파츠
4. Community Part: 유저 공개 파츠
5. Slot: 파츠 결합 기준 위치

관계:
1. Pack 1:N Template
2. Template 1:N Default Part
3. Template 1:N Slot
4. Slot N:N Part(호환 규칙)

---

## 4. 초기 Pack 구성

| pack_slug | 이름 | 최소 템플릿 | 핵심 목적 |
|---|---:|---:|---|
| `nendo_core` | Chibi Nendo Core | 8 | 큰 머리-작은 몸 베이스 |
| `mome_soft` | Soft Mome | 6 | 둥근 볼륨 모에 스타일 |
| `minecraft_blocky` | Minecraft Blocky | 6 | 복셀/각진 체형 빠른 생성 |
| `roblox_blocky` | Roblox Blocky | 6 | 블록형/모듈형 캐릭터 |
| `animal_friends` | Animal Friends | 4 | 동물형 빠른 생성 |
| `robot_toy` | Robot Toy | 4 | 로봇/기계 캐릭터 |
| `fantasy_mini` | Fantasy Mini | 3 | 판타지 소품 캐릭터 |
| `accessory_booster` | Accessory Booster | 3 | 헤어/모자/소품 강화 |

---

## 5. Template 상세 명세

### 5.1 필수 필드
1. `id`
2. `pack_id`
3. `slug`
4. `name`
5. `target_style`
6. `difficulty`
7. `base_scene_path`
8. `preview_image_path`
9. `default_scale`
10. `default_proportion`
11. `part_slots`

### 5.2 비율 파라미터
1. `headRatio` 범위: 1.0 ~ 2.1
2. `bodyRatio` 범위: 0.8 ~ 1.4
3. `legRatio` 범위: 0.45 ~ 1.25

### 5.3 Slot 키 규칙
1. `head_top`
2. `head_left`
3. `head_right`
4. `face_center`
5. `body_front`
6. `body_back`
7. `arm_l`
8. `arm_r`
9. `leg_l`
10. `leg_r`
11. `prop_mount`
12. `voxel_grid_anchor`

---

## 6. Part 상세 명세

### 6.1 분류
1. `core`
2. `face`
3. `hair`
4. `outfit`
5. `accessory`
6. `joint`
7. `voxel`

### 6.2 카테고리(브라우징 기준)
1. Head
2. Face
3. Hair
4. Torso
5. Arm/Hand
6. Leg/Foot
7. Outfit
8. Props
9. Joint/Snap
10. Voxel Blocks

### 6.3 필수 필드
1. `part_key`
2. `display_name`
3. `part_kind`
4. `primitive_type`
5. `default_transform`
6. `editable_params`
7. `mirror_group`(선택)
8. `style_family`
9. `compatibility_slots`

### 6.4 파츠 적용 규칙
1. slot 타입이 맞지 않으면 스냅 불가
2. 좌우 파츠는 `mirror_group`으로 동시 적용
3. 파츠 적용 후 Undo 1스텝으로 롤백 가능
4. 복셀 파츠는 `voxel_grid_anchor` 기준 정렬

---

## 7. UX 동작 사양

### 7.1 홈 퀵스타트
1. `Blank`
2. `Free Draw First`
3. `Start with Starter`

### 7.2 Starter Drawer
1. 상단: 스타일 탭(Nendo/Moe/Minecraft/Roblox/기타)
2. 중앙: Template 카드 그리드
3. 하단: Default Part strip
4. 우측: 비율 슬라이더 + 적용 버튼

### 7.3 Parts Browser
1. 카테고리 사이드바
2. 필터 바(스타일/난이도/작성자/정렬)
3. 검색 입력(이름/태그)
4. 카드 리스트(썸네일/작성자/가시성)
5. `Apply`, `Save`, `Publish` 액션

### 7.4 시간 목표
1. 앱 진입 -> 템플릿 선택: 30초 이내
2. 템플릿 선택 -> 조형 시작 가능: 3초 이내
3. 첫 캐릭터 베이스 완성: 60초 이내

---

## 8. 데이터/캐시 사양
1. 원본: Supabase `starter_*`, `part_categories`, `parts`
2. 에셋: `starter-assets`, `part-files`, `part-preview`
3. 로컬 캐시 키:
4. `starterCatalog:v{version}`
5. `partCatalog:v{version}`
6. 실패 fallback: 앱 번들 JSON
7. 갱신 방식: 앱 시작 시 버전 비교 후 교체

---

## 9. 운영 사양
1. Starter 데이터 write는 admin/service role만 수행
2. Official Part write도 admin/service role만 수행
3. 유저 파츠 기본 가시성은 `private`
4. `public` 전환 시 자동 품질 검사 + 최소 메타 검증
5. 비활성화는 `is_active=false` soft disable
6. 시즌 팩은 `sort_order`와 `tags`로 노출 제어

---

## 10. 수용 기준(DoD)
1. 최소 8/40/220 수량 달성
2. Minecraft/Roblox 스타터 각각 최소 6개 템플릿 제공
3. 카테고리/필터/검색으로 파츠 탐색 가능
4. 초등학생 사용자 5명 중 4명 이상이 60초 내 베이스 생성 성공
5. 오프라인 상태에서도 Starter 시작 가능
6. 템플릿 적용 후 Draw/Build/Polish 연속 흐름 끊김 없음
