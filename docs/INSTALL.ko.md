# Apple Developer 계정 없이 설치하기

**유료 Apple Developer 계정이 없어도 자기 Mac에서 Promecapt를 빌드하고 실행할 수 있습니다.** Developer ID 서명·공증은 다운로드 앱의 개발자와 배포 파일을 macOS가 검증하는 절차입니다. 공증이 없다고 제작자의 컴퓨터에서만 실행되는 것은 아닙니다.

소스에서 직접 빌드하거나 배포 ZIP을 사용할 수 있습니다. 두 방법 모두 화면 캡처 앱에 필요한 macOS 권한은 허용해야 합니다. 회사에서 관리하는 Mac은 설치·실행을 별도로 제한할 수 있으므로, 정책에 막히면 IT 담당자에게 확인하세요.

[English installation guide](INSTALL.md) · [한국어 README](../README.ko.md)

## 방법 A — 무료 개발 도구로 직접 빌드

### 1. Command Line Tools 설치

터미널에서 실행합니다.

```sh
xcode-select --install
```

Apple 설치 창에서 설치를 **완료한 다음** 다음 단계로 진행하세요. 이미 설치되어 있으면 설치되어 있다는 메시지가 나올 수 있습니다. 유료 개발자 가입, 인증서, App Store Connect 자격 증명은 필요 없습니다.

컴파일러 버전을 확인합니다.

```sh
swift --version
```

**Swift 5.9 이상**이 필요합니다. 앱 실행은 macOS 13 이상을 지원하지만, 빌드에는 해당 컴파일러를 제공하는 macOS·Command Line Tools 조합이 필요합니다. 버전이 낮으면 호환되는 Apple 개발 도구 또는 macOS를 업데이트하세요. 앱 패키징에는 전체 Xcode가 필요 없으며, XCTest 명령인 `swift test`를 실행할 때만 전체 Xcode가 필요합니다.

### 2. 배포 태그의 소스를 받아 앱 생성

소스를 보관할 폴더에서 실행합니다.

```sh
git clone --branch v1.0.0 --depth 1 https://github.com/PROMLEE/promecapt.git
cd promecapt
bash scripts/package.sh
```

완료되면 `dist/Promecapt.app`과 현재 Mac CPU용 ZIP이 만들어집니다. 기본적으로 이 Mac에서 **ad-hoc 서명**을 합니다. Apple Developer 로그인·인증서·개인 키·서명용 비밀값을 준비할 필요가 없고, 외부 Swift 패키지 의존성도 없습니다.

이 방법은 직접 소스를 빌드하는 것이며 Apple 공증을 받은 배포본이 되는 것은 아닙니다. 회사 관리 정책이나 macOS 접근 권한을 우회하지도 않습니다.

### 3. 내 응용 프로그램 폴더에 설치

기존 Promecapt가 실행 중이라면 먼저 종료하세요. 아래는 관리자 권한이 필요 없는 **사용자 개인 응용 프로그램 폴더**에 설치하는 명령입니다.

```sh
mkdir -p "$HOME/Applications"
ditto dist/Promecapt.app "$HOME/Applications/Promecapt.app"
open "$HOME/Applications/Promecapt.app"
```

권한이 있다면 Finder에서 `/Applications`로 옮겨도 됩니다. 여러 복사본을 동시에 사용하지 말고 **한 경로에 설치한 앱**을 계속 실행하세요. 평소에는 `swift run`이나 `.build` 안 실행 파일 대신 패키징된 `.app`을 실행해야 권한을 관리하기 쉽습니다.

### 4. 화면 캡처·손쉬운 사용 권한 허용

1. **시스템 설정 → 개인정보 보호 및 보안 → 화면 녹화**를 엽니다. 최신 macOS에서는 **화면 및 시스템 오디오 녹음**입니다.
2. **Promecapt**를 켜고, 요청하면 앱을 종료한 뒤 다시 실행합니다.
3. 내부 버튼·입력칸 감지와 안정적인 전역 단축키 처리를 위해 **손쉬운 사용**에서도 Promecapt를 허용합니다.
4. 메뉴 막대의 캡처 프레임 아이콘을 사용합니다. 기본 캡처 단축키는 `⌥⌘1`이며, 설정 → 단축키에서 F1 프리셋을 선택할 수 있습니다.

