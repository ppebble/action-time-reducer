# 건축·아이템 이동: 42.21 적용 방식 선별

## 근거

설치된 42.21의 Lua와 projectzomboid.jar에서 추출한 클래스 코드를 읽었습니다. 추출/디컴파일 결과는 조사 작업공간에만 두고 모드 배포물에는 포함하지 않습니다.

- `ISBuildAction.lua:277`: MP 클라이언트는 maxTime=-1로 시작하며 서버 응답의 시간을 사용.
- `ISBuildIsoEntity.lua:859`, `ISBuildingObject.lua:199`: 새 건축 UI도 ISBuildAction 경로를 사용.
- `zombie.core.BuildAction.getDuration()`: 서버 Java가 목공 수준, Handy, 즉시 행동 여부 등을 기반으로 시간을 계산. Lua의 ISBuildAction.maxTime이나 건축 레시피 시간을 직접 조회하지 않음.
- `ISInventoryTransferAction.lua:168,854`: MP 클라이언트는 서버의 ItemTransaction 기간/완료 응답을 사용.
- `zombie.core.Transaction.getDuration()`: 무게, 수납 상태, Dextrous/AllThumbs, 장갑 등에 따른 시간을 계산하고 배치 항목들의 최대 시간을 사용.
- `ItemTransactionPacket.processServer()`: 서버가 setTimeData 후 수락 응답을 전송.

## 선별 결과

| 대상/방식 | 판단 | 이번 버전 |
|---|---|---|
| 건축: 클라이언트 maxTime 또는 create만 단축 | 서버 계산이 그대로여서 실제 MP 완료 가속을 보장하지 못함 | 제외 |
| 건축: 레시피 시간만 단축 | 조사한 ISBuildAction 서버 경로에는 반영되지 않음 | 제외 |
| 건축: 공개 API로 서버 행동의 승인 시간 조정 | Java 교체 없이 가능한 후보지만, 해당 Lua 접근·훅·승인 패킷 순서를 확인하지 못함 | 향후 조사 후보; 가능하다고 확정하지 않음 |
| 이동: 클라이언트 타이머만 단축 | 서버 거래 완료 전에 표시만 앞서갈 수 있음 | 제외 |
| 이동: 여러 아이템을 한 거래에 배치 | Lua 큐에서 구성할 수 있는 후보. Java 배치 시간은 최댓값이라 총 대기가 줄어들 수 있음 | 별도 기능 후보; 기본 getDuration 가속에는 포함하지 않음 |
| 건축/이동: 서버 Java 시간 계산 수정 | 명확한 조정 지점은 있으나 버전 고정/배포/다른 Java 모드 충돌 부담 | 사용자 요청 범위 밖; 제외 |
| 이동: 무게나 특성을 임시 변경 | 실제 인벤토리/게임 규칙/동기화에 영향 | 채택하지 않음 |

Lua 전송 배치화를 구현하려면 원래 거래를 보존하면서 같은 출발·도착 컨테이너별로만 묶고, 서버 개수 제한과 각 아이템의 ID/권한/용량 검사·취소·완료를 유지해야 합니다. 바닥/거래 UI/카트/ProximityInventory와의 상호작용, 부분 거절, 접속 종료를 별도 검증해야 합니다. 이를 단순 시간 배율 기능과 같은 것으로 취급하지 않습니다.

현 버전은 이 모든 경로를 건드리지 않습니다. 가속되는 ISDismantleAction은 일부 구조물 분해이며, 건축 배치나 아이템 이동과는 별개입니다.
