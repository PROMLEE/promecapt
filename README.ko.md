<div align="center">
  <img src="assets/app-icon.svg" width="112" alt="Promecapt 아이콘">
  <h1>Promecapt</h1>
  <p><strong>캡처하고, 바로 편집하고, 곁에 고정하세요.</strong></p>
  <p>상용 캡처 도구의 오픈소스 대안 — macOS 캡처·주석·화면 고정·GIF 녹화</p>
  <p><a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <a href="README.ja.md">日本語</a> · <a href="README.zh-CN.md">简体中文</a></p>
  <p><a href="https://github.com/PROMLEE/promecapt/releases">다운로드</a> · <a href="https://github.com/PROMLEE/promecapt/issues">문제 제보</a></p>
  <p>macOS 13 이상 · Apple Silicon / Intel · MIT 라이선스 · v1.0.0</p>
</div>

![캡처·주석·고정 작업 흐름을 설명하는 일러스트](assets/overview.svg)

## 주요 기능

- **그 자리에서 캡처·편집:** 창·앱 요소 자동 감지, 직접 영역 지정, 8개 핸들과 키보드로 크기·위치 조절.
- **다시 선택해서 고치는 주석:** 펜, 형광펜, 사각형, 타원, 선, 화살표, 텍스트, 번호. 선택 도구로 이동·크기·속성을 수정합니다.
- **통합 가리기:** 모자이크·블러·블랙박스. 휠이나 숫자 증감 버튼으로 두께·세기를 조절합니다.
- **이미지·GIF 화면 고정:** 확대·축소, 투명도, 그룹, 클릭 통과, 재시작 후 복원. GIF는 움직이는 상태로 고정됩니다.
- **영역 OCR:** 필요한 글자 범위만 드래그하고 결과를 확인·수정·복사합니다. 현재 인식 언어는 한국어·영어입니다.
- **캡처 기록:** `,` / `.`로 이전·다음 기록과 당시 바깥 화면을 불러옵니다.
- **GIF 녹화:** 녹화 범위 표시, 프레임·해상도·시간 설정, 결과 미리보기·복사·고정·저장.
- **앱 UI 다국어:** 한국어·영어·일본어·중국어 간체. 시스템 자동 선택과 직접 지정을 지원합니다.

## 설치

**다른 Mac에서도 유료 Apple Developer 계정 없이 직접 빌드·실행할 수 있습니다.** 아래 두 방법 중 선택하세요.

