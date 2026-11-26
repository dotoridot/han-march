# 초한: 한왕의 길

## 0장. 게임을 한 번도 개발하지 않은 개발자의 이야기

최근 침착맨의 초한지 3부작을 보고 감명을 받았습니다. 게임을 한 번도 만들어 본 적 없었지만, 진나라가 무너진 뒤 유방이 한나라를 세우기까지의 이야기를 직접 플레이할 수 있는 게임으로 만들어 보고 싶었습니다.
[침착맨 초한지 1부](https://www.youtube.com/watch?v=_NTvvdtl0oM) / [2부](https://www.youtube.com/watch?v=1gP7JCCYZIs) / [3부](https://www.youtube.com/watch?v=kFcDFTYSz-w)

이 글과 일곱 개의 GitHub PR은 실제 개발이 끝난 뒤 Git 변경과 검증 기록을 바탕으로 다시 구성했습니다. PR은 지금 읽을 수 있도록 새로 열었습니다. 아래 표에서 PR을 열어 개발기를 읽고, 비교 링크에서 바로 앞 단계와의 코드 차이를 볼 수 있습니다.

앱을 만들 때는 버튼을 누른 결과를 확인하는 데 익숙했습니다. 첫 게임에서는 버튼 하나를 잘 눌러도 다음 순간이 달라졌습니다. 가까운 적을 때리는 동안 뒤에서 다른 적이 다가오고, 이동하면서 구조를 시도하면 진행이 끊깁니다. 같은 공격이라도 예고가 끝나기 전에 피했는지에 따라 결과가 달라집니다. 누른 버튼과 함께, 그 버튼을 누른 순간의 전장을 다뤄야 했습니다.

처음에는 패현과 오중의 거리를 눈높이에서 걸어 봤습니다. 패현에서는 소하와 군량을 나누고, 오중에서는 항량의 임무를 받아 수송 나루로 갔습니다. 거리에서 찾은 시설을 전략 지도에서도 선택할 수 있게 했습니다. 준비한 물자가 출정에 쓰이고 남은 물자가 귀환 뒤 창고로 돌아오는 것까지 연결했습니다. 이 실험은 기록으로 소개합니다. 함께 쓰인 도시와 거리 원화는 재배포 범위를 확인하기 어려워 제외했습니다.

다음 실험에서는 화면을 위에서 내려다보게 하고 두 번의 전투 사이에 야영지를 뒀습니다. 성문 앞에서 누구를 구했는지에 따라 야영지 보고가 달라지고, 거기서 회복한 동료와 등용한 장수가 군량고 공략에 나섭니다. 첫 PR은 브라우저에서 이 한 판을 다시 돌려볼 수 있는 지점입니다.

## 개발기 읽는 순서

| 장 | 달라진 점 | 실행 | 당시 검증 | 변경 |
| --- | --- | --- | --- | --- |
| 1. Canvas 2D로 좁힌 첫 전투 | 성문 방어, 야영지, 군량고 공략 | 브라우저에서 `index.html` 열기 | 규칙 9개와 오프라인 Chromium 완주 두 경로 | [PR #1](https://github.com/dotoridot/han-march/pull/1) / [비교](https://github.com/dotoridot/han-march/compare/main...chapter-01-browser) |
| 2. Godot 네이티브 전투 | 전투 XP, 강화, 성벽 사격 | `godot/project.godot` 열기 | headless 규칙 83개, 항우 유무 두 경로 | [PR #2](https://github.com/dotoridot/han-march/pull/2) / [비교](https://github.com/dotoridot/han-march/compare/chapter-01-browser...chapter-02-godot) |
| 3. 한중에서 건국까지 | 네 전장, 역사와 가상 행군, 체크포인트 | `han-march/project.godot` 열기 | 캠페인 규칙과 저장 복원. 장시간 회귀는 4장 | [PR #3](https://github.com/dotoridot/han-march/pull/3) / [비교](https://github.com/dotoridot/han-march/compare/chapter-02-godot...chapter-03-campaign) |
| 4. 회피 예고와 시드 재생 | 첫 경유마다 달라지는 사건, 경로 교차와 다시 재생 | `han-march/project.godot` 열기 | 8,472개 시드, 자동 검사 항목 235,778개 | [PR #4](https://github.com/dotoridot/han-march/pull/4) / [비교](https://github.com/dotoridot/han-march/compare/chapter-03-campaign...chapter-04-seeds) |
| 5. 1.2 기마 행군과 특기 | 3D 지도, 인장과 18면 주사위, 고정 적중 틱 | `han-march/project.godot` 열기 | 캠페인 78/78, 지도와 특기 85/85 | [PR #5](https://github.com/dotoridot/han-march/pull/5) / [비교](https://github.com/dotoridot/han-march/compare/chapter-04-seeds...chapter-05-mounted) |
| 6. 1.3 일러스트와 고정 틱 | 480프레임에서 파츠와 공유 리그로 | `han-march/project.godot` 열기 | 접촉 30/30, 48개 시드 재생 해시 유지 | [PR #6](https://github.com/dotoridot/han-march/pull/6) / [비교](https://github.com/dotoridot/han-march/compare/chapter-05-mounted...chapter-06-rig) |
| 7. 1.4 파츠 메시와 보조광 | 네 방향 표시, 외곽 메시, 조명 수신 범위 | `han-march/project.godot` 열기 | 투명 면적 근사 약 97% 감소, CPU 동기화 p95 증가 | [PR #7](https://github.com/dotoridot/han-march/pull/7) / [비교](https://github.com/dotoridot/han-march/compare/chapter-06-rig...chapter-07-mesh) |

## 단계별 실행

1. [브랜치 목록](https://github.com/dotoridot/han-march/branches)에서 보고 싶은 장을 고르세요. `main`은 이 개발기의 시작점입니다.
2. 1장은 내려받은 폴더의 `index.html`을 데스크톱 브라우저에서 여세요. WASD로 이동하고 클릭 또는 Space로 공격합니다. E를 길게 눌러 구조하고 Q로 동료를 모읍니다. 규칙 검사는 `node --test test/game.test.js`로 실행합니다.
3. 2장부터는 [Godot 4.6.3](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable)과 해당 브랜치의 의존성 받기 스크립트가 필요합니다. 브랜치 안의 `godot/README.md` 또는 `han-march/README.md`에서 프로젝트별 명령과 조작을 확인하세요.

표의 수치는 당시 원본에서 얻은 기록입니다. 이 공개 브랜치에서 다시 실행한 검사와 남은 범위는 각 PR의 테스트 절에 적었습니다. 공개본의 네이티브 여섯 장은 지정 Intel Mac에서 무음 headless로 주 장면이 시작되는 것까지 확인했습니다. 마지막 단계의 면적 수치는 CPU에서 계산한 근사값입니다. 실제 GPU 시간, 60fps 유지와 Windows 게임 실행은 확인되지 않았습니다.

게임 코드와 자료의 공개 범위는 [공개 범위와 제3자 고지](RIGHTS.md)에 있습니다.
