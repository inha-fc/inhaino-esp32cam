#include <Arduino.h>
#include "esp_camera.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ESPmDNS.h>

// ===========================
// Select camera model in board_config.h
// ===========================
#include "board_config.h"

#include "secrets.h"
#include "camera_control.h"

const char *ssid = WIFI_SSID;
const char *password = WIFI_PASSWORD;

void startCameraServer();
void setupLedFlash();

// ===========================
// MQTT
// ===========================
#define MQTT_TOPIC_CMD    "cam/" MQTT_CLIENT_ID "/cmd"
#define MQTT_TOPIC_STATUS "cam/" MQTT_CLIENT_ID "/status"
#define MQTT_TOPIC_ONLINE "cam/" MQTT_CLIENT_ID "/online"

#if MQTT_TLS
static WiFiClientSecure mqttNet;
#else
static WiFiClient       mqttNet;
#endif
static PubSubClient mqtt(mqttNet);

static void mqtt_publish_status() {
  sensor_t *s = esp_camera_sensor_get();
  if (!s) return;
  char buf[256];
  snprintf(buf, sizeof(buf),
    "{\"ip\":\"%s\",\"framesize\":%u,\"quality\":%u,"
    "\"brightness\":%d,\"contrast\":%d,\"saturation\":%d}",
    WiFi.localIP().toString().c_str(),
    (unsigned)s->status.framesize,
    (unsigned)s->status.quality,
    s->status.brightness,
    s->status.contrast,
    s->status.saturation
  );
  mqtt.publish(MQTT_TOPIC_STATUS, buf, true);
}

static void mqtt_callback(char *topic, byte *payload, unsigned int len) {
  if (len == 0 || len >= 128) return;
  char buf[128];
  memcpy(buf, payload, len);
  buf[len] = '\0';

  // Payload format: {"var":"brightness","val":2}
  char var[32] = {0};
  int  val = 0;
  if (sscanf(buf, "{\"var\":\"%31[^\"]\",\"val\":%d}", var, &val) == 2) {
    camera_apply_control(var, val);
    mqtt_publish_status();
  }
}

static void mqtt_connect() {
  while (!mqtt.connected()) {
    Serial.print("MQTT connecting...");
    bool ok = strlen(MQTT_USER) > 0
      ? mqtt.connect(MQTT_CLIENT_ID, MQTT_USER, MQTT_PASS,
                     MQTT_TOPIC_ONLINE, 0, true, "0")
      : mqtt.connect(MQTT_CLIENT_ID,
                     MQTT_TOPIC_ONLINE, 0, true, "0");
    if (ok) {
      Serial.println(" connected");
      mqtt.publish(MQTT_TOPIC_ONLINE, "1", true);
      mqtt.subscribe(MQTT_TOPIC_CMD);
      mqtt_publish_status();
    } else {
      Serial.printf(" failed (rc=%d), retry in 5s\n", mqtt.state());
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println();

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 10000000;
  config.frame_size = FRAMESIZE_UXGA;
  config.pixel_format = PIXFORMAT_JPEG;  // for streaming
  //config.pixel_format = PIXFORMAT_RGB565; // for face detection/recognition
  config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  config.jpeg_quality = 12;
  config.fb_count = 1;

  // if PSRAM IC present, init with UXGA resolution and higher JPEG quality
  //                      for larger pre-allocated frame buffer.
  if (config.pixel_format == PIXFORMAT_JPEG) {
    if (psramFound()) {
      config.jpeg_quality = 10;
      config.fb_count = 2;
      config.grab_mode = CAMERA_GRAB_LATEST;
    } else {
      // Limit the frame size when PSRAM is not available
      config.frame_size = FRAMESIZE_SVGA;
      config.fb_location = CAMERA_FB_IN_DRAM;
    }
  } else {
    // Best option for face detection/recognition
    config.frame_size = FRAMESIZE_240X240;
#if CONFIG_IDF_TARGET_ESP32S3
    config.fb_count = 2;
#endif
  }

#if defined(CAMERA_MODEL_ESP_EYE)
  pinMode(13, INPUT_PULLUP);
  pinMode(14, INPUT_PULLUP);
#endif

  // camera init
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }

  sensor_t *s = esp_camera_sensor_get();
  // initial sensors are flipped vertically and colors are a bit saturated
  if (s->id.PID == OV3660_PID) {
    s->set_vflip(s, 1);        // flip it back
    s->set_brightness(s, 1);   // up the brightness just a bit
    s->set_saturation(s, -2);  // lower the saturation
  }
  // drop down frame size for higher initial frame rate
  if (config.pixel_format == PIXFORMAT_JPEG) {
    s->set_framesize(s, FRAMESIZE_QVGA);
  }

#if defined(CAMERA_MODEL_M5STACK_WIDE) || defined(CAMERA_MODEL_M5STACK_ESP32CAM)
  s->set_vflip(s, 1);
  s->set_hmirror(s, 1);
#endif

#if defined(CAMERA_MODEL_ESP32S3_EYE)
  s->set_vflip(s, 1);
#endif

// Setup LED FLash if LED pin is defined in camera_pins.h
#if defined(LED_GPIO_NUM)
  setupLedFlash();
#endif

  WiFi.begin(ssid, password);
  WiFi.setSleep(false);

  Serial.print("WiFi connecting");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("WiFi connected");

  startCameraServer();

  Serial.print("Camera Ready! Use 'https://");
  Serial.print(WiFi.localIP());
  Serial.println("' to connect (accept self-signed cert warning)");

  if (MDNS.begin(MQTT_CLIENT_ID)) {
    MDNS.addService("https", "tcp", 443);
    Serial.printf("mDNS: https://%s.local/\n", MQTT_CLIENT_ID);
  }

#if MQTT_TLS
  mqttNet.setInsecure();  // encrypts without CA verification
  mqtt.setServer(MQTT_BROKER, 8883);
#else
  mqtt.setServer(MQTT_BROKER, MQTT_PORT);
#endif
  mqtt.setCallback(mqtt_callback);
  mqtt_connect();
}

void loop() {
  if (!mqtt.connected()) {
    mqtt_connect();
  }
  mqtt.loop();
  delay(10);
}
