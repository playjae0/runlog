# Run Log — Codex Autonomous iOS Sprint

> 목적: 현재 Run Log iOS 앱을 Apple 기술 스택으로 안정화하고, 검증·문서화·GitHub 게시까지 한 번에 진행한다.  
> 대상 저장소: `https://github.com/playjae0/runlog.git`

---

## 1. 가장 중요한 제품 결정

이 프로젝트의 현재 우선순위는 **iOS 앱 완성**이다.

### 확정 사항

1. 현재 앱은 iOS 17+ SwiftUI 앱이다.
2. 건강·러닝 데이터는 HealthKit을 기준으로 한다.
3. 지도는 **Apple MapKit만 사용한다.**
4. iOS 앱에서 Google Maps SDK, Google Maps API 키, 지도 제공자 선택 기능은 제거한다.
5. Android 앱은 지금 구현하지 않는다.
6. Android는 iOS 핵심 기능이 안정화된 후 별도 기술검증을 거쳐 Go/No-Go를 결정한다.
7. Web, PWA, 서버, 소셜 기능도 이번 스프린트 범위가 아니다.

Google Maps 제거는 단순 코드 삭제가 아니다. Apple MapKit이 현재 기능을 모두 대체하는지 확인한 뒤 안전하게 진행한다.

---

## 2. 기준 문서와 사실 판단 순서

작업 전 다음 문서를 읽는다.

- `RUN_LOG_STATUS.md`
- `RUNFOLIO_ROADMAP.md` 또는 `RUN_LOG_ROADMAP.md`
- `README.md`

사실 판단 우선순위는 다음과 같다.

1. 실제 코드와 Xcode 프로젝트 설정
2. `RUN_LOG_STATUS.md`
3. 로드맵 문서
4. 기존 README

`Runfolio`는 과거 프로젝트명이며 현재 제품명은 **Run Log**다.

문서와 코드가 다르면 코드를 기준으로 판단하고 문서를 수정한다.

---

## 3. 자율 실행 원칙

이 작업은 분석만 하는 작업이 아니다.

다음 흐름을 반복한다.

```text
현재 상태 확인
→ 안전한 작업 선택
→ 구현
→ 테스트·빌드 검증
→ 문서 갱신
→ 커밋
→ 다음 작업 진행
```

안전하게 수행할 수 있는 작업은 사용자에게 매번 확인하지 말고 계속 진행한다.

다음 경우에만 해당 작업을 중단하거나 건너뛴다.

- API 키, 인증서, Apple Developer 서명 정보가 필요함
- GitHub 인증이 되어 있지 않음
- 사용자 데이터 삭제나 되돌리기 어려운 마이그레이션이 필요함
- 기존 미커밋 변경과 충돌해 사용자 작업을 훼손할 가능성이 있음
- 실제 기기에서만 검증 가능한 사항
- 제품 정책 결정이 반드시 필요함

한 작업이 막혀도 독립적으로 가능한 다음 작업은 계속한다.

---

## 4. 작업 시작 전 안전 점검

먼저 다음을 확인한다.

```bash
pwd
git status --short --branch
git remote -v
git branch --show-current
git log --oneline --decorate -20
git diff --stat
git diff --check
gh --version
gh auth status
xcodebuild -list
xcodebuild -showsdks
```

### 금지 사항

- `git reset --hard`
- `git checkout -- .`
- force push
- 기존 사용자 변경 되돌리기
- 출처를 모르는 파일 삭제
- API 키, 인증서, 개인 HealthKit 데이터 커밋
- 테스트하지 않은 상태를 성공으로 보고
- 무관한 사용자 변경까지 무조건 `git add -A`

현재 작업 트리에 미커밋 변경이 있으면 모두 사용자 작업으로 간주한다. 먼저 diff를 읽고 이번 작업과 충돌하지 않는 범위에서만 수정한다.

---

## 5. GitHub 게시 전략

원격 저장소는 다음을 사용한다.

```text
https://github.com/playjae0/runlog.git
```

### 로컬에 기존 Git 이력이 있으면

- 기존 이력을 유지한다.
- 원격 저장소가 비어 있다면 현재 이력을 그대로 `main`에 푸시한다.
- 기존 커밋을 squash, rebase, amend하지 않는다.

### 로컬에 커밋이 없으면

먼저 `.gitignore`와 비밀정보를 점검한다.

최소 제외 대상:

```gitignore
DerivedData/
.DerivedData/
*.xcuserstate
xcuserdata/
.build/
.swiftpm/
*.log
```

