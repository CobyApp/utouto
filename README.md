# うとうと (Utotōto) - モーニングコールアプリ

iOS 17+向けの感情 몰입형 모닝콜 알람 앱입니다. SwiftUI + TCA(The Composable Architecture)로 구현되었습니다.

## 주요 기능

- **알람 CRUD**: 시간, 반복 요일, 라벨, 캐릭터 지정
- **캐릭터 시스템**: 3가지 기본 캐릭터 (優しい/ツンデレ/クール)
- **링잉 경험**: 캐릭터 이미지 + 랜덤 보이스 + 슬라이드 해제
- **스누즈 기능**: 설정 가능한 간격과 최대 횟수
- **심층 링크**: `utototo://ringing?alarmId=...` 지원
- **로컬 저장**: JSON + FileManager (향후 CoreData 확장 가능)

## 기술 스택

- **언어**: Swift 5.9+
- **UI**: SwiftUI
- **아키텍처**: TCA (The Composable Architecture)
- **플랫폼**: iOS 17.0+
- **저장소**: FileManager (Documents 디렉토리)
- **알림**: UNUserNotificationCenter
- **오디오**: AVFoundation

## 프로젝트 구조

```
Utouto/
├── Package.swift                    # Swift Package Manager 설정
├── Sources/Utouto/
│   ├── Models/
│   │   └── Models.swift            # 데이터 모델 (Alarm, Settings, Character)
│   ├── Clients/
│   │   └── Clients.swift           # TCA 클라이언트 (Repository, Notification, Audio 등)
│   ├── Features/
│   │   ├── App/
│   │   │   └── AppFeature.swift    # 메인 앱 피처 (TCA Reducer)
│   │   ├── Onboarding/
│   │   │   └── OnboardingFeature.swift # 온보딩 피처
│   │   ├── AlarmList/
│   │   │   └── AlarmListFeature.swift # 알람 목록 피처
│   │   ├── AlarmEdit/
│   │   │   └── AlarmEditFeature.swift # 알람 편집 피처
│   │   ├── CharacterSelect/
│   │   │   └── CharacterSelectFeature.swift # 캐릭터 선택 피처
│   │   ├── Ringing/
│   │   │   └── RingingFeature.swift # 링잉 경험 피처
│   │   └── Settings/
│   │       └── SettingsFeature.swift # 설정 피처
│   ├── Resources/
│   │   └── Assets.xcassets/        # 앱 에셋
│   ├── Info.plist                  # 앱 설정 (URL scheme 등)
│   └── utoutoApp.swift             # 앱 엔트리 포인트
├── Tests/UtoutoTests/
│   └── Tests.swift                 # 단위 테스트
├── utouto.xcodeproj/               # Xcode 프로젝트
└── README.md                       # 프로젝트 설명
```

## 빌드 및 실행 방법

### 1. TCA 의존성 설치

프로젝트는 Swift Package Manager를 사용하여 TCA를 의존성으로 포함합니다.

```bash
# Xcode에서 자동으로 의존성이 해결됩니다
# 또는 수동으로:
cd /path/to/utouto
swift package resolve
```

### 2. Xcode에서 열기

```bash
open utouto.xcodeproj
```

### 3. 빌드 및 실행

- 타겟: iOS 17.0+
- 시뮬레이터 또는 실제 기기에서 실행
- **중요**: 실제 기기에서 테스트하려면 개발자 계정과 프로비저닝이 필요합니다

## 심층 링크 테스트

### 1. URL Scheme 등록 확인

Info.plist에 다음이 포함되어 있어야 합니다:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>utototo</string>
        </array>
    </dict>
</array>
```

### 2. 링잉 화면 테스트

Safari에서 다음 URL을 열어 테스트:

```
utototo://ringing?alarmId=YOUR_ALARM_UUID
```

예시:
```
utototo://ringing?alarmId=12345678-1234-1234-1234-123456789ABC
```

## 알림 권한 테스트

### 1. 권한 요청 흐름

- 앱 최초 실행 시 온보딩 화면에서 권한 요청
- 설정 > 개인정보 보호 > 알림에서 권한 확인 가능

### 2. 알림 테스트

1. 알람 생성 및 활성화
2. 앱을 백그라운드로 전환
3. 알람 시간까지 대기 또는 시뮬레이터에서 시간 변경
4. 알림 탭 시 링잉 화면으로 이동

## TODO / 미구현 사항

### 에셋 파일
- 캐릭터 이미지: `character_gentle.png`, `character_tsundere.png`, `character_cool.png`
- 보이스 클립: `wake_gentle_1.mp3`, `snooze_gentle_1.mp3` 등
- 기본 효과음: `wake_default.mp3`, `snooze_default.mp3`

### 향상 기능
- [ ] 진동 피드백 (현재는 설정만 존재)
- [ ] LongPress 해제 모드 (현재는 Slide만 지원)
- [ ] 알람 로그 UI
- [ ] CoreData 마이그레이션
- [ ] 다크 모드 최적화
- [ ] 접근성 (VoiceOver) 지원

## 테스트

### 단위 테스트 실행

```bash
# Xcode에서 Test 실행
# 또는 커맨드 라인:
xcodebuild test -project utouto.xcodeproj -scheme utouto
```

### 테스트 커버리지

현재 구현된 테스트:
1. 알람 생성 및 저장
2. 알람 토글 시 알림 스케줄링
3. 링잉 화면에서 스누즈 시 오디오 정지

## 라이선스

이 프로젝트는 학습 목적으로 만들어졌습니다. 실제 배포 시 적절한 라이선스를 적용하세요.

## 개발자 노트

- TCA를 사용하여 테스트 가능하고 모듈화된 아키텍처 구현
- 모든 비즈니스 로직은 Reducer에서 순수 함수로 구현
- Effect를 통해 외부 의존성 처리
- 오프라인-first 설계로 네트워크 의존성 제거