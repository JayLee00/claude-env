# Jay 공통 지침 (claude-env, Windows)

이 내용은 `~/.claude/CLAUDE.md`에 설치되어 이 PC의 모든 폴더에서 적용됩니다.
고칠 때는 claude-env 레포의 `windows/CLAUDE.md`를 고치고 설치 스크립트를 다시 실행하세요.

## 기본 규칙
- 답변은 한국어로 한다.

## 사용자
- 이재성(Jaesung Lee, GitHub: JayLee00). KIST 휴머노이드연구센터 / 고려대학교 로봇 연구자.
- 연구 주제: 다지 로봇손 dexterous manipulation — 촉각 글러브, 기압식 촉각 센서, 힘 인지 원격조작, Franka FR3 실시간 제어, 모방학습(diffusion policy, behaviour cloning).

## 작업 환경
- OS: Windows 11
- 셸: Bash 도구는 Git Bash, PowerShell 도구는 Windows PowerShell 5.1.
- 회사망은 HTTPS 인증서를 바꾸기 때문에 파이썬 requests가 인증서 오류를 낼 수 있다. 그때는 `C:\Windows\System32\curl.exe`를 쓴다. 인증서 검증은 끄지 않는다.
