#!/bin/bash
# stamp-web-name.sh — 웹 빌드 산출물의 PWA 표시 이름에 접미사를 붙인다.
#
# 사용법: ./tool/stamp-web-name.sh <suffix> [build-dir] [--require-badge]
# 예시:   ./tool/stamp-web-name.sh w5        → 홈 화면 아이콘 이름 "HTM-w5"
#         ./tool/stamp-web-name.sh STG       → "HTM-STG"
#
# --require-badge: 아이콘 배지를 못 찍으면 실패로 끝낸다(exit 1).
#   CI 에서 쓴다 — 러너에 Pillow/폰트가 없으면 배지 없는 빌드가 조용히 배포되어
#   staging 이 prod 와 구분 안 되는 상태로 나간다. 그건 경고가 아니라 실패다.
#
# 왜 필요한가:
#   홈 화면 아이콘 이름은 manifest.json 과 apple-mobile-web-app-title 에서 온다.
#   둘 다 정적 파일이라 --dart-define 으로 못 바꾼다. 그래서 빌드 후 여기서 찍는다.
#
#   prod/staging/워크트리 빌드가 전부 "HTM" 이면 한 폰에 여러 개를 설치했을 때
#   어느 게 어느 환경인지 구분이 안 된다(오리진이 달라 iOS 는 별개 앱으로 취급하므로
#   실제로 동시에 설치된다). 테스트용이자 환경 혼동 방지용.
#
# 주의: build/web 산출물만 건드린다. 소스(web/manifest.json, web/index.html)는
#       "HTM" 그대로 두어야 prod 빌드가 접미사 없이 나간다.
set -euo pipefail

SUFFIX=""
BUILD_DIR=""
REQUIRE_BADGE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --require-badge) REQUIRE_BADGE=1 ;;
        -*) echo "Unknown flag: $1"; exit 1 ;;
        *)
            if [ -z "$SUFFIX" ]; then SUFFIX="$1"
            elif [ -z "$BUILD_DIR" ]; then BUILD_DIR="$1"
            else echo "Unexpected arg: $1"; exit 1; fi
            ;;
    esac
    shift
done
BUILD_DIR="${BUILD_DIR:-build/web}"

if [ -z "$SUFFIX" ]; then
    sed -n '2,24p' "$0"
    exit 1
fi

MANIFEST="$BUILD_DIR/manifest.json"
INDEX="$BUILD_DIR/index.html"

for f in "$MANIFEST" "$INDEX"; do
    [ -f "$f" ] || { echo "ERROR: $f 없음 — 먼저 flutter build web 실행"; exit 1; }
done

NAME="HTM-$SUFFIX"

python3 - "$MANIFEST" "$INDEX" "$NAME" <<'PY'
import json, re, sys

manifest_path, index_path, name = sys.argv[1], sys.argv[2], sys.argv[3]

with open(manifest_path) as f:
    m = json.load(f)
m["name"] = name
m["short_name"] = name
with open(manifest_path, "w") as f:
    json.dump(m, f, indent=4)
    f.write("\n")

with open(index_path) as f:
    html = f.read()
# iOS 는 apple-mobile-web-app-title 을 manifest 보다 우선한다 — 같이 바꿔야 한다.
html = re.sub(
    r'(<meta name="apple-mobile-web-app-title" content=")[^"]*(">)',
    lambda mo: mo.group(1) + name + mo.group(2),
    html,
)
html = re.sub(r"<title>[^<]*</title>", f"<title>{name}</title>", html)
with open(index_path, "w") as f:
    f.write(html)
PY

echo "OK: PWA 표시 이름 → $NAME  ($BUILD_DIR)"

# ── 아이콘 배지 ────────────────────────────────────────────
# 이름만 바꾸면 홈 화면에서 아이콘이 전부 똑같아 구분이 안 된다. 아이콘에도 라벨을 새긴다.
# Pillow 가 필요한데 어느 python 에 있을지 환경마다 다르므로 후보를 훑는다.
# 못 찾으면 이름 변경만 하고 경고 후 넘어간다 — 배지는 편의 기능이라 빌드를 막지 않는다.
BADGE_SCRIPT="$(cd "$(dirname "$0")" && pwd)/badge_icons.py"

find_python_with_pil() {
    local candidates=("${PYTHON:-}" python3)
    # 이 repo 들이 형제 디렉토리로 놓인 구조를 가정한 server venv (worktree 포함)
    local here; here="$(cd "$(dirname "$0")" && pwd)"
    local probe="$here"
    for _ in 1 2 3 4 5 6 7; do
        probe="$(dirname "$probe")"
        [ -x "$probe/server/.venv/bin/python" ] && candidates+=("$probe/server/.venv/bin/python")
    done
    for c in "${candidates[@]}"; do
        [ -n "$c" ] || continue
        command -v "$c" >/dev/null 2>&1 || [ -x "$c" ] || continue
        if "$c" -c "import PIL" >/dev/null 2>&1; then echo "$c"; return 0; fi
    done
    return 1
}

if PY="$(find_python_with_pil)"; then
    "$PY" "$BADGE_SCRIPT" "$SUFFIX" "$BUILD_DIR"
elif [ "$REQUIRE_BADGE" -eq 1 ]; then
    echo "ERROR: Pillow 가 있는 python 을 못 찾았다 — --require-badge 이므로 중단한다."
    echo "       배지 없는 빌드가 나가면 staging 을 prod 와 구분할 수 없다."
    echo "       CI 라면 'pip install Pillow' 단계를 확인할 것."
    exit 1
else
    echo "WARN: Pillow 가 있는 python 을 못 찾아 아이콘 배지는 건너뛴다."
    echo "      (이름 변경은 적용됨. PYTHON=/path/to/python 으로 지정 가능)"
fi
