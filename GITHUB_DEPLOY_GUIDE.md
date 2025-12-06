# 📤 GitHub 배포 가이드

이 프로젝트를 GitHub에 배포하는 방법을 설명합니다.

---

## 🚀 GitHub에 업로드하기

### 1️⃣ GitHub 계정에서 새 리포지토리 생성

**웹사이트**: https://github.com/new

**설정**:
- Repository name: `hangulasobi` (또는 선호하는 이름)
- Description: `Korean language learning game with speech recognition`
- Public 선택 (오픈소스)
- Initialize this repository with: **체크 해제** (이미 로컬에 커밋 있음)

**Create repository** 클릭

---

### 2️⃣ 로컬에서 원격 저장소 연결

생성 후 나타나는 명령어를 실행하거나, 아래 명령어를 사용:

```bash
# 로컬 저장소 디렉토리로 이동
cd /Users/systemi/hangulasobi

# 원격 저장소 추가 (yourname을 실제 GitHub 계정명으로 변경)
git remote add origin https://github.com/yourname/hangulasobi.git

# 브랜치명 확인 (main 또는 master)
git branch -M main

# 원격 저장소에 푸시
git push -u origin main
```

**예시** (GitHub 사용자명이 "awesome-dev"인 경우):
```bash
git remote add origin https://github.com/awesome-dev/hangulasobi.git
git branch -M main
git push -u origin main
```

---

### 3️⃣ GitHub 인증 (처음 실행 시)

Mac에서 처음 push할 때 인증이 필요합니다:

#### 옵션 A: Personal Access Token (추천)

1. **GitHub 설정에서 토큰 생성**:
   - https://github.com/settings/tokens/new
   - Scopes: `repo` 선택
   - 토큰 복사

2. **터미널에서 입력**:
   ```bash
   git push -u origin main
   ```
   - Username: GitHub 사용자명 입력
   - Password: **생성한 Personal Access Token 입력** (비밀번호 X)

#### 옵션 B: SSH Key

```bash
# SSH 키 생성 (이미 있으면 스킵)
ssh-keygen -t ed25519 -C "your_email@example.com"

# SSH 키 추가 (Mac Keychain)
ssh-add ~/.ssh/id_ed25519

# GitHub에 공개키 추가
# https://github.com/settings/keys → New SSH key
# cat ~/.ssh/id_ed25519.pub 내용 복사해서 붙여넣기

# SSH로 리모트 변경
git remote set-url origin git@github.com:yourname/hangulasobi.git

# 푸시
git push -u origin main
```

---

## 📋 GitHub에 있어야 할 파일 확인

```bash
# 현재 tracked 파일 확인
git ls-files | head -20

# 푸시될 파일 확인
git diff --name-only --cached

# 전체 상태 확인
git status
```

---

## ✅ 배포 후 확인 사항

### 1️⃣ GitHub 리포지토리 확인
- https://github.com/yourname/hangulasobi에서 파일 확인
- README.md가 제대로 표시되는지 확인

### 2️⃣ 태그 생성 (릴리스)

```bash
# v1.0.0 태그 생성
git tag -a v1.0.0 -m "Initial release"

# 태그 푸시
git push origin v1.0.0

# 또는 모든 태그 푸시
git push --tags
```

### 3️⃣ GitHub Releases 생성

1. GitHub 리포지토리에서 **Releases** 클릭
2. **Draft a new release** 클릭
3. 다음 정보 입력:
   - Tag version: `v1.0.0`
   - Release title: `Initial Release - Korean Language Learning Game`
   - Description:
     ```
     🎮 Korean language learning game with speech recognition

     ### Features
     - 3 difficulty levels (Beginner/Intermediate/Advanced)
     - Google Speech API integration
     - 200+ learning sentences
     - Complete offline support (iOS)
     - Refactored codebase

     ### What's New
     - Initial release
     - Full app implementation
     - Bug fixes and optimizations

     ### Installation
     - iOS: Download from App Store (coming soon)
     - Android: Download from Google Play (coming soon)
     - Or build from source: `flutter run`
     ```

