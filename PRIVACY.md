# 공개 배포 정보 관리

설치 안내·데모 이미지·검증된 설치파일만 공개합니다. 로그인 인증 파일, API 키, 개인 설정, 실제 계정 화면, 개인 이메일을 배포 자료에 넣지 않습니다.

배포 작업 폴더에서는 커밋 작성자를 GitHub 아이디와 비공개 이메일로 설정합니다.

```sh
git config --local user.name SJSK0517
git config --local user.email 108185213+SJSK0517@users.noreply.github.com
```

다른 기여자는 자신의 GitHub 아이디와 GitHub가 제공하는 noreply 이메일을 사용하세요. GitHub 계정의 이메일 설정에서도 이메일 비공개 및 개인 이메일이 노출되는 명령줄 push 차단을 설정할 수 있습니다.

Python 3가 설치된 작업 폴더에서 다음 설정을 하면 push 전에 자동 검사합니다.

```sh
git config --local core.hooksPath scripts/git-hooks
```

push 전에는 다음 검사를 실행합니다.

```sh
python3 scripts/check-privacy.py HEAD
```

이 검사는 Git 작성자 이메일, 인증 파일명, 일반적인 토큰·비밀키 및 텍스트 이메일 패턴을 검사합니다. 이미지 속 글자와 모든 종류의 개인정보를 자동 판별하는 도구는 아니므로 이미지·첨부파일은 별도로 확인해야 합니다.

Git 이력을 변경하더라도 옛 커밋 주소, PR 내부 참조, GitHub 캐시나 이미 내려받은 복사본이 함께 삭제되지는 않습니다. 과거 공개 정보 삭제가 필요하면 GitHub의 민감 정보 제거 지원 절차를 추가로 진행해야 합니다.
