# 건축·아이템 이동: 42.21 적용 방식

## 0.4.1 지원 경로

싱글플레이 건축과 아이템 이동은 공통 create 경계에서 시간을 줄입니다. 두 생성자는 base allocator를 호출하지 않으므로 allocator만으로는 잡히지 않습니다. 이동의 후속 배치 시간도 보정하며 원래 이동 중 1.5배 보정과 완료·취소·용량 처리를 유지합니다.

멀티 아이템 이동은 **수동 클래스 복사 패치**로 지원합니다. `Transaction.getDuration()`의 최종 반환값에만 샌드박스 배율을 적용하고 원래 특성·무게·장갑 계산을 유지합니다. 서버의 `setTimeData` 이후 승인 응답은 단축된 기간을 기존 long 필드로 보내며, 원래 클라이언트가 해당 기간을 받아 사용합니다. 패킷과 참가자 Java는 변경하지 않습니다. Lua가 MP 이동 시간을 다시 줄이지 않으므로 중복 적용하지 않습니다.

패치 파일은 데디케이트 서버의 `java` 또는 게임 내 호스트의 일반 게임 설치 루트에 복사합니다. 기존 클래스 경로의 폴더 우선 검색을 사용하며, agent·추가 로더·시작 파일 수정이 필요 없습니다. 원본 JAR은 유지합니다. 배포물에는 수정한 원본 `Transaction.class` 한 개와 자체 helper 두 개만 포함합니다. 사용자가 이 클래스의 수동 배포를 명시적으로 승인한 범위입니다.

보정 helper는 `GameServer.server`, `LuaManager.env`, `KahluaTable.rawget` 공개 API로 서버 설정과 모드·충돌 상태를 읽습니다. 클라이언트/SP·미활성·충돌·설정 누락이면 원래 시간을 유지합니다. 단, **클래스 자체의 게임 버전 호환성은 이 설정 검사보다 앞선 문제**입니다. agent와 달리 원본 지문 불일치 시 원본 클래스로 되돌리는 런타임 보장이 없습니다. 오래된 복사본은 모드 비활성 서버에도 영향을 줄 수 있으므로 게임 업데이트 시 제거·지원 버전 확인이 필요합니다.

멀티 새 건축은 여전히 미지원입니다. `BuildActionPacket → ActionManager.start → BuildAction.start` 사이에 시간을 수정할 배포 가능한 Lua 이벤트나 객체 접근 함수가 확인되지 않았습니다. `OnProcessAction/OnProcessTransaction`은 이미 시간이 지난 완료 경로입니다. 관리자 큐는 private이며 debug reflection은 `Core.debug` 제한이 있어 사용하지 않습니다. Lua 다단계 건축, 철거·분해·바리케이드·마감과 벌목은 별도 허용 경로입니다.

## 읽기 전용 조사 근거

설치된 42.21 Lua와 게임 JAR의 클래스 코드를 확인했습니다. 조사용 추출·디컴파일 파일은 배포하지 않습니다. 예외는 사용자가 승인한 최종 수정 `Transaction.class` 한 개입니다.

- `ISBuildAction.lua:277`: MP 클라이언트는 `maxTime=-1`로 시작하며 서버 응답의 시간을 사용.
- `ISBuildIsoEntity.lua:859`, `ISBuildingObject.lua:199`: 새 건축 UI도 `ISBuildAction` 경로를 사용.
- `BuildAction.getDuration()`: 서버 Java가 목공 수준, Handy, 즉시 행동 여부 등을 기반으로 계산. Lua의 `ISBuildAction.maxTime`이나 건축 레시피 시간을 직접 조회하지 않음.
- `ISInventoryTransferAction.lua:168,854`: MP 클라이언트는 서버의 거래 기간·완료 응답을 사용.
- `Transaction.getDuration()`: 무게, 수납 상태, Dextrous/AllThumbs, 장갑 등에 따른 시간을 계산하고 배치 항목들의 최대 시간을 사용.
- `ItemTransactionPacket.processServer()`: 서버가 `setTimeData` 후 수락 응답을 전송.

## 선별 결과

| 방식 | 판단 | 적용 |
|---|---|---|
| 건축: 클라이언트 타이머·레시피만 단축 | 원래 서버 계산을 바꾸지 못함 | 제외 |
| 건축: 공개 Lua API로 승인 시간 조정 | 필요한 접근·훅·패킷 순서를 확인하지 못함 | 미지원 |
| 이동: 클라이언트 타이머만 단축 | 서버 완료 전에 표시만 앞서갈 수 있음 | 제외 |
| 이동: 서버 최종 시간 보정 | 기존 승인 기간 재사용, 참가자 Java 변경 불필요 | 수동 클래스 패치 |
| 이동: 여러 아이템을 한 거래에 묶음 | 별도의 배치·부분 거절·용량·취소 검증 필요 | 이번 기능에 포함하지 않음 |
| 건축: 서버 Java 시간 계산 수정 | 이동과 다른 계산 경로 | 이번 패치 대상에서 제외 |
| 이동: 무게·특성 임시 변경 | 인벤토리 규칙·동기화에 영향 | 제외 |

정적 패킷 경로와 Java 클래스 로드 검사는 실제 두 클라이언트 플레이 증거가 아닙니다. 현재 확인 범위와 남은 검증은 [verification.md](verification.md)를 참고하세요.