Google Maps API 키, 인증서, provisioning profile, 개인 데이터가 포함되지 않았는지 확인한다.

그 후 현재 프로젝트를 보존하는 초기 커밋을 만든다.

```text
Initial Run Log iOS application
```

초기 상태를 `main`에 푸시한 뒤 개선 작업 브랜치를 만든다.

```text
agent/runlog-ios-stabilization
```

이미 적절한 기능 브랜치라면 현재 브랜치를 유지해도 된다.

---

# 6. 실행 우선순위

## Phase A — Apple MapKit 단일화

### 목표

iOS 앱에서 Google Maps 의존성을 제거하고 Apple MapKit만으로 모든 지도 기능을 제공한다.

### 작업

1. Google Maps SDK가 사용되는 모든 파일과 프로젝트 설정을 찾는다.
2. 현재 Apple MapKit과 Google Maps의 기능 차이를 정리한다.
3. 다음 기능이 Apple MapKit에서 정상 동작하는지 확인한다.
   - 정적 전체 경로
   - 시작·종료 마커
   - 현재 위치 마커
   - 페이스별 색상 polyline
   - 경로 재생
   - 카메라 추적
   - cinematic 3D 카메라
   - 전체 경로 영역 맞춤
   - 월간 누적 경로
4. Google Maps에서만 존재하는 필수 기능이 없다면 다음을 제거한다.
   - Google Maps SDK 패키지
   - Google Maps import
   - Google 전용 지도 View와 coordinator
   - 지도 제공자 선택 UI
   - Google Maps API 키 설정
   - Google 전용 환경변수와 안내 문서
   - 사용되지 않는 Google 지도 코드
5. Apple MapKit을 기본이 아닌 유일한 지도 구현으로 정리한다.
6. 앱 기능과 디자인은 최대한 유지한다.
7. 패키지 제거 후 Xcode 프로젝트와 Swift Package 해석을 검증한다.

### 완료 기준

- Google Maps SDK 없이 프로젝트가 해석된다.
- 지도 제공자 선택 UI가 없다.
- Run Log의 모든 지도 화면이 Apple MapKit을 사용한다.
- 기존 Apple 지도 기능이 회귀하지 않는다.
- Google Maps API 키가 필요하지 않다.

### 권장 커밋

```text
Consolidate maps on Apple MapKit
```

---

## Phase B — 테스트 기반과 저장소 위생

### 작업

1. `.gitignore`를 점검하고 생성물을 제외한다.
2. XCTest 타깃 유무를 확인한다.
3. 없다면 프로젝트 구조를 해치지 않는 방식으로 테스트 타깃을 추가한다.
4. 다음 순수 계산을 테스트 가능한 구조로 만든다.
   - route 병합·정규화
   - 누적 거리
   - 경과 시간
   - 페이스 계산
   - 월·기간 경계
   - 다운샘플링
5. 테스트 타깃 추가가 위험하면 무리하게 `project.pbxproj`를 손대지 말고 가장 안전한 대안을 적용한다.

### 권장 커밋

```text
Add test foundation and repository hygiene
```

---

## Phase C — HealthKit route 정확성

### 핵심 문제

한 workout에 여러 `HKWorkoutRoute`가 있을 때 첫 번째 route만 사용하면 실제 경로 일부가 누락될 수 있다.

### 작업

1. workout에 속한 모든 `HKWorkoutRoute`를 조회한다.
2. 각 route의 모든 location batch를 수집한다.
3. 결과를 하나로 병합한다.
4. timestamp 기준으로 안정 정렬한다.
5. 유효하지 않은 위도·경도를 제거한다.
6. timestamp와 좌표가 모두 동일한 명백한 중복만 제거한다.
7. timestamp만 같거나 좌표만 같은 데이터는 함부로 제거하지 않는다.
8. 단일 route의 기존 동작을 유지한다.
9. 빈 결과와 route 없음 상태를 명확히 처리한다.
10. 취소와 오류가 올바르게 전달되게 한다.
11. 가능한 로직을 HealthKit과 분리된 순수 함수로 작성한다.

### 테스트

- 단일 route
- 여러 route 병합
- route 순서가 뒤집힌 입력
- timestamp 정렬
- 완전 동일 중복
- 같은 timestamp, 다른 좌표
- 같은 좌표, 다른 timestamp
- 유효하지 않은 좌표
- 빈 입력
- 단일 포인트
- 병합 전후 거리와 경과 시간

### 이번 단계에서 하지 않을 것

