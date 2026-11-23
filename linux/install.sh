#!/usr/bin/env bash
# claude-env Linux 설치 스크립트
#
# 사용:  ./install.sh [--skip-claude-install] [--skip-plugins]
#
# 하는 일
#   1. Claude Code가 없으면 공식 설치 스크립트로 설치 (--skip-claude-install로 끔)
#   2. settings.json 병합: 기존 설정은 보존하고, 이 레포에 있는 키만 덮어씀
#   3. CLAUDE.md: ~/.claude/CLAUDE.md 안의 claude-env 블록만 교체 (나머지 내용 보존)
#   4. skills/ 아래 스킬을 ~/.claude/skills/ 로 복사
#   5. claude-hud 상태줄 런처와 설정 복사
#   6. 마켓플레이스 추가 + 플러그인 설치 (--skip-plugins로 끔)
# 바꾸기 전 파일은 ~/.claude/claude-env-backups/<시각>/ 에 백업됨.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
BACKUP_DIR="$CLAUDE_DIR/claude-env-backups/$(date +%Y%m%d-%H%M%S)"
SKIP_CLAUDE=0
SKIP_PLUGINS=0
BACKED_UP=0

for arg in "$@"; do
  case "$arg" in
    --skip-claude-install) SKIP_CLAUDE=1 ;;
    --skip-plugins) SKIP_PLUGINS=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "알 수 없는 옵션: $arg" >&2; exit 1 ;;
  esac
done

step() { printf '\033[36m==> %s\033[0m\n' "$*"; }
note() { printf '\033[33m[주의] %s\033[0m\n' "$*"; }
backup() { # backup <원본 경로> <백업 안에서의 이름>
  [ -e "$1" ] || return 0
  mkdir -p "$(dirname "$BACKUP_DIR/$2")"
  cp -a "$1" "$BACKUP_DIR/$2"
  BACKED_UP=1
}

PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1; then PY="$c"; break; fi
done
if [ -z "$PY" ]; then
  echo "python3가 필요합니다: sudo apt install -y python3" >&2
  exit 1
fi

mkdir -p "$CLAUDE_DIR"
echo "설치 위치: $CLAUDE_DIR"

# 1. Claude Code ------------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
  if [ "$SKIP_CLAUDE" = 1 ]; then
    note "claude 명령이 없습니다. 나중에 설치하세요: curl -fsSL https://claude.ai/install.sh | bash"
  else
    step "Claude Code 설치 (공식 설치 스크립트)"
    curl -fsSL https://claude.ai/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
    command -v claude >/dev/null 2>&1 || note "설치 후에도 claude 명령을 찾지 못했습니다. 새 터미널에서 다시 실행하세요."
  fi
fi
command -v git >/dev/null 2>&1 || note "git이 없습니다: sudo apt install -y git"

# 2. node (claude-hud 상태줄용, 18 이상) ----------------------------------------
HUD_NODE=""
if command -v node >/dev/null 2>&1; then
  major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
  if [ "${major:-0}" -ge 18 ]; then
    HUD_NODE="$(command -v node)"
  else
    note "node $(node -v) 는 claude-hud에 너무 오래됐습니다 (18 이상 필요). 상태줄 설정은 건너뜁니다."
    note "  예: curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs"
  fi
else
  note "node가 없어 claude-hud 상태줄 설정은 건너뜁니다 (Node.js 18 이상 설치 후 다시 실행)."
fi

# 3. settings.json 병합 ------------------------------------------------------
step "settings.json 병합"
backup "$CLAUDE_DIR/settings.json" settings.json
HUD_NODE="$HUD_NODE" "$PY" - "$HERE/settings.json" "$CLAUDE_DIR/settings.json" <<'PYEOF'
import json, os, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as f:
    repo = json.load(f)
node = os.environ.get("HUD_NODE", "")
if node:
    repo["statusLine"]["command"] = repo["statusLine"]["command"].replace("__NODE__", node)
else:
    repo.pop("statusLine", None)
cur = {}
if os.path.exists(dst):
    try:
        with open(dst, encoding="utf-8-sig") as f:
            cur = json.load(f)
    except ValueError:
        print("[주의] 기존 settings.json을 읽지 못해 새로 씁니다 (원본은 백업에 있음).")
    if not isinstance(cur, dict):
        cur = {}
