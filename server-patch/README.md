# Safe Action Time 서버 전용 아이템 이동 패치 — 0.3.0

이 패치는 서버 운영자만 설치합니다. 일반 참가자는 Java 수정이나 로더 설치가 필요 없습니다. 싱글플레이도 이 패치가 필요 없습니다.

게임 파일을 덮어쓰지 않고 서버 JVM 시작 시 원래 아이템 이동 시간 계산의 반환값에 샌드박스 단축률만 적용합니다. 기존 민첩함·무게·수납·장갑 보정, 승인/거절/취소/결과와 패킷 형식은 유지합니다. 패킷 변경 없이 접속자의 원래 코드가 서버 시간을 받아 사용합니다.

## 설치 (Windows PowerShell)

서버와 참가자에게 동일한 일반 ActionTimeReducer 모드를 활성화하고 샌드박스의 아이템 이동 단축률을 설정합니다. 기본 0은 원래 시간입니다.

다운로드한 서버 패치 폴더에서 실행합니다.

```powershell
./install-server-patch.ps1 -ServerRoot '서버 설치 폴더'
```

설치된 서버 폴더의 ActionTimeReducer-server에서 기존 시작 파일을 지정해 실행합니다.

```powershell
./start-server.ps1 -Launcher 'StartServer64.bat' -ServerArguments @('-servername', '서버이름')
```

이미 서버이름을 포함한 전용 시작 파일이 있다면 그 파일명을 Launcher에 지정하세요. 원래 시작 파일의 인수 처리 제한도 그대로 유지됩니다. 이 래퍼로 시작해야 패치가 적용됩니다. 게임에 포함된 Java 25를 사용합니다. 콘솔의 `[ActionTimeReducer] Supported server inventory duration hook installed.` 메시지로 실제 적용 여부를 확인하세요. `armed`는 로드를 기다리는 상태이며 `DISABLED`가 나오면 기본 시간을 유지합니다.

원래 서버 jar와 시작 파일은 수정하지 않습니다. 기존 서버 설정, 저장, 프리셋도 수정하지 않습니다. 이 패키지는 빌드 시 기록한 Transaction.class SHA-256에만 적용됩니다. 게임 업데이트나 다른 Java 모드가 이 클래스를 변경했다면 새 버전에 맞춰 재검증·재빌드해야 합니다.

## 해제

서버를 종료한 뒤 기존 시작 파일로 직접 실행하면 패치가 적용되지 않습니다. 파일도 제거하려면 설치된 폴더에서 uninstall-server-patch.ps1을 실행하세요. 알 수 없는 파일이 있으면 삭제를 중단합니다.

## 범위

멀티 아이템 이동만 지원합니다. 멀티 새 건축 배치는 별도 미지원입니다. 이 패치를 클라이언트나 싱글플레이 시작 과정에 넣을 필요가 없습니다.

실제 두 클라이언트 접속·아이템 이동 검증 상태는 저장소 docs/verification.md를 확인하세요. 패킷 코드 및 JVM 검사와 실제 플레이 증거는 구분합니다.