1. **무료 개발 도구로 직접 빌드:** Command Line Tools 설치 → 배포 태그 소스 받기 → `bash scripts/package.sh` → 생성한 `.app` 설치 순서입니다. [상세 로컬 설치 가이드](docs/INSTALL.ko.md)와 아래 명령을 제공합니다.
2. **배포 ZIP 사용:** [Releases](https://github.com/PROMLEE/promecapt/releases)에서 Apple Silicon은 **arm64**, Intel은 **x86_64**를 받아 압축을 풀고 **Promecapt.app**을 응용 프로그램 폴더에 옮깁니다.

현재 ZIP은 ad-hoc 서명이며 **Developer ID 서명·Apple 공증은 없습니다.** 다른 컴퓨터에서 설치 불가능하다는 뜻이 아니라, 다운로드 앱의 최초 실행 때 macOS가 차단할 수 있다는 뜻입니다. 신뢰하는 파일이라면 [Apple의 앱별 실행 안내](https://support.apple.com/en-us/102445)와 [설치 문제 해결](docs/INSTALL.ko.md#방법-b--배포-zip-사용)을 참고하세요. 회사에서 관리하는 Mac은 별도 정책이 적용될 수 있습니다.

첫 캡처 전 **시스템 설정 → 개인정보 보호 및 보안 → 화면 녹화**(최신 macOS는 **화면 및 시스템 오디오 녹음**)에서 Promecapt를 허용하고, 요청하면 다시 실행합니다. 앱 내부 요소 감지와 안정적인 전역 단축키 처리는 손쉬운 사용 권한을 사용합니다. 오디오는 녹음하지 않습니다. 메뉴 막대의 캡처 프레임 아이콘에서 시작하세요.

## 빠른 사용법

| 동작 | 기본 단축키 / 조작 |
| --- | --- |
| 영역·창 캡처 | `⌥⌘1` → 드래그 또는 감지된 대상 클릭 |
| 캡처 복사 / 고정 | `⌘C` / `⌘Enter` |
| 클립보드 고정 | `⌥⌘3` |
| 고정 이미지 모두 표시·숨기기 | `⌥⌘4` |
| 이전·다음 캡처 기록 | 캡처 중 `,` / `.` |
| 캡처 취소 / 고정 창 닫기 | `Esc` |
| 설정 | 메뉴 막대 아이콘 → 설정, 또는 앱 활성 상태에서 `⌘,` |
| 두께·가리기 세기 | 이미지 위 휠 또는 숫자 증감 버튼 |
| 고정 이미지 이동 / 확대·축소 | 드래그 / 휠 |
| 투명도 | `Ctrl` + 휠 |
| 정지 이미지 고정 주석 편집 | `Space`; 기존 주석 수정은 선택 도구 사용 |
| GIF 녹화 | 메뉴의 GIF 영역 녹화 또는 캡처 도구 막대의 GIF 버튼 |

설정 → 단축키에서 **F1 / F3 / F4** 프리셋과 사용자 조합을 지정합니다. 밝기·음량 키 모드라면 `Fn+F1`을 사용하거나 macOS의 표준 기능키 설정을 켜세요. `Enter`는 텍스트를 확정하며 캡처를 끝내지 않습니다. 설정 → 일반에서 언어와 Dock 표시 여부를 바꿀 수 있습니다.

## GIF 설정과 결과

설정 → GIF에서 **5~30fps**, **긴 변 640·1280·1920px 또는 원본 Retina 픽셀**, **최대 15·30·60초**, 커서 포함 여부를 선택합니다. 원본보다 확대하지 않으며 정지 화면에서는 프레임 수가 줄어들 수 있습니다. 임시 프레임 파일이 256MiB에 도달해도 녹화를 마칩니다.

녹화 범위는 빨간 점선과 바깥쪽의 옅은 음영으로 표시하며 마우스 조작을 막지 않습니다. 정지하면 결과 창에서 재생을 확인하고 **복사·고정·저장**합니다. 복사에는 GIF 원본 데이터·첨부 파일 경로·PNG 대체본을 함께 제공하므로, 붙여넣는 앱의 GIF 지원 여부에 따라 움직임이 달라질 수 있습니다. 한 화면 안의 영역만 녹화하며 Promecapt 자체 창과 오디오는 포함하지 않습니다. GIF 주석·회전·프레임 편집은 아직 지원하지 않습니다.

## 개인정보와 보관

이미지와 OCR은 이 Mac에서 처리합니다. 계정·업로드 서버·분석 수집 기능이 없습니다.

기록에는 선택 이미지뿐 아니라 **당시 화면 전체와 선택 위치**도 로컬에 저장합니다. 민감한 화면을 캡처할 때 이를 고려하세요. 보관 개수 제한과 기록 삭제는 배경도 함께 정리하며, 고정 이미지는 별도로 보관합니다.

설정과 보관함은 이 Mac에 유지됩니다. 복사한 GIF 첨부 파일은 로컬 캐시에 보관되며, 새로 복사할 때 오래된 캐시를 정리합니다.

## 직접 빌드

`xcode-select --install`로 무료 개발 도구를 설치하고 설치 완료 후 `swift --version`으로 Swift 5.9 이상인지 확인하세요. **유료 Apple Developer 계정·인증서·서명용 비밀값은 필요 없습니다.** 전체 Xcode는 `swift test`에만 필요하며 앱 패키징에는 필요 없습니다. 기존 앱은 교체 전에 종료하세요. 아래는 관리자 권한 없이 개인 응용 프로그램 폴더에 설치하는 명령입니다. [전체 절차와 권한 문제 해결](docs/INSTALL.ko.md)을 참고하세요.

```sh
git clone --branch v1.0.0 --depth 1 https://github.com/PROMLEE/promecapt.git
cd promecapt
bash scripts/package.sh
mkdir -p "$HOME/Applications"
ditto dist/Promecapt.app "$HOME/Applications/Promecapt.app"
open "$HOME/Applications/Promecapt.app"
```

CI는 Apple Silicon·Intel에서 XCTest를 실행합니다. 패키징 시 `ARCH=arm64` 또는 `ARCH=x86_64`를 지정할 수 있습니다. [검증](docs/QA.md) · [배포](docs/RELEASING.md) · [변경 기록](CHANGELOG.md) · [기여 안내](CONTRIBUTING.md)를 참고하세요.

**1.0.0에는 자동 업데이트가 구현되어 있지 않습니다.** Developer ID 서명·공증과 서명된 업데이트를 준비할 예정이며, [설계 문서](docs/AUTO-UPDATE.md)를 제공합니다.

## 라이선스

[MIT](LICENSE). 라이선스 조건에 따라 개인·상업적 사용, 수정, 재배포가 가능합니다. 앱과 메뉴 막대 아이콘은 자체 공통 캡처 프레임 심벌로 생성합니다.

## LLM용 문서

문서 색인은 [llms.txt](llms.txt), 통합 가이드는 [llms-full.txt](llms-full.txt), 단수 파일명 호환 진입점은 [llm.txt](llm.txt)입니다. 설치·사용·개인정보·기능 제한을 원문 Markdown으로 연결합니다. 파일을 제공한다고 모든 검색 엔진이나 AI가 자동으로 읽는 것은 아닙니다.