- Kalman filter
- map matching
- 공격적인 GPS smoothing
- 정지 구간 자동 삭제
- 원본 경로를 변경하는 과도한 보정

### 권장 커밋

```text
Merge and normalize HealthKit workout routes
```

---

## Phase D — 지표 의미와 리플레이 안정화

### 현재 페이스

현재 UI의 “현재 페이스”가 시작부터 현재까지 평균이라면 다음 중 하나로 바로잡는다.

1. 신뢰 가능한 이동 창 페이스를 계산한다.
2. 구현 신뢰성이 부족하면 라벨을 `현재까지 평균`으로 변경한다.

잘못된 의미를 가진 라벨을 유지하지 않는다.

### 통계 범위

최근 365일만 조회하면서 `전체`, `누적`이라고 표시하면 다음 중 안전한 방법을 선택한다.

- 실제 전체 기록 조회와 증분 캐시를 구현
- 현재 범위를 유지하고 `최근 1년`으로 표시

성능을 해치는 전체 조회를 억지로 구현하지 않는다.

### 리플레이

- 재생 중에만 timer/display update를 활성화한다.
- 일시정지와 화면 종료 시 정리한다.
- 재개 시 중복 timer가 생기지 않게 한다.
- tick 횟수보다 실제 기준 시각으로 진행 시간을 계산한다.
- slider 조작과 재생 상태가 충돌하지 않게 한다.
- background/foreground 전환을 검토한다.
- 남은 거리와 진행률 등 기존 데이터로 정확히 표시 가능한 지표를 보완한다.
- 지나치게 큰 View 파일에서는 테스트 가치가 높은 순수 계산만 우선 분리한다.

### 다운샘플링

단순 포인트 인덱스 샘플링을 검토하고, 안전하다면 시간 또는 거리 분포를 보존하도록 개선한다.

반드시 보존할 것:

- 시작점
- 종료점
- 원본 route 데이터
- 주요 방향 변화
- 재생 시간 의미

### 권장 커밋

```text
Correct run metrics and replay lifecycle
```

---

## Phase E — 월간 아카이브와 기록 탐색

앞 단계가 안정화된 후 진행한다.

### 월간 아카이브

- 이전 달·다음 달 이동
- 미래 월 이동 방지
- 최근 12개월 제한을 명확히 하거나 확장
- 월 경계 테스트
- 각 러닝 경로 구분
- 선택한 경로 강조
- 목록 선택과 지도 강조 동기화
- 지도 경로 선택과 목록 동기화
- route 없음·일부 실패·전체 실패 상태 구분

### 기록 탐색

현재 데이터로 의미 있게 구현 가능한 범위에서 다음을 진행한다.

- 최신순·오래된순
- 거리순
- 페이스순
- 기간 필터
- 거리 필터
- 고도 데이터가 신뢰 가능하면 표시
- route 존재 여부
- 평균 심박수 표시 일관성

실제 제목 데이터가 없으면 검색 UI를 억지로 추가하지 않는다.

### 권장 커밋

```text
Improve monthly archive and run history
```

---

## Phase F — 캐시·권한·문서

### 로컬 데이터

- route 영속 캐시 필요성을 검토한다.
- workout UUID 기준을 사용한다.
- schema version을 둔다.
- 손상 캐시는 복구 가능해야 한다.
- HealthKit을 원본 데이터로 유지한다.
- route 없음 negative cache에 재시도 또는 만료 정책을 둔다.
- 불완전한 캐시는 배포하지 않는다.

### HealthKit UX

다음 상태를 거짓 없이 구분한다.

- 첫 실행
- 권한 요청 절차 완료
- 데이터 없음
- 조회 실패
- 수동 새로고침
- 캐시 표시
- HealthKit 읽기 권한 상태를 직접 확정할 수 없는 플랫폼 제약

### 문서

다음을 실제 코드에 맞게 갱신한다.

- `RUN_LOG_STATUS.md`
- `RUN_LOG_ROADMAP.md`
- `README.md`

기존 `RUNFOLIO_ROADMAP.md`를 이름 변경한다면 `git mv`를 사용한다.

README에는 다음을 포함한다.

- Run Log 소개
- 현재 기능
- iOS 및 Xcode 요구사항
- HealthKit 권한
- Apple MapKit 사용
- 실행 방법
- 테스트 방법
- 알려진 제한
- 개인정보와 위치정보 주의
- 로드맵 링크

