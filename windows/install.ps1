<#
  claude-env Windows 설치 스크립트

  사용:  .\install.cmd
     또는 powershell -ExecutionPolicy Bypass -File install.ps1 [-SkipClaudeInstall] [-SkipPlugins]

  하는 일
    1. Claude Code가 없으면 공식 설치 스크립트로 설치 (-SkipClaudeInstall로 끔)
    2. settings.json 병합: 기존 설정은 보존하고, 이 레포에 있는 키만 덮어씀
    3. CLAUDE.md: ~/.claude/CLAUDE.md 안의 claude-env 블록만 교체 (나머지 내용 보존)
    4. skills/ 아래 스킬을 ~/.claude/skills/ 로 복사
    5. claude-hud 상태줄 런처와 설정 복사
    6. 마켓플레이스 추가 + 플러그인 설치 (-SkipPlugins로 끔)
  바꾸기 전 파일은 ~/.claude/claude-env-backups/<시각>/ 에 백업됨.
#>
param(
  [switch]$SkipClaudeInstall,
  [switch]$SkipPlugins
)

$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$BackupDir = Join-Path $ClaudeDir ('claude-env-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$script:BackedUp = $false

function Write-Step([string]$Msg) { Write-Host "==> $Msg" -ForegroundColor Cyan }
function Write-Note([string]$Msg) { Write-Host "[주의] $Msg" -ForegroundColor Yellow }
function Read-Utf8([string]$Path) { [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
function Save-Utf8([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $Utf8NoBom) }

function Backup-Path([string]$Path, [string]$Name) {
  if (-not (Test-Path $Path)) { return }
  $dst = Join-Path $BackupDir $Name
  New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
  Copy-Item $Path $dst -Recurse -Force
  $script:BackedUp = $true
}

# $Over의 키를 $Base에 덮어씀. 최상위 객체(enabledPlugins, extraKnownMarketplaces 등)는
# 항목 단위로 합치고, 그 아래 값은 통째로 교체한다 (예: 마켓플레이스 source에 옛 키가 남지 않게).
function Merge-Json($Base, $Over, [int]$Depth = 1) {
  foreach ($p in $Over.PSObject.Properties) {
    $cur = $Base.PSObject.Properties[$p.Name]
    if ($Depth -gt 0 -and $cur -and ($cur.Value -is [System.Management.Automation.PSCustomObject]) -and ($p.Value -is [System.Management.Automation.PSCustomObject])) {
      Merge-Json $cur.Value $p.Value ($Depth - 1)
    } elseif ($cur) {
      $cur.Value = $p.Value
    } else {
      $Base | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
    }
  }
}

New-Item -ItemType Directory -Force $ClaudeDir | Out-Null
Write-Host "설치 위치: $ClaudeDir"

# 1. Claude Code ------------------------------------------------------------
$claude = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claude) {
  if ($SkipClaudeInstall) {
    Write-Note 'claude 명령이 없습니다. 나중에 설치하세요: irm https://claude.ai/install.ps1 | iex'
  } else {
    Write-Step 'Claude Code 설치 (공식 설치 스크립트)'
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    $env:Path = (Join-Path $HOME '.local\bin') + ';' + $env:Path
    $claude = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claude) { Write-Note 'Claude Code 설치 후에도 claude 명령을 찾지 못했습니다. 새 터미널에서 다시 실행하세요.' }
  }
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Note 'Git for Windows가 없습니다. Claude Code는 Git Bash가 필요합니다: winget install Git.Git'
}

# 2. node (claude-hud 상태줄용, 18 이상) ----------------------------------------
$nodePath = $null
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
  $major = [int](((& $node.Source -v) | Select-Object -First 1) -replace '^v(\d+).*$', '$1')
  if ($major -ge 18) { $nodePath = $node.Source -replace '\\', '/' }
  else { Write-Note "node v$major 는 claude-hud에 너무 오래됐습니다 (18 이상 필요). 상태줄 설정은 건너뜁니다." }
} else {
  Write-Note 'node가 없어 claude-hud 상태줄 설정은 건너뜁니다. 설치: winget install OpenJS.NodeJS.LTS'
}

