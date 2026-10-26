
















#include <WiFi.h>
#include <HTTPClient.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <time.h>
#include "mbedtls/md.h"




const char* WIFI_SSID     = "NAMA_WIFI_ANDA";
const char* WIFI_PASSWORD = "PASSWORD_WIFI";




const char* SERVER_ENDPOINT = "http://192.168.1.100:3000/api/iot/events";


const char* DEVICE_ID   = "c0000001-0000-0000-0000-000000000001";
const char* DEVICE_KEY  = "demo_device_key_001";
const char* HMAC_SECRET = "asuhkita_iot_device_hmac_secret_2026";


const char* NTP_SERVER = "pool.ntp.org";
const long  GMT_OFFSET_SEC = 7 * 3600;
const int   DAYLIGHT_OFFSET_SEC = 0;




#define PIN_IR_SENSOR    34
#define PIN_BTN_10K      18
#define PIN_BTN_20K      19
#define PIN_BTN_50K      23
#define PIN_BUZZER       4
#define PIN_STATUS_LED   2


#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1
#define SCREEN_ADDRESS 0x3C
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);


long selectedAmount = 20000;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 250;




void updateDisplay(const char* statusTitle, const char* statusMsg, long amount) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  

  display.setTextSize(1);
  display.setCursor(18, 0);
  display.println(F("ASUHKITA SMART IOT"));
  display.drawLine(0, 10, 127, 10, SSD1306_WHITE);


  display.setCursor(0, 16);
  display.print(F("Status: "));
  display.println(statusTitle);


  display.setCursor(0, 30);
  display.print(F("Nominal: Rp "));
  display.setTextSize(1);
  display.println(amount);


  display.setCursor(0, 48);
  display.setTextSize(1);
  display.println(statusMsg);

  display.display();
}

void beepBuzzer(int count, int durationMs) {
  for (int i = 0; i < count; i++) {
    digitalWrite(PIN_BUZZER, HIGH);
    delay(durationMs);
    digitalWrite(PIN_BUZZER, LOW);
    if (i < count - 1) delay(100);
  }
}




String getIsoTimestamp() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("[NTP] Gagal sinkronisasi waktu, memakai waktu fallback.");
    return "2026-10-21T12:00:00Z";
  }
  char timeStringBuff[30];
  strftime(timeStringBuff, sizeof(timeStringBuff), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(timeStringBuff);
}


String calculateHmacSha256(String payload, const char* key) {
  byte hmacResult[32];
  mbedtls_md_context_t ctx;
  mbedtls_md_type_t md_type = MBEDTLS_MD_SHA256;

  mbedtls_md_init(&ctx);
  mbedtls_md_setup(&ctx, mbedtls_md_info_from_type(md_type), 1);
  mbedtls_md_hmac_starts(&ctx, (const unsigned char*)key, strlen(key));
  mbedtls_md_hmac_update(&ctx, (const unsigned char*)payload.c_str(), payload.length());
  mbedtls_md_hmac_finish(&ctx, hmacResult);
  mbedtls_md_free(&ctx);


  String hmacHex = "";
  for (int i = 0; i < 32; i++) {
    char hexBuffer[3];
    sprintf(hexBuffer, "%02x", hmacResult[i]);
    hmacHex += hexBuffer;
  }
  return hmacHex;
}




bool sendDonationEvent(long amount) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Terputus! Mencoba menghubungkan ulang...");
    WiFi.reconnect();
    return false;
  }

  digitalWrite(PIN_STATUS_LED, HIGH);
  updateDisplay("MENGIRIM...", "Enkripsi HMAC & Ledger", amount);

  String timestamp = getIsoTimestamp();


  String canonicalPayload = String(DEVICE_ID) + "|" + String(amount) + "|" + timestamp;
  String hmacSignature = calculateHmacSha256(canonicalPayload, HMAC_SECRET);

  Serial.println(F("--- Pengiriman Transaksi IoT ---"));
  Serial.print(F("Canonical: ")); Serial.println(canonicalPayload);
  Serial.print(F("HMAC     : ")); Serial.println(hmacSignature);


  String jsonBody = "{";
  jsonBody += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  jsonBody += "\"device_key\":\"" + String(DEVICE_KEY) + "\",";
  jsonBody += "\"amount_sim\":" + String(amount) + ",";
  jsonBody += "\"timestamp\":\"" + timestamp + "\",";
  jsonBody += "\"hmac_signature\":\"" + hmacSignature + "\"";
  jsonBody += "}";

  HTTPClient http;
  http.begin(SERVER_ENDPOINT);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(10000);

  int httpCode = http.POST(jsonBody);
  bool success = false;

  if (httpCode > 0) {
    String response = http.getString();
    Serial.printf("[HTTP] Status: %d\n", httpCode);
    Serial.print("[HTTP] Response: "); Serial.println(response);

    if (httpCode == 201 || httpCode == 200) {
      Serial.println(F(">> SUKSES! Tercatat di Blockchain Ledger! <<"));
      updateDisplay("BERHASIL! :)", "Tercatat di Blockchain", amount);
      beepBuzzer(2, 100);
      success = true;
    } else {
      Serial.printf(">> GAGAL! Kode: %d <<\n", httpCode);
      updateDisplay("DITOLAK!", "Validasi Backend Gagal", amount);
      beepBuzzer(3, 300);
    }
  } else {
    Serial.printf("[HTTP] Error koneksi: %s\n", http.errorToString(httpCode).c_str());
    updateDisplay("OFFLINE!", "Server Tidak Terjangkau", amount);
    beepBuzzer(1, 600);
  }

  http.end();
  digitalWrite(PIN_STATUS_LED, LOW);
  delay(2500);
  return success;
}