`RunHealthPrototype` 내부 명칭 변경은 signing, entitlement, bundle ID, 캐시 경로 영향을 분석한다. 안전하게 검증할 수 없으면 별도 후속 작업으로 남긴다.

### 권장 커밋

```text
Update Run Log data handling and documentation
```

---

# 7. Android 방침

## 이번 스프린트에서 Android 코드는 작성하지 않는다

SwiftUI, HealthKit, MapKit 코드는 Android에서 직접 재사용되지 않는다.

Android는 iOS 앱 완성 후 별도 프로젝트로 검토한다.

## iOS 안정화 후 작성할 문서

다음 파일만 작성할 수 있다.

```text
ANDROID_FEASIBILITY.md
```

이 문서는 구현 약속이 아니라 기술검증 계획이다.

최소 포함 내용:

- iOS 기능과 Android 대응 기술 매핑
  - SwiftUI → Jetpack Compose
  - HealthKit → Health Connect
  - MapKit → Android 지도 후보
  - HealthKit workout route → Health Connect exercise route
- Android 데이터 원본별 실제 경로 제공 가능성
- 삼성 Health, Fitbit, Garmin 등에서 Health Connect로 전달되는 데이터 차이
- 권한과 개인정보 요구사항
- 실제 삼성·Pixel 기기 검증 항목
- 지도 후보별 비용·라이선스·운영 부담
- iOS 로직 중 플랫폼 중립 모델로 분리 가능한 범위
- 예상 개발량
- Go/No-Go 기준

## Android Go 조건

다음이 확인되기 전에는 Android 개발을 시작하지 않는다.

1. iOS 핵심 기능과 테스트가 안정적이다.
2. Android 실제 기기에서 운동 세션과 GPS route를 읽을 수 있다.
3. 필요한 데이터 원본 앱이 route를 Health Connect에 제공한다.
4. 지도 기술과 운영 비용이 결정됐다.
5. 공통 데이터 모델이 정의됐다.
6. iOS와 동일 기능이 필요한지 MVP 범위가 합의됐다.

Android 버전은 기술적으로 검토 가능하지만, iOS 앱을 그대로 변환하는 작업은 아니다.

---

# 8. 검증 기준

각 단계마다 가능한 검증을 실행한다.

```bash
git diff --check
xcodebuild -list
xcodebuild -showsdks
xcrun swiftc -frontend -parse <실제 Swift 파일 경로>
```

가능하면 실제 project, scheme, destination을 확인한 뒤 실행한다.

```bash
xcodebuild test
xcodebuild build
```

결과는 반드시 다음으로 구분한다.

- 성공
- 코드 문제로 실패
- Xcode·SDK·Simulator 환경 문제로 실행 불가
- 실제 기기 검증 필요

환경 문제를 코드 성공으로 표현하지 않는다.

---

# 9. 커밋과 푸시

각 Phase가 독립적으로 완료되고 검증 가능한 상태가 되면 커밋한다.

커밋 전:

```bash
git status --short
git diff --stat
git diff --check
git diff
```

무관한 사용자 변경은 stage하지 않는다.

예상 커밋:

```text
Initial Run Log iOS application
Consolidate maps on Apple MapKit
Add test foundation and repository hygiene
Merge and normalize HealthKit workout routes
Correct run metrics and replay lifecycle
Improve monthly archive and run history
Update Run Log data handling and documentation
```

실제로 완료한 작업만 커밋한다.

작업 브랜치를 푸시한다.

```bash
git push -u origin "$(git branch --show-current)"
```

가능하면 draft PR을 만든다.

PR 제목:

```text
Stabilize the Run Log iOS application
```

PR 본문:

- 변경 내용
- 변경 이유
- 사용자 영향
- 데이터 정확성 개선
- 테스트 및 빌드 결과
- 환경 제한
- 남은 작업
- Android가 이번 범위에서 제외된 이유

---

# 10. 종료 조건과 최종 보고

분석이나 계획만 작성하고 종료하지 않는다.

안전하게 가능한 Phase를 순서대로 계속 수행한다.

```text
A → B → C → D → E → F
```

한 Phase가 막히면 이유를 기록하고 다음 독립 작업으로 넘어간다.

마지막에 다음을 보고한다.

## 완료한 작업

## 사용자에게 보이는 변화

## 수정 파일

## 테스트와 빌드

## Git 커밋

## Push 및 PR

## 남아 있는 미커밋 변경

## 남은 P0/P1/P2

## Android Go/No-Go 검토 시점

최종적으로 실행한다.

```bash
git status --short --branch
git log --oneline --decorate -15
```