Dock 아이콘이 없어도 메뉴 막대에서 실행 중일 수 있습니다. 응용 프로그램 폴더에서 앱을 다시 열면 설정에 접근할 수 있습니다.

## 방법 B — 배포 ZIP 사용

1. [공식 Releases](https://github.com/PROMLEE/promecapt/releases)에서 Apple Silicon은 `arm64`, Intel은 `x86_64`를 받습니다.
2. ZIP의 SHA-256을 함께 제공되는 `.sha256` 파일과 비교합니다. 예를 들어 다운로드 폴더에서 `shasum -a 256 Promecapt-1.0.0-macos-arm64.zip`을 실행한 뒤 첫 해시값을 비교하세요.
3. 압축을 풀고 **Promecapt.app**을 응용 프로그램 폴더에 옮겨 한 번 실행합니다.
4. 현재 배포본은 ad-hoc 서명이며 **Developer ID 서명·Apple 공증이 없습니다.** 확인되지 않은 개발자·공증 문제로 차단된다면 먼저 소스와 체크섬을 확인하세요. 해당 앱을 신뢰하는 경우 [Apple의 앱별 실행 안내](https://support.apple.com/en-us/102445)에 따라, 실행을 시도한 뒤 **시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기(Open Anyway)**에서 앱 이름을 확인하고 진행할 수 있습니다.
5. 위의 화면 캡처·손쉬운 사용 권한을 설정합니다.

“손상된 앱” 또는 악성 소프트웨어 경고는 확인되지 않은 개발자 경고와 다릅니다. 그 경우에는 실행을 중단하고 다운로드를 확인하거나 유지보수자에게 문의하세요. Gatekeeper를 일괄 해제하는 명령이나 시스템 보안 해제는 필요하지 않습니다. 회사 관리 기기에서는 앱별 예외 자체가 제한될 수 있습니다.

## 자주 막히는 부분

| 증상 | 확인할 내용 |
| --- | --- |
| `xcode-select` 실행 후 설치 창이 뜸 | 설치를 끝낸 뒤 `swift --version`을 다시 실행합니다. |
| Swift가 5.9보다 낮음 | 호환되는 개발 도구·macOS를 업데이트한 뒤 빌드합니다. |
| 앱은 실행했는데 Dock에 없음 | 메뉴 막대 아이콘을 확인하거나 `.app`을 다시 열어 설정을 엽니다. |
| F1이 밝기 조절로 동작함 | `Fn+F1`, macOS 표준 기능키 설정 또는 다른 단축키를 사용합니다. |
| 화면 캡처 스위치는 켜져 있는데 거절됨 | 앱을 종료합니다. 새 ad-hoc 빌드라면 시스템 설정에서 기존 Promecapt 항목만 갱신하고, 실제 설치한 `.app`을 다시 연결한 뒤 실행합니다. 다른 앱의 권한은 건드리지 않습니다. |
| 버튼·입력칸이 감지되지 않음 | 손쉬운 사용 권한을 확인합니다. 대상 앱의 접근성 지원에 따라 감지 범위도 달라집니다. |
| 회사 Mac에서 실행이 차단됨 | IT 담당자에게 허용된 설치·로컬 빌드 절차를 확인합니다. 직접 빌드해도 조직 정책을 우회하지 않습니다. |

## 검증과 업데이트

`bash scripts/test-local.sh`는 Command Line Tools만으로 검사합니다. `swift test`는 전체 Xcode가 필요합니다. 배포는 Apple Silicon·Intel 양쪽 CI에서 검증합니다.

1.0.0에는 자동 업데이트가 없습니다. 업데이트할 때는 앱을 종료하고 새 공식 빌드로 교체하거나, 검토한 새 배포 태그를 같은 경로에 직접 빌드·설치하세요. 권한 문제를 해결하려고 캡처 보관함을 삭제할 필요는 없습니다.
