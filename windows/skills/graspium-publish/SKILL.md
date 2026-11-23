---
name: graspium-publish
description: Graspium Inbox 폴더에 있는 발표자료 PDF를 읽어 Graspium 사이트(graspium-official.github.io)에 논문 카드로 올리고 DexVault에도 노트로 넣는다. "graspium 올려줘", "graspium 업데이트", "inbox 처리해줘", "읽은 논문 올려줘"에 사용한다.
---

# graspium-publish

사용자는 읽은 논문을 PPT로 정리한 뒤 PDF로 내보내 inbox에 넣기만 한다. 나머지는 이 절차로 처리한다.

## 경로

- Inbox: `C:\Users\Jay\01_Research\13_Graspium_Inbox` (처리 후 `done\`으로 이동)
- 사이트 저장소: `C:\Users\Jay\01_Research\08_Github\graspium-official.github.io`
- 등록 스크립트: 저장소의 `scripts/publish_local.py`, 실행은 저장소의 `.venv\Scripts\python.exe`
- 볼트: `C:\Users\Jay\01_Research\12_DexVault`

`.venv`가 없으면 저장소에서 `python -m venv .venv` 후 `.venv\Scripts\python -m pip install pymupdf pyyaml`.

## 절차

### 1. 준비
- Inbox 최상위의 `*.pdf`를 나열한다. 없으면 그렇게 알리고 끝낸다.
- 저장소에서 `git status`가 깨끗한지 확인하고 `git pull --rebase origin main`을 한다. 다른 멤버가 GitHub 이슈로 올린 논문이 봇 커밋으로 들어오기 때문에 매번 필요하다.

### 2. PDF마다: 읽고 항목 채우기
Read 도구로 PDF 전체를 읽는다(`pages`로 20쪽씩). 슬라이드에 없는 내용은 지어내지 않는다.

- `title`, `authors`: 슬라이드의 논문 제목으로 arXiv를 검색해 정확한 제목과 저자를 확인한다 (`https://export.arxiv.org/api/query?search_query=ti:"..."`, 이 PC에서는 인증서 문제로 파이썬 대신 `C:\Windows\System32\curl.exe`를 쓴다). 저자가 4명을 넘으면 앞 3명 뒤에 `et al.`을 붙인다. arXiv에 없으면 슬라이드에 적힌 대로 쓴다.
- `arxiv` 또는 `paper`: 확인된 arXiv ID. 없으면 DOI나 학회 페이지 URL. 그것도 없으면 비운다.
- `venue`: `_data/tags.yml`의 `known_venues` 중 하나. 게재처를 확인하지 못했으면 `arXiv`.
- `field`: `_data/tags.yml`의 `fields` 키 중 가장 가까운 하나.
- `lang`: 슬라이드 본문 언어. 한국어면 `kor`, 영어면 `eng`.
- `keywords`: 2~5개, 영어, 단어 첫 글자 대문자. 사이트의 기존 키워드와 같은 뜻이면 기존 표기를 그대로 쓴다(필터가 표기 단위로 묶인다). 기존 표기는 `_data/papers.yml`에서 확인한다.
- `presenter`: `Jaesung Lee` (사용자가 다른 사람 자료라고 하면 `_data/members.yml`의 이름으로).
- `tldr`: 영어 2~3문장. 무엇을 풀었고, 어떻게 했고, 결과가 무엇인지.
- `notes`: 슬라이드에서 사용자가 정리한 핵심을 5~10줄로. 슬라이드 언어를 따른다. 사용자의 의견이나 한계 지적이 있으면 포함한다.
- `thumb_page`: 논문의 전체 구조나 대표 그림이 가장 잘 보이는 슬라이드 쪽 번호. 제목 슬라이드는 피한다.
- `id_prefix`: `js`. 번호는 스크립트가 다음 빈 번호를 붙인다.
- `date`: 오늘.

이 값을 UTF-8 JSON으로 `13_Graspium_Inbox\done\<pdf 이름>.entry.json`에 Write 도구로 저장한다. `pdf`에는 inbox의 PDF 절대 경로를 적는다.

### 3. 확인과 등록
1. `python scripts/publish_local.py <entry.json> --dry-run`으로 검사한다. 오류가 나면 고친다. 같은 제목이 이미 사이트에 있으면 사용자에게 알리고 그 PDF는 건너뛴다.
2. 사용자에게 PDF별로 id, 제목, venue, field, keywords, tldr, 썸네일 쪽 번호를 보여 주고 올려도 되는지 묻는다. 사용자가 이번 실행에서 "확인 없이 올려"라고 했으면 묻지 않는다.
3. 승인되면 `--dry-run` 없이 실행한다. 생성된 `assets/thumbnails/<id>.png`를 Read로 열어 그림이 제대로 나왔는지 본다. 이상하면 `thumb_page`를 바꿔 다시 만든다(항목을 지우고 재실행).
4. 커밋하고 push한다.
   ```
   git add _data/papers.yml assets/thumbnails/<id>.png assets/slides/<id>.pdf
   git commit -m "Add paper <id>: <title>"
   git push origin main
   ```
   push가 인증 문제로 실패하면 멈추고 `gh auth login`이 필요하다고 알린다. 강제 push는 하지 않는다.
5. `gh run list --limit 1`로 배포가 시작됐는지 확인한다(gh가 로그인돼 있을 때).

### 4. 볼트에 넣기
볼트의 `CLAUDE.md`와 `.claude/skills/ingest-paper/SKILL.md` 절차대로 논문 노트를 만든다.
- 논문 원문 PDF를 받을 수 있으면 `raw/papers/arxiv-<id>.pdf`로 받아 원문 기준으로 노트를 쓴다.
- frontmatter에 `graspium: <id>`, `slides: <슬라이드 PDF의 사이트 경로>`를 추가한다.
- 사용자의 슬라이드 내용은 `## 내 정리` 섹션에 넣는다. 원문에서 확인한 내용과 섞지 않는다.
- 이미 같은 논문 노트가 있으면 새로 만들지 않고 보강한다.

### 5. 정리
- 처리한 PDF를 `done\<id>_<원래 이름>.pdf`로 옮긴다. 건너뛴 PDF는 inbox에 그대로 둔다.
- 올린 논문의 id와 제목, 사이트 주소(https://graspium-official.github.io), 볼트에 생긴 노트, 확인하지 못한 항목을 보고한다.

## 이미 올린 항목 고치기
`_data/papers.yml`에서 해당 id 블록을 직접 고치고 `Update paper <id>: <title>`로 커밋한다. 수정 후 저장소의 파이썬으로 `yaml.safe_load`가 통과하는지 확인한다.
