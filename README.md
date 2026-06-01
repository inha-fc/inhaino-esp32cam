# InhaIno — ESP32-CAM 펌웨어

> 인하대학교 소프트웨어융합공학과 IoT프로그래밍 팀 프로젝트  
> 팀명: InhaIno | 이종영(12233771) · 이상호(12223429)

[![Build](https://github.com/inha-fc/inhaino-esp32cam/actions/workflows/build.yml/badge.svg)](https://github.com/inha-fc/inhaino-esp32cam/actions/workflows/build.yml)
[![Arduino IDE](https://img.shields.io/badge/branch-arduino--ide-blue?logo=arduino)](https://github.com/inha-fc/inhaino-esp32cam/tree/arduino-ide)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

지하철 부정승차 방지 IoT 인증 시스템의 **촬영·스트리밍** 펌웨어입니다.  
Arduino R4 WiFi의 촬영 트리거 요청에 응답하고, 등록 모드에서는 서버 명령으로 자동 촬영하여 이미지를 전송합니다.

---

## 인하이노 연동

### 촬영 파이프라인 (검증 모드)

```
[Arduino R4 WiFi]
    └─ HTTP GET :81/inhaino/capture ──→ [ESP32-CAM]
                                             └─ {"img_url":"http://<cam_ip>:81/inhaino/jpeg"}

[Flask 서버]
    └─ HTTP GET :81/inhaino/jpeg ──→ [ESP32-CAM]
                                         └─ binary JPEG → 얼굴 대조
```

### 촬영 파이프라인 (등록 모드)

```
[Mosquitto 브로커]
    └─ MQTT gate/esp32cam-1/capture → [ESP32-CAM]
                                          └─ 촬영 후 POST /register/stage-image → [Flask 서버]
```

### InhaIno 전용 엔드포인트 (포트 81, HTTP, 인증 불필요)

| 메서드 | 경로 | 설명 | 응답 |
|---|---|---|---|
| GET | `/inhaino/capture` | 촬영 트리거 + img_url 반환 | `{"img_url":"http://<ip>:81/inhaino/jpeg"}` |
| GET | `/inhaino/jpeg` | 최신 프레임 스냅샷 | `image/jpeg` |

> Arduino R4 WiFi는 SSL을 지원하지 않으므로 InhaIno 전용 엔드포인트는 HTTP 포트(81)에 위치합니다.

### InhaIno MQTT 토픽

| 방향 | 토픽 | 페이로드 | 설명 |
|---|---|---|---|
| Subscribe | `gate/{CLIENT_ID}/capture` | `AABBCCDD` (card_id) | 서버 → CAM 촬영 명령 |
| Publish | `cam/{CLIENT_ID}/status` | JSON | 카메라 상태 (retained) |
| Publish LWT | `cam/{CLIENT_ID}/online` | `1` / `0` | 연결 상태 (retained) |
| Subscribe | `cam/{CLIENT_ID}/cmd` | JSON | 카메라 설정 명령 (기존) |

### Heartbeat

30초마다 Flask 서버에 장치 생존 신호를 전송합니다.

```
POST /heartbeat  {"device_id":"esp32cam-1"}
```

---

## 브랜치 구조

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

## 주요 기능

- 실시간 MJPEG 스트리밍
- 브라우저 기반 카메라 컨트롤 UI (해상도, 밝기, 채도, 화이트밸런스 등)
- 센서 자동 감지 및 전용 UI 제공 (OV2640 / OV3660 / OV5640)
- PSRAM 유무에 따른 자동 화질 조절
- LED 플래시 지원 (핀 정의 시 자동 활성화)
- HTTP Basic Auth 기반 인증 (웹 UI · REST API 보호)
- HTTPS (포트 443) + HTTP 스트리밍 (포트 81) + mDNS (`esp32cam-1.local`)
- REST API (JSON 응답) + MQTT / MQTTS 통신 지원
- OTA 펌웨어 업데이트 (브라우저에서 `.bin` 업로드)
- 인하이노 연동: `/inhaino/capture` · `/inhaino/jpeg` 엔드포인트, 서버 heartbeat
- GitHub Actions 멀티 보드 빌드 검증 (ESP32 / S2 / S3, PSRAM on/off)

---

## 지원 보드

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

## 펌웨어 구조

```
inhaino-esp32cam/
├── .github/
│   └── workflows/
│       ├── build.yml                # 멀티 보드 빌드 검증
│       └── deploy-arduino-ide.yml   # arduino-ide 브랜치 자동 배포
├── CameraWebServer/                  # Arduino 스케치 폴더
│   ├── CameraWebServer.ino           # 메인 스케치 (MQTT, heartbeat, InhaIno 연동)
│   ├── app_httpd.cpp                 # HTTP 핸들러 (capture, stream, /inhaino/*)
│   ├── board_config.h                # 카메라 모델 선택
│   ├── camera_index.h                # 웹 UI (gzip 인코딩된 HTML)
│   ├── camera_pins.h                 # 보드별 GPIO 핀 정의
│   ├── ci.yml                        # 빌드 매트릭스 정의 (FQBN 목록)
│   ├── partitions.csv                # 커스텀 파티션 테이블
│   ├── secrets.h                     # Wi-Fi · MQTT · 서버 설정 (변경사항 추적 제외)
│   └── secrets.h.example             # 설정 템플릿
├── Scripts/
│   ├── extract_html.sh               # camera_index.h → index/*.html 추출
│   └── pack_html.sh                  # index/*.html → camera_index.h 재생성
├── index/
│   ├── common/
│   │   └── style.css                 # 센서 공통 CSS
│   ├── ov2640.html                   # OV2640 웹 UI 소스
│   ├── ov3660.html                   # OV3660 웹 UI 소스
│   └── ov5640.html                   # OV5640 웹 UI 소스
└── README.md
```

---

## 개발 환경 설정

### 1. 저장소 클론

```sh
git clone https://github.com/inha-fc/inhaino-esp32cam.git
cd inhaino-esp32cam
```

### 2. 설정 파일 편집

`CameraWebServer/secrets.h`를 편집합니다.

```cpp
#define WIFI_SSID           "your_ssid_here"
#define WIFI_PASSWORD       "your_password_here"
#define CAMERA_AUTH_USER    "admin"
#define CAMERA_AUTH_PASS    "changeme"       // 반드시 변경

#define MQTT_BROKER         "192.168.1.x"
#define MQTT_PORT           1883
#define MQTT_CLIENT_ID      "esp32cam-1"    // devices.json 등록 ID와 일치해야 함

#define INHAINO_SERVER_IP   "192.168.1.100" // Flask 서버 IP
#define INHAINO_SERVER_PORT 58080
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

#### 보드 패키지 설치 (최초 1회)

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

## 초기 접속

업로드 완료 후 `Tools → Serial Monitor`를 열고 baud rate를 **115200**으로 설정하면 IP 주소가 출력됩니다.

```
WiFi connected
Camera Ready! Use 'http://192.168.x.x' to connect
```

브라우저에서 해당 주소에 접속하면 스트리밍 UI를 사용할 수 있습니다.

---

## 웹 UI 커스터마이징

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

## REST API

### 웹 UI · 관리 엔드포인트 (포트 443, HTTPS, Basic Auth 필요)

| 메서드 | 경로 | 설명 | 응답 |
|---|---|---|---|
| GET | `/status` | 카메라 전체 상태 조회 | JSON |
| GET | `/control?var=X&val=Y` | 카메라 설정 변경 | JSON |
| GET | `/capture` | JPEG 스냅샷 | `image/jpeg` |
| GET | `/stream` | MJPEG 실시간 스트림 (포트 81) | multipart |
| GET | `/info` | 시스템 정보 (IP, RSSI, 힙, 가동시간) | JSON |
| GET/POST | `/update` | OTA 업데이트 페이지 / 펌웨어 업로드 | — |
| POST | `/cert` | TLS 인증서 PEM 업로드 | — |
| POST | `/cert/key` | TLS 개인키 PEM 업로드 | — |
| POST | `/restart` | 소프트웨어 재시작 | — |

### InhaIno 전용 엔드포인트 (포트 81, HTTP, 인증 불필요)

| 메서드 | 경로 | 설명 | 응답 |
|---|---|---|---|
| GET | `/inhaino/capture` | 촬영 트리거 + img_url 반환 | `{"img_url":"http://<ip>:81/inhaino/jpeg"}` |
| GET | `/inhaino/jpeg` | 최신 프레임 스냅샷 | `image/jpeg` |

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
curl -u admin:changeme "https://192.168.x.x/control?var=brightness&val=1"

# InhaIno 촬영 트리거 (인증 불필요)
curl "http://192.168.x.x:81/inhaino/capture"
# → {"img_url":"http://192.168.x.x:81/inhaino/jpeg"}
```

---

## MQTT

### 라이브러리 설치

Arduino IDE → `Tools → Manage Libraries` → **PubSubClient** by Nick O'Leary 설치

### 토픽 전체 명세

| 방향 | 토픽 | 페이로드 | 설명 |
|---|---|---|---|
| Subscribe | `cam/{CLIENT_ID}/cmd` | `{"var":"X","val":Y}` | 카메라 설정 명령 |
| Subscribe | `gate/{CLIENT_ID}/capture` | `AABBCCDD` (card_id) | 인하이노 촬영 명령 |
| Publish | `cam/{CLIENT_ID}/status` | JSON | 카메라 상태 (retained) |
| Publish LWT | `cam/{CLIENT_ID}/online` | `1` / `0` | 연결 상태 (retained) |

`gate/{CLIENT_ID}/capture` 수신 시: 촬영 후 Flask 서버 `/register/stage-image`에 multipart POST

### 설정 (`secrets.h`)

```cpp
#define MQTT_BROKER    "192.168.1.x"
#define MQTT_PORT      1883
#define MQTT_USER      ""
#define MQTT_PASS      ""
#define MQTT_CLIENT_ID "esp32cam-1"
```

### mosquitto 테스트 예시

```sh
# 촬영 명령 전송 (등록 모드)
mosquitto_pub -h 192.168.1.x -t "gate/esp32cam-1/capture" -m "AABBCCDD"

# 상태 구독
mosquitto_sub -h 192.168.1.x -t "cam/esp32cam-1/status"
```

### MQTT over TLS (MQTTS)

`secrets.h`에서 `MQTT_TLS 1`로 변경하면 포트 8883으로 암호화 연결합니다.  
브로커 인증서 검증은 생략하고 암호화만 적용합니다 (사설 브로커 대상).

---

## CI / GitHub Actions

### 빌드 검증

`CameraWebServer/ci.yml`의 FQBN 목록으로 멀티 보드 빌드를 자동 실행합니다.

```
push / PR → CameraWebServer/** 변경 감지
  └─ generate-matrix : ci.yml 파싱 → 빌드 타겟 생성
  └─ build (병렬)
       ├─ esp32:esp32:esp32   (PSRAM on / off)
       ├─ esp32:esp32:esp32s2 (PSRAM on / off)
       └─ esp32:esp32:esp32s3 (OPI / enabled / disabled)
```

### 자동 배포

`CameraWebServer/**`, `index/**`, `Scripts/**` 변경 시 `arduino-ide` 브랜치를 자동으로 업데이트합니다.

```
push → main
  └─ pack_html.sh 실행 (index/ → camera_index.h 빌드)
  └─ arduino-ide 브랜치에 CameraWebServer/ 배포
```

---

## HTTPS 설정

### 인증서 생성 (최초 1회)

```sh
./Scripts/gen_cert.sh
```

openssl로 자체 서명 인증서를 생성하여 `CameraWebServer/default_cert.h`에 저장합니다.  
이 파일은 `.gitignore`에 포함되어 있으므로 클론 후 반드시 실행하세요.

> CI(GitHub Actions)는 빌드 전 자동으로 실행합니다.

### 포트 구성

| 포트 | 프로토콜 | 용도 |
|---|---|---|
| 443 | HTTPS | 웹 UI, REST API, 인증서 관리 |
| 81 | HTTP | MJPEG 스트리밍 + InhaIno 엔드포인트 |

### 브라우저 접속

자체 서명 인증서이므로 첫 접속 시 브라우저 경고가 표시됩니다.  
**"고급 → 계속 진행"** 을 선택해 접속합니다.

---

## OTA 펌웨어 업데이트

펌웨어를 USB 연결 없이 Wi-Fi로 업데이트합니다.

```
https://192.168.x.x/update
```

**curl 예시**

```sh
curl -k -u admin:changeme \
  -X POST --data-binary @firmware.bin \
  -H "Content-Type: application/octet-stream" \
  https://192.168.x.x/update
```

> Arduino IDE에서 `.bin` 파일 생성: `Sketch → Export Compiled Binary`

---

## 자격증명 관리

| 파일 | git 추적 | 용도 |
|---|:---:|---|
| `CameraWebServer/secrets.h` | 최초 1회 | 실제 Wi-Fi · MQTT · 서버 설정 |
| `CameraWebServer/secrets.h.example` | 항상 | 팀원용 템플릿 |

초기 커밋 이후 로컬 변경사항이 추적되지 않으려면 아래 명령어를 실행하세요.

```sh
git update-index --skip-worktree CameraWebServer/secrets.h
```

---

## mDNS

Wi-Fi 연결 후 아래 주소로 IP 없이 접속할 수 있습니다.

```
https://esp32cam-1.local/
```

`MQTT_CLIENT_ID`가 mDNS 호스트명으로 사용됩니다. 같은 네트워크의 macOS · Linux · Windows 10 이상에서 동작합니다.

---

## 라이선스

MIT
