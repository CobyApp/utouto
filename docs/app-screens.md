# Utouto — 화면 & 기능 정리

## 앱 전체 구조

```
AppFeature (AppView)
├── Tab 1: 알람목록      → AlarmListFeature
│   └── Sheet: 알람생성/편집 → AlarmEditFeature
├── Tab 2: 내 영상      → MyLibraryFeature
│   └── Sheet: 클립 편집   → ClipEditorFeature
├── Tab 3: 커뮤니티     → CommunityFeature
└── Tab 4: 설정        → SettingsFeature
    Overlay: 알람울림   → RingingFeature
```

---

## 1. 알람 목록 (AlarmListFeature / AlarmListView)

**역할:** 저장된 알람을 목록으로 표시하고 관리

| 기능 | 설명 |
|------|------|
| 알람 목록 표시 | 시간 오름차순 정렬 |
| 알람 ON/OFF 토글 | 활성화 시 알림 스케줄 등록, 비활성화 시 취소 |
| 알람 편집 진입 | 셀 탭 → AlarmEditFeature로 이동 |
| 알람 삭제 | 스와이프 → 확인 Alert 후 삭제 |
| 알람 추가 | 우상단 + 버튼 → AlarmEditFeature(신규)로 이동 |
| 빈 상태 화면 | 알람 없을 때 안내 메시지 + 추가 버튼 |

---

## 2. 알람 생성 / 편집 (AlarmEditFeature / AlarmEditView)

**역할:** 새 알람 생성 또는 기존 알람 수정

| 기능 | 설명 |
|------|------|
| 시간 설정 | 시(時) / 분(分) 피커 |
| 라벨 입력 | 알람 이름 텍스트 입력 |
| 반복 요일 설정 | 요일 다중 선택 |
| 일회성 설정 | 일회성 ON 시 특정 날짜 지정 가능 |
| 알람 영상(클립) 선택 | 보유 클립 목록에서 선택 |
| 스누즈 설정 | ON/OFF, 간격(분), 최대 횟수 |
| 해제 방식 설정 | 슬라이드 / 탭 등 (DismissMode) |
| 저장 | 알람 DB 저장 + 알림 스케줄 등록 |
| 취소 | 변경 사항 버리고 닫기 |

---

## 3. 영상 가져오기 & 클립 편집 (ClipEditorFeature / ClipEditorView)

**역할:** 사진 라이브러리에서 영상을 불러와 알람용 클립으로 편집·저장

| 단계 | 기능 | 설명 |
|------|------|------|
| Step 1 | 영상 선택 | 포토 라이브러리 피커로 영상 가져오기 |
| Step 2 | 타임라인 편집 | 시작/끝 시간 조절 (최소 1초 ~ 최대 30초) |
| Step 2 | 제목 입력 | 클립 이름 입력 |
| Step 2 | 미리보기 | 선택 구간 오디오 미리 재생 |
| Step 3 | 저장 | 오디오 트리밍 + 썸네일 생성 후 로컬 저장 |

---

## 4. 보유 알람 영상 리스트 (MyLibraryFeature / MyLibraryView)

**역할:** 로컬에 저장된 클립 관리. 온라인 업로드 여부로 구분

| 기능 | 대상 | 설명 |
|------|------|------|
| 클립 목록 | 전체 | 최신순 정렬, 썸네일 + 제목 표시 |
| 재생 | 전체 | 탭으로 오디오 미리 재생 / 정지 |
| 삭제 | 전체 | 확인 Alert 후 로컬 파일 삭제 |
| 온라인 업로드 | 미업로드 (isUploaded = false) | Supabase에 업로드 → 커뮤니티 공유 |
| 업로드 상태 표시 | 업로드 중 | 로딩 인디케이터 |
| 클립 편집 진입 | - | + 버튼 → ClipEditorFeature 시트 |
| 알람에 적용 | - | 클립 선택 → AlarmEditFeature로 전달 |

---

## 5. 온라인 알람 영상 커뮤니티 (CommunityFeature / CommunityView)

**역할:** 다른 사용자가 공유한 클립 탐색, 미리보기, 다운로드

| 기능 | 설명 |
|------|------|
| 클립 목록 조회 | Supabase에서 페이지네이션 로드 (20개씩) |
| 무한 스크롤 | 하단 도달 시 추가 로드 |
| 검색 | 제목 기반 텍스트 검색 / 초기화 |
| 미리보기 | 탭으로 스트리밍 재생 / 정지 |
| 다운로드 | 클립 다운로드 → 내 라이브러리에 자동 추가 |
| 좋아요 | 클립에 좋아요 |
| 알람에 바로 적용 | 다운로드 완료 시 AlarmEditFeature로 자동 이동 |

---

## 6. 알람 울림 화면 (RingingFeature / RingingView)

**역할:** 알람 발동 시 전체화면 오버레이

| 기능 | 설명 |
|------|------|
| 알람 영상/오디오 재생 | 설정된 클립 재생 |
| 스누즈 | 설정된 간격 후 재알람 |
| 알람 해제 | 설정된 방식(슬라이드/탭)으로 해제 |
| Deep Link 진입 | utouto://ringing?alarmId=UUID |

---

## 데이터 흐름 요약

```
[클립 생성]
ClipEditorFeature → MyLibraryFeature (로컬 저장)
    ↓ selectClipForAlarm delegate
AppFeature → AlarmEditFeature (clipId 설정)

[커뮤니티 클립 사용]
CommunityFeature (다운로드)
    ↓ useClipAsAlarm delegate
AppFeature → VideoClip 로컬 저장 → AlarmEditFeature 오픈
```

---

## Feature 파일 위치

| Feature | Feature | View |
|---------|---------|------|
| App | AppFeature.swift | AppView.swift |
| 알람 목록 | AlarmListFeature.swift | AlarmListView.swift |
| 알람 편집 | AlarmEditFeature.swift | AlarmEditView.swift |
| 클립 편집기 | ClipEditorFeature.swift | ClipEditorView.swift |
| 내 라이브러리 | MyLibraryFeature.swift | MyLibraryView.swift |
| 커뮤니티 | CommunityFeature.swift | CommunityView.swift |
| 알람 울림 | RingingFeature.swift | RingingView.swift |
| 설정 | SettingsFeature.swift | SettingsView.swift |
