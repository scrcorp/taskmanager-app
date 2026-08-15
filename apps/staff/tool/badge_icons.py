"""빌드 산출물 아이콘에 환경 라벨(dev/stg/w5/v1.0.3 …)을 새긴다.

왜 필요한가:
    한 폰에 prod / staging / 워크트리 빌드를 동시에 설치할 수 있다(오리진이 다르면
    iOS·안드로이드 모두 별개 앱으로 취급). 이름만 다르면 홈 화면에서 아이콘이 전부
    똑같아 헷갈린다. 아이콘 자체에 라벨을 박아 한눈에 구분한다.

주의:
    - build/web 산출물만 건드린다. 소스 web/icons/ 는 깨끗하게 둬야 prod 가 무라벨로 나간다.
    - maskable 아이콘은 런처가 가장자리를 잘라내므로 배지를 안쪽으로 들여 넣는다.
    - favicon(16px)은 글자가 뭉개져서 건너뛴다.

사용법: python badge_icons.py <label> <build-dir>
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# macOS(로컬 빌드) 와 Linux(GitHub Actions ubuntu 러너) 양쪽을 커버해야 한다.
# CI 에서 폰트를 못 찾으면 배지 없이 배포되므로 Linux 경로를 반드시 포함할 것.
FONT_CANDIDATES = [
    # macOS
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Verdana Bold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    # Linux (ubuntu-latest 는 fonts-dejavu-core 가 기본 포함)
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
]

# 배지를 새길 대상. inset = 아이콘 크기 대비 안쪽 여백 비율
#   maskable 은 바깥 20% 가 잘려나갈 수 있어 안전영역 안으로 들여 넣는다.
TARGETS = [
    ("icons/Icon-192.png", 0.0),
    ("icons/Icon-512.png", 0.0),
    ("icons/apple-touch-icon-180.png", 0.0),
    ("icons/Icon-maskable-192.png", 0.10),
    ("icons/Icon-maskable-512.png", 0.10),
]

BAR_HEIGHT_RATIO = 0.26      # 아이콘 높이 대비 배지 바 높이
BAR_COLOR = (17, 17, 17)     # 거의 검정 — 어떤 아이콘 색 위에서도 대비 확보
TEXT_COLOR = (255, 255, 255)
TEXT_WIDTH_RATIO = 0.86      # 바 너비 대비 글자 폭 목표


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in _font_paths():
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    raise RuntimeError(
        "사용 가능한 볼드 폰트를 찾지 못했다. 후보: " + ", ".join(FONT_CANDIDATES)
    )


def _font_paths() -> list[str]:
    """고정 후보 → 시스템 폰트 디렉토리 탐색 순.

    배포 러너 이미지가 바뀌어도 배지가 조용히 빠지지 않도록 마지막에 훑는다.
    """
    paths = list(FONT_CANDIDATES)
    for root in ("/usr/share/fonts", "/usr/local/share/fonts"):
        base = Path(root)
        if base.is_dir():
            paths.extend(sorted(str(p) for p in base.rglob("*Bold*.ttf")))
    return paths


def fit_font(text: str, max_w: int, max_h: int) -> ImageFont.FreeTypeFont:
    """max_w x max_h 안에 들어가는 가장 큰 폰트를 이분 탐색으로 찾는다."""
    lo, hi, best = 6, max(8, max_h * 2), None
    while lo <= hi:
        mid = (lo + hi) // 2
        font = load_font(mid)
        l, t, r, b = font.getbbox(text)
        if (r - l) <= max_w and (b - t) <= max_h:
            best, lo = font, mid + 1
        else:
            hi = mid - 1
    return best or load_font(6)


def badge(path: Path, label: str, inset_ratio: float) -> None:
    img = Image.open(path).convert("RGB")
    size = img.width
    inset = int(size * inset_ratio)

    bar_h = max(8, int(size * BAR_HEIGHT_RATIO))
    bar_bottom = size - inset
    bar_top = bar_bottom - bar_h
    bar_left, bar_right = inset, size - inset

    draw = ImageDraw.Draw(img)
    draw.rectangle([bar_left, bar_top, bar_right, bar_bottom], fill=BAR_COLOR)

    bar_w = bar_right - bar_left
    font = fit_font(label, int(bar_w * TEXT_WIDTH_RATIO), int(bar_h * 0.70))

    l, t, r, b = font.getbbox(label)
    # getbbox 는 베이스라인 기준 오프셋을 포함하므로 그만큼 빼서 실제 중앙에 놓는다.
    x = bar_left + (bar_w - (r - l)) // 2 - l
    y = bar_top + (bar_h - (b - t)) // 2 - t
    draw.text((x, y), label, font=font, fill=TEXT_COLOR)

    img.save(path)


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 1
    label, build_dir = sys.argv[1].upper(), Path(sys.argv[2])

    done = 0
    for rel, inset in TARGETS:
        path = build_dir / rel
        if not path.exists():
            print(f"  skip (없음): {rel}")
            continue
        badge(path, label, inset)
        print(f"  badged: {rel}")
        done += 1

    if done == 0:
        print("ERROR: 배지를 새길 아이콘이 없다 — build-dir 확인")
        return 1
    print(f"OK: 아이콘 {done}개에 '{label}' 배지")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