# 3. settings.json 병합 ------------------------------------------------------
Write-Step 'settings.json 병합'
$repoSettings = (Read-Utf8 (Join-Path $Here 'settings.json')) | ConvertFrom-Json
if ($nodePath) {
  $repoSettings.statusLine.command = $repoSettings.statusLine.command.Replace('__NODE__', $nodePath)
} else {
  $repoSettings.PSObject.Properties.Remove('statusLine')
}
$settingsPath = Join-Path $ClaudeDir 'settings.json'
$merged = $null
if (Test-Path $settingsPath) {
  Backup-Path $settingsPath 'settings.json'
  try { $merged = (Read-Utf8 $settingsPath) | ConvertFrom-Json } catch {
    Write-Note '기존 settings.json을 읽지 못해 새로 씁니다 (원본은 백업에 있음).'
  }
}
if (-not ($merged -is [System.Management.Automation.PSCustomObject])) { $merged = [pscustomobject]@{} }
Merge-Json $merged $repoSettings
Save-Utf8 $settingsPath (($merged | ConvertTo-Json -Depth 50) + "`n")

# 4. CLAUDE.md (claude-env 블록만 교체) ----------------------------------------
Write-Step 'CLAUDE.md 갱신'
$begin = '<!-- claude-env:begin -->'
$end = '<!-- claude-env:end -->'
$block = $begin + "`n" + (Read-Utf8 (Join-Path $Here 'CLAUDE.md')).Trim() + "`n" + $end
$mdPath = Join-Path $ClaudeDir 'CLAUDE.md'
$old = ''
if (Test-Path $mdPath) { Backup-Path $mdPath 'CLAUDE.md'; $old = Read-Utf8 $mdPath }
$pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end)
if ($old -match $pattern) {
  $new = [regex]::Replace($old, $pattern, [Text.RegularExpressions.MatchEvaluator] { param($m) $block })
} elseif ($old.Trim()) {
  $new = $old.TrimEnd() + "`n`n" + $block + "`n"
} else {
  $new = $block + "`n"
}
Save-Utf8 $mdPath $new

# 5. 스킬 -------------------------------------------------------------------
$skillsSrc = Join-Path $Here 'skills'
if (Test-Path $skillsSrc) {
  $skillsDst = Join-Path $ClaudeDir 'skills'
  New-Item -ItemType Directory -Force $skillsDst | Out-Null
  foreach ($s in Get-ChildItem $skillsSrc -Directory) {
    Write-Step "스킬 설치: $($s.Name)"
    $dst = Join-Path $skillsDst $s.Name
    if (Test-Path $dst) { Backup-Path $dst "skills\$($s.Name)"; Remove-Item $dst -Recurse -Force }
    Copy-Item $s.FullName $dst -Recurse
  }
}

# 6. claude-hud 상태줄 -------------------------------------------------------
Write-Step 'claude-hud 런처와 설정 복사'
$hudDst = Join-Path $ClaudeDir 'plugins\claude-hud'
New-Item -ItemType Directory -Force $hudDst | Out-Null
Copy-Item (Join-Path $Here 'hud\statusline.mjs') $hudDst -Force
Backup-Path (Join-Path $hudDst 'config.json') 'claude-hud-config.json'
Copy-Item (Join-Path $Here 'hud\config.json') $hudDst -Force

# 7. 플러그인 ----------------------------------------------------------------
if ($SkipPlugins) {
  Write-Note '플러그인 설치를 건너뜁니다 (-SkipPlugins).'
} elseif (-not $claude) {
  Write-Note 'claude 명령이 없어 플러그인 설치를 건너뜁니다. Claude Code 설치 후 이 스크립트를 다시 실행하세요.'
} else {
  foreach ($m in $repoSettings.extraKnownMarketplaces.PSObject.Properties) {
    $src = $m.Value.source
    if ($src.source -ne 'github') { continue }
    Write-Step "마켓플레이스 추가: $($m.Name) ($($src.repo))"
    & $claude.Source plugin marketplace add $src.repo
    if ($LASTEXITCODE -ne 0) { Write-Note "$($m.Name): 이미 있거나 추가 실패 (exit $LASTEXITCODE)" }
  }
  foreach ($p in $repoSettings.enabledPlugins.PSObject.Properties) {
    if (-not $p.Value) { continue }
    Write-Step "플러그인 설치: $($p.Name)"
    & $claude.Source plugin install $p.Name --scope user
    if ($LASTEXITCODE -ne 0) { Write-Note "$($p.Name): 이미 설치돼 있거나 설치 실패 (exit $LASTEXITCODE)" }
  }
}

Write-Host ''
Write-Host '완료.' -ForegroundColor Green
if ($script:BackedUp) { Write-Host "기존 파일 백업: $BackupDir" }
Write-Host '다음: 새 터미널에서 claude 실행 -> 처음이면 /login 으로 로그인.'
