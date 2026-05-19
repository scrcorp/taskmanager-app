# Attendance App Changelog

> 최신이 위로. prod 배포된 빌드만 기록. staging-only / dev 빌드는 생략.
> 빌드 번호(+N)는 `pubspec.yaml`의 `version: X.Y.Z+N` 에서 추출되며 같은 마이너 버전 안에서 누적됨.

---

## v1.0.8 (prod: TBD)

- Tip 키오스크 분배 UI + Staff eligible 필터 + version polling 안정화 (+26)
- Manage mode reason 자유 입력 → preset 칩 picker (+26)
- Tip 기능 추가 — Staff app 입력 + Attendance app 분배/조회 (+26)
- Worktree 별 `applicationId` / 라벨 격리로 멀티 빌드 공존 가능 (+26)

---

## v1.0.7 (prod)

> 본 changelog 도입 이전. 자세한 내역은 git log 참조 (`git log --oneline -- apps/attendance/`).
> 핵심: kiosk admin mode + 메인 grid + activity history + APK 자동 업데이트 헤더 broadcast + 다국어(en/es).

---

## 작성 규칙

- 마이너 버전(`vX.Y.Z`) 단위로 헤더, 최신이 위로
- 항목은 한 줄, 끝에 빌드 번호 `(+N)` 표시
- 같은 마이너 안에 여러 빌드가 있으면 각 빌드 항목 누적
- prod 배포 날짜는 헤더에 `(prod: YYYY-MM-DD)` 형식으로 채움
- staging-only / dev-only 빌드는 기록하지 않음 (소음 방지)
