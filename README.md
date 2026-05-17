# inhaino-esp32cam

ESP32-CAM 기반의 Wi-Fi 카메라 웹 서버 프로젝트입니다.  
브라우저에서 실시간 영상 스트리밍을 확인할 수 있습니다.

---

## Features

- 실시간 MJPEG 스트리밍
- 브라우저 기반 카메라 컨트롤 UI (해상도, 밝기, 채도 등)
- PSRAM 유무에 따른 자동 품질 조절
- LED 플래시 지원 (핀 정의 시 자동 활성화)
- Wi-Fi 인증정보 분리 관리 (`secrets.h`)

---

## Supported Boards

`board_config.h`에서 사용할 보드를 주석 해제하여 선택합니다.

| 보드 | PSRAM |
|---|:---:|
| ESP-EYE *(기본값)* | ✓ |
| ESP32-S3 EYE | ✓ |
| AI Thinker ESP32-CAM | ✓ |
| M5Stack PSRAM | ✓ |
| M5Stack Wide | ✓ |
| WROVER Kit | ✓ |
| TTGO T-Journal | — |
| XIAO ESP32S3 | ✓ |

> PSRAM이 있는 보드는 UXGA 해상도와 높은 JPEG 품질을 지원합니다.

---

## Requirements

- [Arduino IDE](https://www.arduino.cc/en/software) 2.x 또는 [arduino-cli](https://arduino.github.io/arduino-cli/)
- ESP32 Arduino Core (`espressif:esp32`)
- 파티션 스킴: **최소 3MB APP** 공간 확보 필요 (Custom 파티션 사용)

---

## Getting Started

### 1. 저장소 클론

```sh
git clone https://github.com/your-org/inhaino-esp32cam.git
cd inhaino-esp32cam
```

### 2. Wi-Fi 인증정보 설정

```sh
# secrets.h는 이미 초기 커밋에 포함되어 있습니다.
# 실제 SSID / Password 로 수정하세요.
```

`secrets.h` 편집:

```cpp
#define WIFI_SSID     "your_ssid_here"
#define WIFI_PASSWORD "your_password_here"
```

수정 후 git이 변경사항을 추적하지 않도록 설정:

```sh
git update-index --skip-worktree secrets.h
```

### 3. 보드 선택

`board_config.h`에서 사용 중인 보드에 맞는 `#define`을 활성화합니다.

```cpp
// 예: AI Thinker 사용 시
// #define CAMERA_MODEL_ESP_EYE
#define CAMERA_MODEL_AI_THINKER  // ← 이 줄을 활성화
```

### 4. 빌드 및 업로드

Arduino IDE에서 `CameraWebServer.ino`를 열고 보드와 포트를 선택한 뒤 업로드합니다.

---

## Usage

업로드 완료 후 시리얼 모니터(115200 baud)를 열면 IP 주소가 출력됩니다.

```
WiFi connected
Camera Ready! Use 'http://192.168.x.x' to connect
```

브라우저에서 해당 주소에 접속하면 스트리밍 UI를 사용할 수 있습니다.

---

## Project Structure

```
inhaino-esp32cam/
├── CameraWebServer.ino   # 메인 스케치 (Wi-Fi 연결, 카메라 초기화)
├── app_httpd.cpp         # HTTP 서버 및 스트리밍 핸들러
├── camera_pins.h         # 보드별 GPIO 핀 정의
├── camera_index.h        # 웹 UI (HTML/CSS/JS, gzip 인코딩)
├── board_config.h        # 카메라 모델 선택
├── partitions.csv        # 커스텀 파티션 테이블
├── secrets.h             # Wi-Fi 인증정보 (git 추적 제외)
├── secrets.h.example     # 인증정보 템플릿
└── ci.yml                # arduino-lint CI 설정
```

---

## Credential Management

| 파일 | git 추적 | 용도 |
|---|:---:|---|
| `secrets.h` | 최초 1회 | 실제 Wi-Fi 인증정보 |
| `secrets.h.example` | 항상 | 팀원용 템플릿 |

`secrets.h`는 `.gitignore`에 등록되어 있습니다.  
초기 커밋 이후 로컬 변경사항이 추적되지 않으려면 아래 명령어를 실행하세요.

```sh
git update-index --skip-worktree secrets.h
```

---

## License

MIT