void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println(F("\n=========================================="));
  Serial.println(F("   ASUHKITA - ESP32 SMART DONATION BOX    "));
  Serial.println(F("=========================================="));


  pinMode(PIN_IR_SENSOR, INPUT);
  pinMode(PIN_BTN_10K, INPUT_PULLUP);
  pinMode(PIN_BTN_20K, INPUT_PULLUP);
  pinMode(PIN_BTN_50K, INPUT_PULLUP);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_STATUS_LED, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);
  digitalWrite(PIN_STATUS_LED, LOW);


  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("[OLED] SSD1306 alokasi gagal! Periksa I2C SDA/SCL."));
  } else {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(10, 20);
    display.println(F("AsuhKita SmartBox"));
    display.setCursor(10, 36);
    display.println(F("Menghubungkan WiFi..."));
    display.display();
  }


  Serial.printf("[WiFi] Menghubungkan ke %s...\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int retryCount = 0;
  while (WiFi.status() != WL_CONNECTED && retryCount < 20) {
    delay(500);
    Serial.print(".");
    digitalWrite(PIN_STATUS_LED, !digitalRead(PIN_STATUS_LED));
    retryCount++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println(F("\n[WiFi] Terhubung!"));
    Serial.print(F("[WiFi] IP Address: ")); Serial.println(WiFi.localIP());

    configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, NTP_SERVER);
    updateDisplay("STANDBY (ONLINE)", "Siap Menerima Donasi", selectedAmount);
    beepBuzzer(1, 150);
  } else {
    Serial.println(F("\n[WiFi] Gagal terhubung! Berjalan dalam mode mandiri."));
    updateDisplay("STANDBY (NO WIFI)", "Periksa Konfigurasi", selectedAmount);
  }
}




void loop() {
  unsigned long currentMillis = millis();


  if (digitalRead(PIN_BTN_10K) == LOW && (currentMillis - lastDebounceTime > debounceDelay)) {
    selectedAmount = 10000;
    lastDebounceTime = currentMillis;
    beepBuzzer(1, 50);
    Serial.println(F("[BTN] Nominal diset: Rp 10.000"));
    updateDisplay("NOMINAL DIUBAH", "Siap Masukkan Uang", selectedAmount);
  } else if (digitalRead(PIN_BTN_20K) == LOW && (currentMillis - lastDebounceTime > debounceDelay)) {
    selectedAmount = 20000;
    lastDebounceTime = currentMillis;
    beepBuzzer(1, 50);
    Serial.println(F("[BTN] Nominal diset: Rp 20.000"));
    updateDisplay("NOMINAL DIUBAH", "Siap Masukkan Uang", selectedAmount);
  } else if (digitalRead(PIN_BTN_50K) == LOW && (currentMillis - lastDebounceTime > debounceDelay)) {
    selectedAmount = 50000;
    lastDebounceTime = currentMillis;
    beepBuzzer(1, 50);
    Serial.println(F("[BTN] Nominal diset: Rp 50.000"));
    updateDisplay("NOMINAL DIUBAH", "Siap Masukkan Uang", selectedAmount);
  }



  int irState = digitalRead(PIN_IR_SENSOR);
  if (irState == LOW && (currentMillis - lastDebounceTime > 1500)) {
    lastDebounceTime = currentMillis;
    Serial.println(F("[SENSOR IR] Terdeteksi Uang Masuk ke Slot!"));
    beepBuzzer(1, 200);


    sendDonationEvent(selectedAmount);


    updateDisplay("STANDBY (ONLINE)", "Siap Menerima Donasi", selectedAmount);
  }

  delay(50);
}
