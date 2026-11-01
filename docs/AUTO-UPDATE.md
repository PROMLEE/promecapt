# 업데이트

Promecapt 1.1.0부터 Sparkle 2로 수동·자동 업데이트를 지원합니다.

## 사용

- **수동:** 메뉴 막대 → 업데이트 확인…, 또는 설정 → 정보 → 업데이트 확인…
- **자동(선택):** 설정 → 정보 → 자동으로 다운로드·설치하고 다시 실행. 기본값은 꺼짐입니다.
- 안정 버전만 확인하며 자동 확인 간격은 하루입니다. 옵션을 켤 때도 한 번 확인합니다.
- 캡처·녹화·주석 편집·OCR 결과·저장 전 GIF 결과가 열려 있으면 설치·재실행을 미룹니다.
- 정보 탭은 설치된 앱의 버전·빌드·소스 리비전·CPU·OS와 최신 확인 결과·시각을 표시합니다.
- 1.0.0에는 업데이터가 없으므로 1.1.0은 DMG로 한 번 직접 설치해야 합니다.

## 배포

아키텍처별 `appcast-arm64.xml` / `appcast-x86_64.xml`을 GitHub Releases의 안정 버전 자산으로 제공합니다. 앱에 각 CPU의 `releases/latest/download/appcast-CPU.xml` 주소와 Ed25519 공개 키를 포함합니다. 버전은 앱의 Info.plist에서 읽으며 별도의 UI 상수로 관리하지 않습니다.

`package.sh` → `package-dmg.sh` → `sign-release.sh` 순서로 생성합니다. 마지막 단계는 ZIP과 feed를 서명하고 앱에 포함된 공개 키로 ZIP 서명을 별도 검증합니다. 배포 파일과 feed는 같은 초안 릴리스에 올리고 함께 공개합니다. 이미 공개한 자산은 교체하지 않습니다.

GitHub Actions secret `SPARKLE_ED_PRIVATE_KEY`에 서명용 개인 키가 필요합니다. 키가 없거나 앱의 공개 키와 맞지 않으면 릴리스 작업이 실패합니다. 키를 로그·소스·릴리스 자산에 포함하지 마세요. 로컬 서명은 `generate-appcast.py --version VERSION --arch CPU --key-file PRIVATE_FILE`로 수행합니다.

## 서명과 권한

Sparkle은 feed와 업데이트 파일의 Ed25519 서명을 검증합니다. 서명 오류·네트워크 장애 시 현재 앱을 교체하지 않습니다. CPU별 feed를 사용하며 낮은 버전으로 자동 다운그레이드하지 않습니다. 설치 전에 고정 이미지·주석·그룹을 저장하고, 저장 실패 시 앱 종료를 취소합니다.

Apple Developer ID 서명·공증은 업데이트 서명과 별개이며 현재 배포본은 ad-hoc입니다. 첫 설치의 macOS 실행 확인과 교체 후 화면 캡처·손쉬운 사용 재연결이 필요할 수 있습니다. DMG를 이용해 Applications에 설치하세요.

개발자용: ad-hoc 빌드는 upstream 서명된 Sparkle 프레임워크를 로드하기 위해 이 앱의 Library Validation 예외 entitlement만 사용하며 Hardened Runtime은 유지합니다. Developer ID 빌드에서는 내부 구성부터 같은 identity로 서명하고 해당 예외를 적용하지 않습니다. 시스템 Gatekeeper 설정은 바꾸지 않습니다.

## 검증

- `swift test` 및 `bash scripts/test-local.sh`
- 서명된 정상 ZIP / 변조 ZIP / 다른 키로 서명한 ZIP
- 정보 탭의 수동 확인, 최신 버전·오류·마지막 확인 시각
- 자동 옵션 유지 및 작업 중 재실행 보류
- 별도 테스트 앱의 구버전 → 신버전 교체·재실행·버전 갱신
- 오프라인, 쓰기 불가 경로, 서명 오류에서 기존 앱·보관함 유지

DEBUG 전용 테스트 번들은 `com.promlee.promecapt.update-test` ID를 사용하며 보관함을 앱 옆 `TestLibrary`에 분리합니다. 이 번들에서만 loopback HTTP feed를 허용하며, release 빌드에는 이 예외가 없습니다. 테스트 파일을 공개 릴리스에 올리지 마세요.

공식 문서: [Sparkle 설정](https://sparkle-project.org/documentation/) · [업데이트 배포](https://sparkle-project.org/documentation/publishing/)
