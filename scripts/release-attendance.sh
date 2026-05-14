#!/usr/bin/env bash
#
# Attendance APK 로컬 빌드 + S3 업로드 + 서버 등록.
#
# 흐름:
#   1) ./scripts/release-attendance.sh [--staging]            → APK 빌드만
#      에뮬레이터/실기기에서 동작 확인 후
#   2) ./scripts/release-attendance.sh --upload [--staging]   → S3 업로드 + 버전 등록
#
# 파일명/경로 규칙 (확정됨, 변경 시 메모리·workflow yml 동기화 필요):
#   prod    : s3://taskmanager-storage-prod/app-releases/attendance/v{X.Y.Z}/htma_{X.Y.Z+N}.apk
#   staging : s3://taskmanager-storage-staging/app-releases/attendance/v{X.Y.Z}/htma_test_{X.Y.Z+N}.apk
#
#   - 디렉토리: marketing version (`+N` 제외)  → 예 `v1.0.7/`
#   - 파일명: full version (`X.Y.Z+N`)       → 예 `htma_1.0.7+25.apk`
#   - 같은 marketing version에 빌드번호만 다른 APK 여러 개 공존 가능
#
# S3 IAM(tm-release)은 PutObject만 가능 — DeleteObject 불가. 잘못 올린 파일 못 지움.
#
set -euo pipefail

# ── 인자 파싱 ──────────────────────────────────────────────
UPLOAD=false
STAGING=false
for arg in "$@"; do
  case "$arg" in
    --upload)  UPLOAD=true ;;
    --staging) STAGING=true ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      echo "Usage: $0 [--upload] [--staging]" >&2
      exit 1
      ;;
  esac
done

# ── 경로 ───────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
ATTENDANCE_DIR="$APP_REPO/apps/attendance"

if [ ! -f "$ATTENDANCE_DIR/pubspec.yaml" ]; then
  echo "ERROR: $ATTENDANCE_DIR/pubspec.yaml not found" >&2
  exit 1
fi

# ── 버전 추출 (pubspec.yaml) ───────────────────────────────
FULL_VERSION="$(grep -E '^version:' "$ATTENDANCE_DIR/pubspec.yaml" | sed -E 's/^version:[[:space:]]*//')"
MARKETING_VERSION="${FULL_VERSION%+*}"

if [ -z "$FULL_VERSION" ] || [ "$FULL_VERSION" = "$MARKETING_VERSION" ]; then
  echo "ERROR: pubspec.yaml version must be X.Y.Z+N format (got: '$FULL_VERSION')" >&2
  exit 1
fi

# ── 환경별 설정 ────────────────────────────────────────────
if $STAGING; then
  FLAVOR="attendancestaging"
  API_BASE="https://stg-api.hermesops.site/api/v1"
  APP_ENV="staging"
  APP_FLAVOR_DEFINE="STAGING"
  BUCKET="taskmanager-storage-staging"
  CHANNEL="attendance_staging"
  PREFIX="htma_test"
else
  FLAVOR="attendanceproduction"
  API_BASE="https://api.hermesops.site/api/v1"
  APP_ENV="production"
  APP_FLAVOR_DEFINE=""
  BUCKET="taskmanager-storage-prod"
  CHANNEL="attendance_production"
  PREFIX="htma"
fi

FILENAME="${PREFIX}_${FULL_VERSION}.apk"
S3_KEY="app-releases/attendance/v${MARKETING_VERSION}/${FILENAME}"
APK_PATH="$ATTENDANCE_DIR/build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk"
PUBLIC_URL="https://${BUCKET}.s3.us-west-2.amazonaws.com/${S3_KEY}"

echo "─────────────────────────────────────────────────────"
echo " Channel:        $CHANNEL"
echo " Version:        $FULL_VERSION  (marketing: $MARKETING_VERSION)"
echo " Build flavor:   $FLAVOR"
echo " APK filename:   $FILENAME"
echo " S3 key:         $S3_KEY"
echo "─────────────────────────────────────────────────────"

# ── Upload 모드: 사전 빌드된 APK 업로드 + 서버 등록 ────────
if $UPLOAD; then
  if [ ! -f "$APK_PATH" ]; then
    echo "ERROR: APK not found — build first (run without --upload)" >&2
    echo "  expected: $APK_PATH" >&2
    exit 1
  fi

  echo
  echo "→ Uploading to s3://${BUCKET}/${S3_KEY}"
  aws s3 cp --acl public-read "$APK_PATH" "s3://${BUCKET}/${S3_KEY}"

  echo
  echo "→ Registering with server"
  RESPONSE="$(curl -sS -X POST "${API_BASE}/console/app-versions" \
    -H "Content-Type: application/json" \
    -d "{
      \"channel\": \"${CHANNEL}\",
      \"version\": \"${FULL_VERSION}\",
      \"s3_key\": \"${S3_KEY}\",
      \"is_latest\": true,
      \"is_min_required\": false,
      \"release_notes\": \"Released via release-attendance.sh\"
    }")"

  echo "$RESPONSE"
  if echo "$RESPONSE" | grep -q '"detail"'; then
    echo "ERROR: server returned error" >&2
    exit 1
  fi

  echo
  echo "✓ Released $FULL_VERSION"
  echo "  Download: $PUBLIC_URL"
  exit 0
fi

# ── Build 모드: APK만 빌드 ─────────────────────────────────
cd "$ATTENDANCE_DIR"

BUILD_ARGS=("--flavor" "$FLAVOR" "--release"
            "--dart-define=API_BASE_URL=${API_BASE}"
            "--dart-define=APP_ENV=${APP_ENV}")
if [ -n "$APP_FLAVOR_DEFINE" ]; then
  BUILD_ARGS+=("--dart-define=APP_FLAVOR=${APP_FLAVOR_DEFINE}")
fi

echo
echo "→ flutter build apk ${BUILD_ARGS[*]}"
flutter build apk "${BUILD_ARGS[@]}"

if [ ! -f "$APK_PATH" ]; then
  echo "ERROR: build succeeded but APK not at expected path" >&2
  echo "  expected: $APK_PATH" >&2
  exit 1
fi

# 동일 디렉토리에 최종 파일명으로도 복사해두면 에뮬레이터/실기기 설치 시 헷갈리지 않음
NAMED_APK="$ATTENDANCE_DIR/build/app/outputs/flutter-apk/${FILENAME}"
cp "$APK_PATH" "$NAMED_APK"

echo
echo "✓ Built $FULL_VERSION"
echo "  APK:       $NAMED_APK"
echo "  Size:      $(du -h "$NAMED_APK" | cut -f1)"
echo
echo "다음 단계:"
echo "  1) 에뮬레이터/실기기에 설치하여 동작 확인"
echo "     adb install -r '$NAMED_APK'"
echo "  2) 확인 끝나면 업로드:"
echo "     ./scripts/release-attendance.sh --upload $($STAGING && echo '--staging')"
echo "  3) 업로드 후 다운로드 URL: $PUBLIC_URL"
