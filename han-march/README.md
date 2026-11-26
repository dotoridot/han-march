# 초한: 한왕의 길 캠페인

한중에서 출발해 관중의 관문, 팽성의 철수, 형양과 성고의 보급 수송, 해하 전투를 거쳐 한 건국으로 이어집니다. 역사 행군과 가상 행군은 전장과 편성에서 다른 선택을 제공합니다. 관문의 세부 임무, 팽성의 나루와 들것, 가상 행군의 항우 합류는 게임을 위해 구성했습니다.

## 실행과 조작

저장소 루트에서 `sh fetch-dependencies.sh han-march`를 실행하세요. 이 명령에는 `curl`, `shasum`, `unzip`이 필요합니다. [Godot 4.6.3](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable)에서 `han-march/project.godot`을 열고 F5로 실행합니다. LimboAI가 제공하는 데스크톱 확장이 필요합니다.

- WASD 이동, 마우스 또는 J 공격, Space 또는 Shift 회피
- E 길게 눌러 전장의 목표와 상호작용, F 특기, Esc 일시정지
- C로 동료를 차례로 선택해 HP, MP, 피로 수치 확인
- Tab과 Enter로 메뉴 및 경유지 선택

전장 도중 종료하면 마지막 출발 체크포인트에서 재개합니다. 새 행군을 시작하면 편성과 강화가 초기화되고 발견한 기록이 남습니다.

## 무음 규칙 검사

`GODOT`에 실행 파일을 지정한 뒤 저장소 루트에서 실행합니다.

```sh
profile=$(mktemp -d)
export HAN_MARCH_PROFILE="$profile" HAN_MARCH_TEST_SAVE="$profile/roundtrip-check.cfg" HAN_MARCH_MUTE=1
"$GODOT" --headless --audio-driver Dummy --path han-march --editor --import --quit
"$GODOT" --headless --audio-driver Dummy --path han-march --script res://tests/campaign_check.gd
```

### 기마 지도, 접촉과 회피 검사

위 설정으로 import를 마친 뒤 같은 셸에서 실행합니다.

```sh
HAN_MARCH_PROFILE="$(mktemp -d)" "$GODOT" --headless --audio-driver Dummy --path han-march --script res://tests/relief_check.gd
HAN_MARCH_PROFILE="$(mktemp -d)" "$GODOT" --headless --audio-driver Dummy --path han-march --script res://tests/contact_feedback.gd
"$GODOT" --headless --audio-driver Dummy --path han-march --script res://tests/dodge_window.gd
```

### 파츠 외곽과 보조광 비교

위 무음 설정과 import를 마친 뒤 비교 모드를 실행합니다.

```sh
HAN_MARCH_DIRECTION_COMPARE=1 "$GODOT" --headless --audio-driver Dummy --path han-march --script res://tests/illustration_check.gd
```

두 군집에서 파츠 투영 면적, 삼각형 수, 조명 수신 파츠 수와 CPU 동기화 시간을 출력합니다. 실제 화면 프레임, GPU 시간과 드로우 콜은 렌더러가 있는 실행에서 `HAN_MARCH_PROFILE_RENDER=1`을 지정할 때만 계측을 시도합니다. 무음 headless 비교에서는 이 값이 비어 있습니다.

[공개 범위와 제3자 고지](../RIGHTS.md)
