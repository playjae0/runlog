# Run Log

Run Log는 Apple Health의 러닝 기록을 불러와 경로, 페이스, 기간별 통계와 월간 아카이브로 보여주는 iPhone용 SwiftUI 앱입니다.

## 현재 기능

- 최근 1년 HealthKit running workout과 평균 심박수 조회
- 최근 러닝, 최근 1년·월·연도·7일·30일 통계
- 러닝 목록과 날짜·거리·시간·평균 페이스·심박수 상세
- Apple MapKit 경로, 시작·종료 마커와 최근 경로 미리보기
- timestamp 기반 경로 리플레이, 타임라인, 10x/20x/40x 배속
- 현재 위치, 페이스별 3색 경로, 카메라 추적과 cinematic 모드
- 경과 시간, 누적·남은 거리, 현재까지 평균 페이스, 진행률
- 최근 24개월 월간 요약과 누적 경로, 기록 선택·강조
- 최신·오래된·거리·페이스순 기록 정렬
- workout 요약 디스크 캐시와 route 세션 캐시

지도는 Apple MapKit만 사용하며 Google Maps SDK나 API 키가 필요하지 않습니다.

## 요구사항

- Xcode 15 이상
- iOS 17 이상을 실행하는 iPhone
- Apple Health에 저장된 러닝 workout
- Signing & Capabilities의 HealthKit 권한

HealthKit route와 실제 권한 동작은 실기기에서 확인해야 합니다. 실내 러닝 또는 원본 앱이 GPS 경로를 HealthKit에 저장하지 않은 workout에는 route가 없을 수 있습니다.

## 실행 방법

1. `RunHealthPrototype.xcodeproj`를 Xcode에서 엽니다.
2. `RunHealthPrototype` scheme을 선택합니다.
3. Signing Team과 고유 Bundle Identifier를 설정합니다.
4. iOS 17+ 실제 iPhone을 연결해 실행합니다.
5. 앱 설정에서 `Health 권한 요청`을 누르고 읽기 권한 절차를 완료합니다.
6. 권한 요청 뒤 최근 1년 러닝이 자동으로 갱신됩니다. 이후에는 설정의 새로고침 버튼을 사용할 수 있습니다.

앱 표시명은 RunLog지만 Xcode 프로젝트·타깃 내부 이름은 기존 호환성을 위해 아직 `RunHealthPrototype`을 유지합니다.

## 테스트

프로젝트에는 `RunHealthPrototypeTests` XCTest 타깃이 있습니다. 정상적인 iOS Simulator가 설치된 환경에서 다음 명령을 사용할 수 있습니다.

```bash
xcodebuild \
  -project RunHealthPrototype.xcodeproj \
  -scheme RunHealthPrototype \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

현재 테스트 범위는 route 병합·정규화, 누적 거리, 경과 시간, 다운샘플링, 월 경계를 포함합니다. HealthKit 조회와 지도 카메라 동작은 실기기 수동 검증이 추가로 필요합니다.

## 캐시와 데이터

- HealthKit이 원본 데이터입니다.
- 최근 workout 요약은 Application Support 아래 JSON 캐시에 저장됩니다.
- 캐시는 schema version이 다르거나 손상되면 비어 있는 상태로 복구됩니다.
- route 좌표는 현재 디스크에 영속 저장하지 않고 앱 세션 메모리에서만 캐시합니다.
- route 없음 결과는 10분 뒤 다시 조회할 수 있습니다.

## 알려진 제한

- 조회·통계 범위는 최근 365일입니다.
- 월간 아카이브 선택 범위는 최근 24개월입니다.
- 이동 창 순간 페이스가 아니라 시작부터 현재 지점까지의 평균을 표시합니다.
- GPS 점프, map matching, 정지 구간 자동 제거는 적용하지 않습니다.
- 지도 경로 선을 직접 눌러 목록을 선택하는 기능은 아직 없습니다.
- 서버, 계정, Web/PWA, Android, 소셜, 자체 GPS 측정은 현재 범위가 아닙니다.

## 개인정보와 위치정보

러닝 경로와 운동·심박수 정보는 민감한 건강·위치 데이터입니다. 앱은 필요한 HealthKit 읽기 권한만 요청하고 HealthKit을 원본으로 유지합니다. 위치 공유, 서버 업로드, 집·회사 주변 경로 공개 같은 기능을 추가하기 전에는 별도 개인정보·공개 범위 정책이 필요합니다.

## 문서

- [현재 개발 현황](RUN_LOG_STATUS.md)
- [Codex iOS Sprint](RUN_LOG_CODEX_SPRINT.md)
- [장기 로드맵](RUNFOLIO_ROADMAP.md)
