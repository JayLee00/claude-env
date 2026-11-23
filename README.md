# claude-env

Jay의 Claude Code 환경(설정, 전역 지침, 스킬, 플러그인, 상태줄)을 새 PC에 한 번에 설치하는 레포.

```
claude-env/
├── windows/            Windows 버전
│   ├── install.cmd     ← 이것만 실행
│   ├── install.ps1
│   ├── settings.json   ~/.claude/settings.json 에 병합될 설정
│   ├── CLAUDE.md       ~/.claude/CLAUDE.md 에 들어갈 전역 지침
│   ├── hud/            claude-hud 상태줄 런처와 설정
│   └── skills/         개인 스킬 (graspium-publish)
└── linux/              Linux 버전 (구성 동일)
    ├── install.sh      ← 이것만 실행
    └── ...
```

## 새 PC에 설치

비공개 레포라서 먼저 GitHub 로그인이 필요합니다 (`gh auth login`, 또는 git이 자격 증명을 물어볼 때 로그인).

### Windows

필요: Git for Windows (`winget install Git.Git`), Node.js 18+ (`winget install OpenJS.NodeJS.LTS`, 상태줄용)

```powershell
gh repo clone JayLee00/claude-env      # 또는 git clone https://github.com/JayLee00/claude-env.git
cd claude-env\windows
.\install.cmd
```

### Linux (Ubuntu)

필요: git, python3, curl, Node.js 18+ (상태줄용)

```bash
gh repo clone JayLee00/claude-env      # 또는 git clone https://github.com/JayLee00/claude-env.git
cd claude-env/linux
./install.sh
```

설치가 끝나면 새 터미널에서 `claude`를 실행하고, 처음이면 `/login`으로 로그인합니다.

### 옵션

| Windows | Linux | 뜻 |
|---|---|---|
| `-SkipClaudeInstall` | `--skip-claude-install` | Claude Code가 없어도 자동 설치하지 않음 |
| `-SkipPlugins` | `--skip-plugins` | 마켓플레이스·플러그인 설치 생략 |

`CLAUDE_CONFIG_DIR` 환경변수가 있으면 `~/.claude` 대신 그 폴더에 설치합니다 (테스트할 때 유용).

## 설치 스크립트가 하는 일

1. **Claude Code**: `claude` 명령이 없으면 공식 설치 스크립트로 설치.
2. **settings.json 병합**: 기존 설정은 지우지 않습니다. 레포에 있는 키만 덮어씁니다.
   `enabledPlugins`, `extraKnownMarketplaces`, `modelSettings` 같은 묶음은 항목 단위로 합쳐서,
   그 PC에만 있는 플러그인이나 권한 설정은 그대로 남습니다.
3. **CLAUDE.md**: `~/.claude/CLAUDE.md` 안의 `<!-- claude-env:begin -->` ~ `<!-- claude-env:end -->` 블록만 교체합니다.
   블록 밖에 그 PC 전용 지침을 적어 두면 다시 설치해도 남습니다.
4. **스킬**: `skills/` 아래 폴더를 `~/.claude/skills/`로 복사 (같은 이름은 교체).
5. **claude-hud 상태줄**: 런처(`statusline.mjs`)와 설정(`config.json`)을 복사하고, 설치 시점에 찾은 node 경로로 `statusLine` 명령을 만듭니다.
   node가 없거나 18 미만이면 상태줄 설정은 건너뛰고 그 PC의 기존 상태줄을 그대로 둡니다.
6. **플러그인**: `settings.json`의 GitHub 마켓플레이스를 추가하고 켜진 플러그인을 설치합니다.

바꾸기 전 파일은 모두 `~/.claude/claude-env-backups/<시각>/`에 백업됩니다. 여러 번 실행해도 안전합니다.

## 들어 있는 것

| 항목 | 내용 |
|---|---|
| 모델 | `opus`, Opus 5.5 effort `high`, `switchModelsOnFlag` |
| 화면 | `tui: fullscreen`, `theme: dark`, 자동 업데이트 채널 `latest` |
| 플러그인 | `claude-hud` (상태줄), `obsidian` (Obsidian 스킬), `kicad-happy` (KiCad/부품 조달) |
| 상태줄 | claude-hud, 60초 갱신, 메모리 사용량 표시, git 상태 끔 (렉 줄이려고 조정한 값) |
| 전역 지침 | 한국어 답변, 사용자 소개, OS별 작업 환경, 회사망 인증서 주의 |
| 스킬 (Windows만) | `graspium-publish` — 경로가 Windows PC 기준이라 Linux에는 넣지 않음 |

## 들어 있지 않은 것 (일부러)

- **로그인 정보** (`.credentials.json`): PC마다 `/login`으로 새로 로그인합니다.
- **대화 기록, 세션, 메모리**: PC마다 따로 쌓입니다.
- **claude.ai 계정 스킬** (docx, pptx, pdf, xlsx, docs 등)과 **MCP 커넥터** (Gmail, Notion, Google Drive 등): 같은 계정으로 로그인하면 자동으로 따라옵니다.
- **프로젝트별 설정**: 각 프로젝트 레포의 `.claude/`, `CLAUDE.md`에 있습니다 (예: DexVault 볼트).

## 이 레포 고치기

- 설정을 바꾸려면 `windows/`와 `linux/`의 파일을 함께 고친 뒤 커밋·푸시하고, 각 PC에서 `git pull` 후 설치 스크립트를 다시 실행합니다.
- `settings.json`의 `statusLine.command` 안 `__NODE__`는 설치 때 실제 node 경로로 바뀝니다. 그대로 두세요.
- 새 개인 스킬은 `windows/skills/<이름>/SKILL.md` (또는 `linux/skills/...`)에 넣으면 됩니다.