# 최상위 dict(enabledPlugins, extraKnownMarketplaces 등)는 항목 단위로 합치고,
# 그 아래 값은 통째로 교체한다 (예: 마켓플레이스 source에 옛 키가 남지 않게).
def merge(base, over, depth=1):
    for k, v in over.items():
        if depth > 0 and isinstance(v, dict) and isinstance(base.get(k), dict):
            merge(base[k], v, depth - 1)
        else:
            base[k] = v
merge(cur, repo)
with open(dst, "w", encoding="utf-8") as f:
    json.dump(cur, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF

# 4. CLAUDE.md (claude-env 블록만 교체) ----------------------------------------
step "CLAUDE.md 갱신"
backup "$CLAUDE_DIR/CLAUDE.md" CLAUDE.md
"$PY" - "$HERE/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" <<'PYEOF'
import os, re, sys
src, dst = sys.argv[1], sys.argv[2]
begin, end = "<!-- claude-env:begin -->", "<!-- claude-env:end -->"
with open(src, encoding="utf-8") as f:
    block = begin + "\n" + f.read().strip() + "\n" + end
old = ""
if os.path.exists(dst):
    with open(dst, encoding="utf-8-sig") as f:
        old = f.read()
pattern = re.compile(re.escape(begin) + ".*?" + re.escape(end), re.S)
if pattern.search(old):
    new = pattern.sub(lambda m: block, old, count=1)
elif old.strip():
    new = old.rstrip() + "\n\n" + block + "\n"
else:
    new = block + "\n"
with open(dst, "w", encoding="utf-8") as f:
    f.write(new)
PYEOF

# 5. 스킬 -------------------------------------------------------------------
if [ -d "$HERE/skills" ]; then
  mkdir -p "$CLAUDE_DIR/skills"
  for s in "$HERE"/skills/*/; do
    [ -d "$s" ] || continue
    name="$(basename "$s")"
    step "스킬 설치: $name"
    if [ -e "$CLAUDE_DIR/skills/$name" ]; then
      backup "$CLAUDE_DIR/skills/$name" "skills/$name"
      rm -rf "$CLAUDE_DIR/skills/$name"
    fi
    cp -a "$s" "$CLAUDE_DIR/skills/$name"
  done
fi

# 6. claude-hud 상태줄 -------------------------------------------------------
step "claude-hud 런처와 설정 복사"
HUD_DIR="$CLAUDE_DIR/plugins/claude-hud"
mkdir -p "$HUD_DIR"
cp "$HERE/hud/statusline.mjs" "$HUD_DIR/"
backup "$HUD_DIR/config.json" claude-hud-config.json
cp "$HERE/hud/config.json" "$HUD_DIR/"

# 7. 플러그인 ----------------------------------------------------------------
if [ "$SKIP_PLUGINS" = 1 ]; then
  note "플러그인 설치를 건너뜁니다 (--skip-plugins)."
elif ! command -v claude >/dev/null 2>&1; then
  note "claude 명령이 없어 플러그인 설치를 건너뜁니다. Claude Code 설치 후 이 스크립트를 다시 실행하세요."
else
  # settings.json에서 github 마켓플레이스와 켜진 플러그인 목록을 읽음
  PLUGIN_LIST="$(mktemp)"
  "$PY" - "$HERE/settings.json" > "$PLUGIN_LIST" <<'PYEOF'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    s = json.load(f)
for name, m in s.get("extraKnownMarketplaces", {}).items():
    if m.get("source", {}).get("source") == "github":
        print("M", name, m["source"]["repo"])
for p, on in s.get("enabledPlugins", {}).items():
    if on:
        print("P", p, "-")
PYEOF
  while read -r kind name repo; do
    if [ "$kind" = M ]; then
      step "마켓플레이스 추가: $name ($repo)"
      claude plugin marketplace add "$repo" || note "$name: 이미 있거나 추가 실패"
    else
      step "플러그인 설치: $name"
      claude plugin install "$name" --scope user || note "$name: 이미 설치돼 있거나 설치 실패"
    fi
  done < "$PLUGIN_LIST"
  rm -f "$PLUGIN_LIST"
fi

echo
printf '\033[32m완료.\033[0m\n'
if [ "$BACKED_UP" = 1 ]; then echo "기존 파일 백업: $BACKUP_DIR"; fi
echo "다음: 새 터미널에서 claude 실행 -> 처음이면 /login 으로 로그인."
