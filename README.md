# InhaIno ESP32 CAM

[![Build](https://github.com/inha-fc/inhaino-esp32cam/actions/workflows/build.yml/badge.svg)](https://github.com/inha-fc/inhaino-esp32cam/actions/workflows/build.yml)
[![Arduino IDE](https://img.shields.io/badge/branch-arduino--ide-blue?logo=arduino)](https://github.com/inha-fc/inhaino-esp32cam/tree/arduino-ide)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

ESP32-CAM 기반의 Wi-Fi 카메라 웹 서버 프로젝트입니다.  
브라우저에서 실시간 영상 스트리밍과 카메라 설정을 제어할 수 있습니다.

---

## Branches

| 브랜치 | 용도 |
|---|---|
| `main` | 소스 코드, 웹 UI 편집, CI 설정 |
| `arduino-ide` | Arduino IDE에서 바로 열 수 있는 자동 빌드 결과물 |

`main`에 push하면 `arduino-ide` 브랜치가 자동으로 업데이트됩니다.

```sh
# Arduino IDE용 브랜치 바로 클론
git clone -b arduino-ide https://github.com/inha-fc/inhaino-esp32cam.git
```

---

## Features

- 실시간 MJPEG 스트리밍
- 브라우저 기반 카메라 컨트롤 UI (해상도, 밝기, 채도, 화이트밸런스 등)
- 센서 자동 감지 및 전용 UI 제공 (OV2640 / OV3660 / OV5640)
- PSRAM 유무에 따른 자동 화질 조절
- LED 플래시 지원 (핀 정의 시 자동 활성화)
- Wi-Fi 인증정보 및 카메라 접속 계정 분리 관리 (`secrets.h`)
- HTTP Basic Auth 기반 인증 (전체 엔드포인트 보호)
- REST API (JSON 응답) + MQTT 통신 지원
- GitHub Actions 멀티 보드 빌드 검증 (ESP32 / S2 / S3, PSRAM on/off)
- `arduino-ide` 브랜치 자동 배포

---

## Supported Boards

`CameraWebServer/board_config.h`에서 사용할 보드를 주석 해제하여 선택합니다.

| 보드 | PSRAM |
|---|:---:|
| **AI Thinker ESP32-CAM** *(기본값)* | ✓ |
| ESP-EYE | ✓ |
| ESP32-S3 EYE | ✓ |
| M5Stack PSRAM | ✓ |
| M5Stack Wide | ✓ |
| WROVER Kit | ✓ |
| XIAO ESP32S3 | ✓ |
| TTGO T-Journal | — |

> PSRAM이 있는 보드는 UXGA 해상도와 높은 JPEG 품질을 지원합니다.

---

## Project Structure

```
inhaino-esp32cam/
├── .github/
│   └── workflows/
│       ├── build.yml                # 멀티 보드 빌드 검증
│       └── deploy-arduino-ide.yml   # arduino-ide 브랜치 자동 배포
├── CameraWebServer/                  # Arduino 스케치 폴더
│   ├── CameraWebServer.ino           # 메인 스케치
│   ├── app_httpd.cpp                 # HTTP 서버 및 스트리밍 핸들러
│   ├── board_config.h                # 카메라 모델 선택
│   ├── camera_index.h                # 웹 UI (gzip 인코딩된 HTML)
│   ├── camera_pins.h                 # 보드별 GPIO 핀 정의
│   ├── ci.yml                        # 빌드 매트릭스 정의 (FQBN 목록)
│   ├── partitions.csv                # 커스텀 파티션 테이블
│   ├── secrets.h                     # Wi-Fi 인증정보 (변경사항 추적 제외)
│   └── secrets.h.example             # 인증정보 템플릿
├── Scripts/
│   ├── extract_html.sh               # camera_index.h → index/*.html 추출
│   └── pack_html.sh                  # index/*.html → camera_index.h 재생성
├── index/
│   ├── common/
│   │   └── style.css                 # 센서 공통 CSS
│   ├── ov2640.html                   # OV2640 웹 UI 소스
│   ├── ov3660.html                   # OV3660 웹 UI 소스
│   └── ov5640.html                   # OV5640 웹 UI 소스
├── .gitignore
├── LICENSE
└── README.md
```

---

## Getting Started

### 1. 저장소 클론

```sh
git clone https://github.com/inha-fc/inhaino-esp32cam.git
cd inhaino-esp32cam
```

### 2. Wi-Fi 인증정보 설정

`CameraWebServer/secrets.h`를 편집합니다.

```cpp
#define WIFI_SSID     "your_ssid_here"
#define WIFI_PASSWORD "your_password_here"
```

수정 후 git이 변경사항을 추적하지 않도록 설정:

```sh
git update-index --skip-worktree CameraWebServer/secrets.h
```

### 3. 보드 선택

`CameraWebServer/board_config.h`에서 사용 중인 보드의 `#define`을 활성화합니다.

```cpp
// #define CAMERA_MODEL_ESP_EYE
#define CAMERA_MODEL_AI_THINKER   // ← 현재 설정
```

### 4. 빌드 및 업로드

#### 보드 매니저 설치 (최초 1회)

`File → Preferences → Additional boards manager URLs`에 추가:

```
https://espressif.github.io/arduino-esp32/package_esp32_index.json
```

`Tools → Board → Boards Manager`에서 **esp32 by Espressif Systems** 설치.

#### Tools 메뉴 설정

| 항목 | 값 |
|---|---|
| **Board** | `ESP32 Wrover Module` |
| **Upload Speed** | `115200` |
| **CPU Frequency** | `240MHz (WiFi/BT)` |
| **Flash Frequency** | `80MHz` |
| **Flash Mode** | `DIO` |
| **Flash Size** | `4MB (32Mb)` |
| **Partition Scheme** | `Huge APP (3MB No OTA/1MB SPIFFS)` |
| **PSRAM** | `Enabled` |
| **Port** | 연결된 시리얼 포트 선택 |

> "AI Thinker ESP32-CAM" 보드 항목은 PSRAM 활성화 옵션이 없으므로 `ESP32 Wrover Module`을 사용합니다.

#### 하드웨어 연결 (USB-to-Serial 어댑터 필요)

AI Thinker ESP32-CAM은 전용 USB 포트가 없어 FTDI / CH340 어댑터가 필요합니다.

```
ESP32-CAM    USB-Serial
GND      →   GND
5V       →   5V
UOR(RX)  →   TX
UOT(TX)  →   RX
IO0      →   GND  ← 업로드 모드 진입용
```

#### 업로드 순서

1. `IO0 → GND` 연결 상태에서 **RST 버튼** 누르기 (부트로더 모드 진입)
2. Arduino IDE에서 **Upload** 클릭
3. `Connecting........` 메시지가 뜨면 업로드 진행됨
4. 업로드 완료 후 `IO0 → GND` 연결 해제
5. **RST 버튼** 다시 눌러 일반 실행 모드로 재시작

---

## Usage

업로드 완료 후 `Tools → Serial Monitor`를 열고 baud rate를 **115200**으로 설정하면 IP 주소가 출력됩니다.

```
WiFi connected
Camera Ready! Use 'http://192.168.x.x' to connect
```

브라우저에서 해당 주소에 접속하면 스트리밍 UI를 사용할 수 있습니다.

---

## Customizing Web UI

웹 UI HTML은 `index/` 폴더에서 관리합니다.

```sh
# 1. camera_index.h에서 HTML 추출
./Scripts/extract_html.sh

# 2. HTML 또는 공통 CSS 편집
vi index/ov2640.html
vi index/common/style.css   # 세 센서 공통 적용

# 3. 편집 완료 후 camera_index.h 재생성
./Scripts/pack_html.sh
```

`index/ov*.html` 내에서 `<!-- @include common/style.css -->` 마커를 사용하면  
`pack_html.sh`가 공통 파일을 자동으로 합쳐서 압축합니다.

---

## CI / GitHub Actions

### Build

`CameraWebServer/ci.yml`의 FQBN 목록으로 멀티 보드 빌드를 자동 실행합니다.

```
push / PR → CameraWebServer/** 변경 감지
  └─ generate-matrix : ci.yml 파싱 → 7개 빌드 타겟 생성
  └─ build (7개 병렬)
       ├─ esp32:esp32:esp32   (PSRAM on / off)
       ├─ esp32:esp32:esp32s2 (PSRAM on / off)
       └─ esp32:esp32:esp32s3 (OPI / enabled / disabled)
```

빌드 타겟 추가는 `CameraWebServer/ci.yml`의 `fqbn` 항목에 FQBN을 추가하면 됩니다.

### Deploy

`CameraWebServer/**`, `index/**`, `Scripts/**` 변경 시 `arduino-ide` 브랜치를 자동으로 업데이트합니다.

```
push → main
  └─ pack_html.sh 실행 (index/ → camera_index.h 빌드)
  └─ arduino-ide 브랜치에 CameraWebServer/ 배포
```

---

## Credential Management

| 파일 | git 추적 | 용도 |
|---|:---:|---|
| `CameraWebServer/secrets.h` | 최초 1회 | 실제 Wi-Fi 인증정보 및 카메라 계정 |
| `CameraWebServer/secrets.h.example` | 항상 | 팀원용 템플릿 |

`secrets.h`에서 Wi-Fi와 카메라 접속 계정을 함께 관리합니다.

```cpp
#define WIFI_SSID        "your_ssid_here"
#define WIFI_PASSWORD    "your_password_here"
#define CAMERA_AUTH_USER "admin"           // 카메라 웹 UI 로그인 ID
#define CAMERA_AUTH_PASS "changeme"        // 카메라 웹 UI 로그인 PW (강력한 값으로 변경)
```

초기 커밋 이후 로컬 변경사항이 추적되지 않으려면 아래 명령어를 실행하세요.

```sh
git update-index --skip-worktree CameraWebServer/secrets.h
```

---

## Security

카메라 웹 서버는 HTTP Basic Authentication으로 보호됩니다.

- 브라우저에서 IP 주소 접속 시 ID/PW 입력 팝업이 표시됩니다.
- 이후 API 호출(`/control`, `/capture`, `/status` 등)에는 자격증명이 자동으로 포함됩니다.
- 실시간 스트림(`/stream`, 포트 81)은 브라우저 `<img>` 태그 제한으로 별도 팝업이 뜰 수 있습니다.

> **주의**: `CAMERA_AUTH_PASS`의 기본값 `changeme`은 반드시 변경하세요.

---

## REST API

모든 요청에는 HTTP Basic Auth 헤더가 필요합니다.

| 메서드 | 경로 | 설명 | 응답 |
|---|---|---|---|
| GET | `/status` | 카메라 전체 상태 조회 | JSON |
| GET | `/control?var=X&val=Y` | 카메라 설정 변경 | JSON |
| GET | `/capture` | JPEG 스냅샷 캡처 | image/jpeg |
| GET | `/stream` | MJPEG 실시간 스트림 (포트 81) | multipart |

**`/control` 변수 목록**

| var | 설명 | 범위 |
|---|---|---|
| `framesize` | 해상도 | 0–13 |
| `quality` | JPEG 품질 | 4–63 (낮을수록 고품질) |
| `brightness` | 밝기 | -2 ~ 2 |
| `contrast` | 대비 | -2 ~ 2 |
| `saturation` | 채도 | -2 ~ 2 |
| `hmirror` | 수평 반전 | 0 / 1 |
| `vflip` | 수직 반전 | 0 / 1 |
| `awb` | 자동 화이트밸런스 | 0 / 1 |
| `agc` | 자동 게인 | 0 / 1 |
| `aec` | 자동 노출 | 0 / 1 |

**예시**

```sh
# 밝기 +1 설정
curl -u admin:changeme "http://192.168.x.x/control?var=brightness&val=1"
# → {"result":"ok"}

# 스냅샷 저장
curl -u admin:changeme "http://192.168.x.x/capture" -o capture.jpg
```

---

## MQTT

### 라이브러리 설치

Arduino IDE → `Tools → Manage Libraries` → **PubSubClient** by Nick O'Leary 설치

### 설정

`secrets.h`에서 브로커 정보를 입력합니다.

```cpp
#define MQTT_BROKER    "192.168.1.x"
#define MQTT_PORT      1883
#define MQTT_USER      ""
#define MQTT_PASS      ""
#define MQTT_CLIENT_ID "esp32cam-1"
```

### 토픽 구조

| 방향 | 토픽 | 페이로드 | 설명 |
|---|---|---|---|
| Subscribe | `cam/{CLIENT_ID}/cmd` | JSON | 카메라 설정 명령 수신 |
| Publish | `cam/{CLIENT_ID}/status` | JSON | 카메라 상태 (retained) |
| Publish LWT | `cam/{CLIENT_ID}/online` | `1` / `0` | 연결 상태 (retained) |

### 명령 페이로드 형식

```json
{"var": "brightness", "val": 1}
```

명령 수신 후 자동으로 `status` 토픽에 최신 상태가 발행됩니다.

### 상태 페이로드 예시

```json
{
  "ip": "192.168.1.42",
  "framesize": 5,
  "quality": 10,
  "brightness": 0,
  "contrast": 0,
  "saturation": 0
}
```

### mosquitto 테스트 예시

```sh
# 명령 전송 (밝기 +2)
mosquitto_pub -h 192.168.1.x -t "cam/esp32cam-1/cmd" \
  -m '{"var":"brightness","val":2}'

# 상태 구독
mosquitto_sub -h 192.168.1.x -t "cam/esp32cam-1/status"
```

---

## License

MIT
