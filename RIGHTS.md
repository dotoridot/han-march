# 공개 범위와 제3자 고지

이 저장소는 작성자가 공개한 《초한: 한왕의 길》의 개발기와 단계별 소스입니다. 작성자의 게임 코드, 글, 도형과 제작 자료에는 별도의 오픈소스 라이선스를 부여하지 않았습니다. 제3자 자료에 적용되는 조건은 아래에 표시한 각 자료의 라이선스를 따릅니다.

- 1장의 전장과 그림은 게임에 포함된 Canvas 그리기 코드로 생성합니다. 별도 도시 원화나 외부 스프라이트를 사용하지 않습니다.
- 2장부터 Noto Sans KR을 사용합니다. [Google Fonts 고정 소스](https://github.com/google/fonts/tree/4efc2774c63917927efe769ca845def6bd6debae/ofl/notosanskr)에서 받은 글꼴을 사용합니다. SIL Open Font License 고지는 Godot 프로젝트의 `assets/OFL.txt`에 있습니다.
- 엔진은 [Godot 4.6.3](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable) (`7d41c59c4`)입니다. 엔진과 내보내기 템플릿은 공식 배포본에서 별도로 받습니다.
- 배포 앱, 서명, 로그, 빌드 캐시, 외부 런타임 바이너리는 이 저장소의 공개 Git 트리에서 제외했습니다. 초기 생성 원화와 출처 범위가 불명확한 앱 아이콘도 제외했습니다.

## 캠페인의 의존성과 그림

- [Dialogue Manager 4.0.0](https://github.com/nathanhoad/godot_dialogue_manager/tree/2162eff4ce74295390708b5e83c344523dec5ff0), [Godot Gameplay Systems 0.20.5](https://github.com/OctoD/godot-gameplay-systems/tree/d3e20d160ecbec75c30dcc219673416718430f1b)의 사용 소스를 포함합니다. 각각 MIT 고지를 `han-march/licenses/`에 보존했습니다. Gameplay Systems의 고정 소스와 일치한 GUT 시험 파일 두 개는 게임 실행에 쓰이지 않아 최신 트리에서 제외했습니다.
- [LimboAI v1.7.1](https://github.com/limbonaut/limboai/releases/tag/v1.7.1)은 GDExtension 4.6용 공식 ZIP을 받습니다. 고정 버전, SHA-256과 대상 경로는 `fetch-dependencies.sh`에서 확인할 수 있습니다. MIT 고지는 `han-march/licenses/LimboAI.txt`에 있습니다.
- [Nightfall](https://github.com/nykadamec/nightfall/tree/c6e36509885cfcbf054cfa1c7a48ab28f83f1a90)의 데이터 구조를 참고했습니다. 고지는 `han-march/licenses/Nightfall.txt`에 있습니다.
- 전장 도트는 이 프로젝트에서 작성했습니다. `han-march/design/paint_march.py`와 아틀라스를 포함합니다. [LibreSprite 1.3](https://github.com/LibreSprite/LibreSprite/tree/cdb12a323ce5ec4fce3512bc6590a90228f15bb9)은 편집에 사용한 별도 GPL v2 도구입니다.
