# 패현의 깃발 네이티브판

패현 성문을 지킨 뒤 야영지에서 장수를 정비하고 진군 군량고로 출정합니다. WASD로 이동하고 마우스 또는 Space로 공격합니다. E를 길게 눌러 구조하거나 성벽에 오르고 Q로 동료를 모읍니다. 피해와 지원으로 얻은 XP로 장수별 강화를 선택할 수 있습니다.

## 실행과 규칙 검사

저장소 루트에서 `sh fetch-dependencies.sh godot`을 실행해 한글 글꼴을 받으세요. [Godot 4.6.3](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable)에서 `godot/project.godot`을 열고 F6 대신 F5로 주 장면을 실행하세요.

`GODOT`에 Godot 실행 파일을 지정한 다음 저장소 루트에서 실행합니다.

```sh
profile=$(mktemp -d)
PEI_LOCAL_DATA="$profile" "$GODOT" --headless --audio-driver Dummy --path godot --editor --import --quit
PEI_LOCAL_DATA="$profile" "$GODOT" --headless --audio-driver Dummy --path godot --script res://tests/native_check.gd
```

[공개 범위와 제3자 고지](../RIGHTS.md)