---

## 🔄 향후 업데이트 배포

새로운 기능이나 버그 수정 후:

```bash
# 변경사항 추가
git add .

# 커밋 (명확한 메시지 사용)
git commit -m "[Feature] 새로운 기능 설명"

# 푸시
git push origin main

# (선택) 새 버전 릴리스
git tag -a v1.0.1 -m "Bug fix release"
git push origin v1.0.1
```

---

## 🌟 GitHub Pages (선택)

프로젝트 웹사이트를 자동으로 생성하려면:

1. **Settings** → **Pages**
2. **Source**: `main` branch 선택
3. `/docs` 폴더 선택 (또는 root)
4. **Save**

---

## 📊 GitHub Badges (선택)

README에 배지 추가:

```markdown
[![Flutter](https://img.shields.io/badge/Flutter-3.32.4+-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Stars](https://img.shields.io/github/stars/yourname/hangulasobi.svg)](https://github.com/yourname/hangulasobi/stargazers)
```

---

## 🛠️ 유용한 GitHub 기능

### 1️⃣ Issues 템플릿

`.github/ISSUE_TEMPLATE/bug_report.md` 생성:

```markdown
## 🐛 버그 설명
버그에 대해 명확하고 간결하게 설명하세요.

## 📋 재현 방법
1. 게임 실행
2. 상급 게임 선택
3. ...

## 🔍 예상 동작
어떻게 되어야 하는지

## 📱 환경
- 기기: iPhone 15
- iOS: 17.0
- 앱 버전: v1.0.0

## 📎 추가 정보
스크린샷이나 로그 추가
```

### 2️⃣ Pull Request 템플릿

`.github/pull_request_template.md` 생성:

```markdown
## 📝 변경사항
간단한 설명

## 🎯 관련 Issue
Closes #123

## ✅ 체크리스트
- [ ] 코드 검토 완료
- [ ] 테스트 통과
- [ ] 문서 업데이트
```

---

## 🎓 커밋 메시지 컨벤션

```
[Type] Subject (50글자 이하)

Body (선택, 72글자 이하로 줄바꿈)

Footer (선택, issue 번호 등)

Types:
- [Feature] 새로운 기능
- [Fix] 버그 수정
- [Refactor] 코드 정리
- [Docs] 문서 추가/수정
- [Test] 테스트 추가
- [Style] 코드 스타일
```

**예시**:
```
[Fix] 次へ 버튼 무한 로딩 현상 해결

- 타이머 주기 최적화 (500ms → 2초)
- 범위 체크 강화
- 디바운싱 추가

Fixes #42
```

---

## 🚨 주의사항

### 민감한 정보 제외
```bash
# API 키, 비밀번호 등이 포함된 파일 확인
git diff HEAD

# 이미 푸시한 경우 제거 (BFG 사용)
# https://rtyley.github.io/bfg-repo-cleaner/
```

### 파일 크기 확인
```bash
# 큰 파일 확인
find . -size +100M

# Git LFS 사용 (큰 바이너리 파일)
git lfs install
git lfs track "*.mp4"
```

---

## 📞 트러블슈팅

### 문제: "Permission denied" 에러

```bash
# SSH 확인
ssh -T git@github.com

# 또는 HTTPS로 변경
git remote set-url origin https://github.com/yourname/hangulasobi.git
```

### 문제: 큰 파일로 인한 푸시 실패

```bash
# 이전 커밋에서 파일 제거
git rm --cached large_file
git commit --amend
```

---

## 🎯 다음 단계

1. ✅ GitHub에 푸시 완료
2. 📝 프로젝트 설명 추가 (About 섹션)
3. 🏷️ Topics 추가: `flutter`, `korean`, `learning-game`, `speech-recognition`
4. 👥 Collaborators 추가 (선택)
5. 📢 릴리스 배포 (App Store, Google Play)

---

**완료! 🎉 GitHub에서 프로젝트를 공개했습니다.**
