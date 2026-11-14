# 배포 담당자 안내

이 폴더는 설치 안내와 검증된 설치파일을 공개 배포하기 위한 저장소입니다. 앱 소스나 개발 저장소의 Git 이력은 포함하지 않습니다.

## 최초 생성과 현재 릴리즈 복사

Windows에서 Git과 GitHub CLI(`gh`)를 설치하고 개발 저장소를 읽을 수 있는 계정으로 `gh auth login`을 완료하세요. 토큰을 문서나 채팅에 붙여넣을 필요는 없습니다.

이 폴더에서 PowerShell로 실행합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Publish-Distribution.ps1
```

이 명령은 다음 작업을 합니다.

1. 개발 저장소의 정식 `usage-tray-v1.4.5` 설치파일과 체크섬을 내려받고 SHA-256을 확인합니다.
2. `SJSK0517/usage-tray-codex`가 없으면 공개 저장소를 만듭니다.
3. 이 폴더의 문서·이미지·배포 도구만 `main`에 올립니다. 기존 원격 이력을 강제로 덮어쓰지 않습니다.
4. 새 저장소의 draft 릴리즈에 x64·ARM64 설치파일과 체크섬을 올리고 업로드 결과를 확인합니다.
5. 모든 검증이 끝나면 릴리즈를 게시합니다. 같은 태그의 정식 릴리즈가 이미 있으면 덮어쓰지 않습니다.

GitHub 연결 권한으로 새 저장소 생성이 제한되면 웹에서 빈 공개 저장소를 먼저 만든 뒤 같은 명령을 실행하세요. 처음 만든 README가 있어도 저장소를 클론한 뒤 이 문서들로 갱신하면 됩니다.

## 다음 버전

문서의 버전과 다운로드 링크 및 `RELEASE-NOTES.md`를 갱신한 다음 해당 태그로 실행하세요.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Publish-Distribution.ps1 -Tag usage-tray-v1.4.6
```

개발 저장소에서 빌드·검사가 완료되어 정식 게시된 릴리즈만 복사합니다. 원본 릴리즈는 삭제하거나 변경하지 않습니다. 이 저장소의 태그는 배포 문서 커밋을 가리키며 앱 소스 커밋을 뜻하지 않습니다.

## 검증된 릴리즈 가져오기

초기 v1.4.5 설치파일은 비공개 개발 저장소의 정식 릴리즈에서 그대로 복사했으며 `release-manifests/`에 기록한 SHA-256과 일치합니다. GitHub Actions의 가져오기 작업은 임시 `import/` 브랜치의 분할 파일을 원래 설치파일로 복원하고 크기·SHA-256과 업로드 결과를 검증한 뒤 릴리즈를 게시합니다. 앱 소스나 GitHub 인증 토큰은 이 저장소로 옮기지 않습니다.
