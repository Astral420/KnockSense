#include <WiFi.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Firebase_ESP_Client.h>
#include <ESPAsyncWebServer.h>
#include <AsyncTCP.h>
#include <LittleFS.h>
#include <HTTPClient.h>
//#include <ESPmDNS.h>
#include <WebSerial.h>

#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// Include our enhanced header files
#include "LittleFSConfig.h"
#include "WebServerHandler.h" 
#include "WebSocketHandler.h"
#include "NetworkManager.h"
#include "KnockSenseNetworkManager.h"
#include "time.h"

// ---------- RFID / Hardware Configuration ----------
#define NR_OF_READERS 2
#define SS_1  5
#define SS_2  17
#define RST_1 16
#define RST_2 4





byte ssPins[] = {SS_1, SS_2};
byte rstPins[] = {RST_1, RST_2};

int RELAY_PIN;
long DOOR_OPEN_DURATION;

// ---------- Global Instances ----------
MFRC522 mfrc522[NR_OF_READERS];



// Firebase instances  
FirebaseData fbdo;
FirebaseData fbStream; // Stream for door unlock commands
FirebaseAuth auth;
FirebaseConfig firebaseConfig;

unsigned long lastManualUnlockCheck = 0;
const unsigned long MANUAL_UNLOCK_CHECK_INTERVAL = 1000; // Check every second
bool isManualUnlock = false;
String currentManualUnlockTeacherID = "";
unsigned long manualUnlockDuration = 4000;




// System components
AsyncWebServer server(81);
LittleFSConfig fsConfig;
WebServerHandler webHandler(&server, &fsConfig);
WebSocketHandler wsHandler(&fsConfig);
KnockSenseNetworkManager networkMgr(&fsConfig, &wsHandler);

// ---------- System State ----------
unsigned long sendDataPrevMillis = 0;
unsigned long doorUnlockTime = 0;
bool isDoorUnlocked = false;
bool firebaseConnected = false;
bool unlockStreamActive = false;

const unsigned long FIREBASE_RECONNECT_INTERVAL = 60000;
const unsigned long TOKEN_REFRESH_RETRY_INTERVAL = 30000;
unsigned long lastFirebaseReconnectAttempt = 0;
unsigned long lastTokenRefreshAttempt = 0;
firebase_auth_token_status currentTokenStatus = token_status_uninitialized;
bool lastFirebaseReadyState = false;

// Firebase credentials (loaded from config)
String API_KEY;
String DATABASE_URL;
String ADMIN_EMAIL;
String ADMIN_PASSWORD;

// ---------- Function Declarations ----------
void loadConfigurationValues();
void connectFirebase();
void checkRFID();
void manageDoorLock();
void handleNetworkUpdates();
String uidToString(byte *buffer, byte bufferSize);
void addOrUpdateRfidTag(String uid);
void logAccessAttempt(String uid, String result, uint8_t reader);
void updateTeacherStatus(String teacherID, uint8_t reader);
void logAttendance(String teacherID, uint8_t reader);
void doorLogic(String uid, uint8_t reader);
void initReader();
void checkManualDoorUnlock();
void processUnlockStream();
void executeManualUnlock(String teacherID, String teacherName, String teacherUid, int duration);
void logManualUnlockEvent(String teacherID, String teacherName, String teacherUid, int duration);
void maintainFirebaseSession(bool firebaseReady);



// ---------- Setup Function ----------
void setup() {
  Serial.begin(115200);
  WebSerial.begin(&server);
  WebSerial.onMessage([](uint8_t *data, size_t len) {
    Serial.println("⚠️ WebSerial input received, but command handling is not yet implemented.");
    WebSerial.println("⚠️ WebSerial input received, but command handling is not yet implemented.");
  });
  Serial.println();
  WebSerial.println();
  for(int i=0; i<50; i++) { Serial.print("="); }
  for(int i=0; i<50; i++) { WebSerial.print("="); }
  Serial.println();
  WebSerial.println();
  Serial.println("🚪 KnockSense Enhanced Access Control System");
  WebSerial.println("🚪 KnockSense Enhanced Access Control System");
  Serial.println("   Version: 2.0 Enhanced");
  WebSerial.println("   Version: 2.0 Enhanced");
  Serial.println("   Build Date: " + String(__DATE__) + " " + String(__TIME__));
  WebSerial.println("   Build Date: " + String(__DATE__) + " " + String(__TIME__));
  for(int i=0; i<50; i++) { Serial.print("="); }
  for(int i=0; i<50; i++) { WebSerial.print("="); }
  Serial.println();
  WebSerial.println();



  // Initialize LittleFS and load configuration
  Serial.println("\n📁 Initializing File System...");
  WebSerial.println("\n📁 Initializing File System...");
  if (!fsConfig.begin()) {
    Serial.println("❌ Failed to initialize LittleFS config!");
    WebSerial.println("❌ Failed to initialize LittleFS config!");
    Serial.println("🔄 System will restart in 5 seconds...");
    WebSerial.println("🔄 System will restart in 5 seconds...");
    delay(5000);
    ESP.restart();
    return;
  }
  Serial.println("✅ File system initialized successfully");
  WebSerial.println("✅ File system initialized successfully");

  // Load configuration values
  Serial.println("\n⚙️  Loading Configuration...");
  WebSerial.println("\n⚙️  Loading Configuration...");
  loadConfigurationValues();

  // Initialize hardware
  Serial.println("\n🔧 Initializing Hardware...");
  WebSerial.println("\n🔧 Initializing Hardware...");


  SPI.begin();
  initReader();
  
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);
  Serial.println("✅ Hardware initialized - Door locked");
  WebSerial.println("✅ Hardware initialized - Door locked");




  // Initialize network management
  Serial.println("\n🌐 Starting Network Manager...");
  WebSerial.println("\n🌐 Starting Network Manager...");
  networkMgr.begin();

  // Init Setup Time
  configTime(8 * 3600, 0, "pool.ntp.org", "time.google.com"); // UTC+8
  Serial.print("Waiting for time");
  WebSerial.print("Waiting for time");
  time_t now = time(nullptr);
  int tries = 0;
  while (now < 1600000000 && tries++ < 20) { // crude check for valid time
    Serial.print(".");
    WebSerial.print(".");
    delay(1000);
    now = time(nullptr);
  }
  Serial.println();
  WebSerial.println();
  if (now < 1600000000) {
    Serial.println("Time not set!");
    WebSerial.println("Time not set!");
  } else {
    Serial.println("Time set.");
    WebSerial.println("Time set.");
  }


  // Initialize web services
  Serial.println("\n🖥️  Starting Web Services...");
  WebSerial.println("\n🖥️  Starting Web Services...");
  webHandler.begin();
  wsHandler.begin(&server);
  Serial.println("✅ Web services started");
  WebSerial.println("✅ Web services started");

  // Connect to Firebase (only if WiFi connected)
  if (networkMgr.isSTAConnected()) {
    Serial.println("\n🔥 Connecting to Firebase...");
    WebSerial.println("\n🔥 Connecting to Firebase...");
    connectFirebase();
  } else {
    Serial.println("\n⚠️  Firebase connection skipped - no internet access");
    WebSerial.println("\n⚠️  Firebase connection skipped - no internet access");
    Serial.println("   System will work in offline mode");
    WebSerial.println("   System will work in offline mode");
  }

  Serial.println("\n🎉 System Initialization Complete!");
  WebSerial.println("\n🎉 System Initialization Complete!");
  networkMgr.printNetworkInfo();
  
  // Send initial status to any connected WebSocket clients
  wsHandler.sendSystemStatus();
}

// ---------- Main Loop ----------
void loop() {
  bool firebaseReady = Firebase.ready();

  // Core system functions
  checkRFID();
  manageDoorLock();
  processUnlockStream();
  if (!unlockStreamActive) {
    // Fallback polling only when stream inactive
    checkManualDoorUnlock();
  }

  maintainFirebaseSession(firebaseReady);

  // Attempt to re-establish stream periodically when Firebase is ready
  static unsigned long lastStreamRetry = 0;
  if (firebaseReady && !unlockStreamActive && (millis() - lastStreamRetry > 10000)) {
    if (Firebase.RTDB.beginStream(&fbStream, "/door_unlock_commands")) {
      unlockStreamActive = true;
      Serial.println("✅ Stream reconnected to /door_unlock_commands");
      WebSerial.println("✅ Stream reconnected to /door_unlock_commands");
    } else {
      Serial.println("❌ Stream restart failed: " + fbStream.errorReason());
      WebSerial.println("❌ Stream restart failed: " + fbStream.errorReason());
    }
    lastStreamRetry = millis();
  }

 
  

  
  // Network and web service management
  networkMgr.loop();
  wsHandler.loop();
  
  // Handle network configuration updates from web interface
  handleNetworkUpdates();
  
  // Check Firebase connection periodically
  static unsigned long lastFirebaseCheck = 0;
  if (millis() - lastFirebaseCheck > 60000) { // Check every minute
    if (networkMgr.isSTAConnected() && !firebaseConnected) {
      connectFirebase();
    }
    maintainFirebaseSession(firebaseReady);
    lastFirebaseCheck = millis();
  }
  
  // System health monitoring
  static unsigned long lastHealthCheck = 0;
  if (millis() - lastHealthCheck > 300000) { // Every 5 minutes
    Serial.println("\n💓 System Health Check:");
    WebSerial.println("\n💓 System Health Check:");
    Serial.printf("   Free Heap: %d bytes\n", ESP.getFreeHeap());
    WebSerial.printf("   Free Heap: %d bytes\n", ESP.getFreeHeap());
    Serial.printf("   Min Free Heap: %d bytes\n", ESP.getMinFreeHeap());
    WebSerial.printf("   Min Free Heap: %d bytes\n", ESP.getMinFreeHeap());
    Serial.printf("   Uptime: %lu ms\n", millis());
    WebSerial.printf("   Uptime: %lu ms\n", millis());
    Serial.printf("   WiFi RSSI: %d dBm\n", WiFi.RSSI());
    WebSerial.printf("   WiFi RSSI: %d dBm\n", WiFi.RSSI());
    lastHealthCheck = millis();
  }

  static unsigned long lastStatusBroadcast = 0;
  if (millis() - lastStatusBroadcast > 100000) { 
    wsHandler.sendSystemStatus();
    lastStatusBroadcast = millis();
}

WebSerial.loop();
}

// ---------- Configuration Management ----------
void loadConfigurationValues() {
  // Load network credentials
  API_KEY = fsConfig.config.firebase_api_key;
  DATABASE_URL = fsConfig.config.firebase_db_url;
  ADMIN_EMAIL = fsConfig.config.admin_email;
  ADMIN_PASSWORD = fsConfig.config.admin_password;
  
  // Load hardware settings
  RELAY_PIN = fsConfig.config.relay_pin;
  DOOR_OPEN_DURATION = fsConfig.config.door_open_duration;
  
  Serial.println("✅ Configuration loaded:");
  WebSerial.println("✅ Configuration loaded:");
  Serial.println("   Relay Pin: " + String(RELAY_PIN));
  WebSerial.println("   Relay Pin: " + String(RELAY_PIN));
  Serial.println("   Door Duration: " + String(DOOR_OPEN_DURATION) + "ms");
  WebSerial.println("   Door Duration: " + String(DOOR_OPEN_DURATION) + "ms");
  Serial.println("   Firebase DB: " + DATABASE_URL.substring(0, 30) + "...");
  WebSerial.println("   Firebase DB: " + DATABASE_URL.substring(0, 30) + "...");
}



// ---------- Network Update Handler ----------
void handleNetworkUpdates() {
  // Handle WiFi configuration updates from WebSocket
  if (wsHandler.hasNewWifiConfig()) {
    String newSSID, newPassword;
    wsHandler.getNewWifiConfig(newSSID, newPassword);
    
    Serial.println("🔄 WiFi configuration update requested:");
    WebSerial.println("🔄 WiFi configuration update requested:");
    Serial.println("   New SSID: " + newSSID);
    WebSerial.println("   New SSID: " + newSSID);
    
    wsHandler.sendConnectionProgress("updating", "Updating WiFi configuration...");
    
    networkMgr.updateWiFiCredentials(newSSID, newPassword);
    wsHandler.clearWifiConfigUpdate();
  }
  
  // Handle reconnection requests
  if (wsHandler.hasReconnectRequest()) {
    Serial.println("🔄 WiFi reconnection requested via WebSocket");
    WebSerial.println("🔄 WiFi reconnection requested via WebSocket");
    networkMgr.forceReconnect();
    wsHandler.clearReconnectRequest();
  }
}

// ---------- Firebase Connection ----------
void connectFirebase() {
  if (!networkMgr.isSTAConnected()) {
    Serial.println("❌ Cannot connect to Firebase - no internet connection");
    WebSerial.println("❌ Cannot connect to Firebase - no internet connection");
    return;
  }

  Serial.println("🔥 Configuring Firebase...");
  WebSerial.println("🔥 Configuring Firebase...");
  
  firebaseConfig.api_key = API_KEY;
  firebaseConfig.database_url = DATABASE_URL;
  firebaseConfig.token_status_callback = mytokenStatusCallback;
  firebaseConfig.signer.preRefreshSeconds = 5 * 60; // refresh 5 minutes before expiry

  bool usingCachedCredentials = false;
  if (fsConfig.hasFirebaseTokens() && fsConfig.config.firebase_refresh_token.length() > 0) {
    time_t now = time(nullptr);
    unsigned long expiresAt = fsConfig.getFirebaseTokenExpiry();
    unsigned long secondsUntilExpiry = 0;
    if (expiresAt > 0 && now > 0 && expiresAt > static_cast<unsigned long>(now)) {
      secondsUntilExpiry = expiresAt - static_cast<unsigned long>(now);
      if (secondsUntilExpiry > 3600) {
        secondsUntilExpiry = 3600;
      }
    }

    Serial.println("♻️ Using cached Firebase refresh token for authentication");
    WebSerial.println("♻️ Using cached Firebase refresh token for authentication");
    Firebase.setIdToken(&firebaseConfig,
                        fsConfig.config.firebase_id_token.c_str(),
                        secondsUntilExpiry,
                        fsConfig.config.firebase_refresh_token.c_str());
    firebaseConfig.signer.tokens.expires = expiresAt;
    auth.user.email = "";
    auth.user.password = "";
    usingCachedCredentials = true;
  } else {
    auth.user.email = ADMIN_EMAIL;
    auth.user.password = ADMIN_PASSWORD;
  }

  Firebase.reconnectWiFi(true);
  Firebase.begin(&firebaseConfig, &auth);
  currentTokenStatus = token_status_uninitialized;
  lastFirebaseReconnectAttempt = millis();
  lastTokenRefreshAttempt = millis();

  // Test connection
  Serial.println("🔥 Testing Firebase connection...");
  WebSerial.println("🔥 Testing Firebase connection...");
  
  if (Firebase.ready()) {
    firebaseConnected = true;
    Serial.println("✅ Firebase connected and authenticated successfully");
    WebSerial.println("✅ Firebase connected and authenticated successfully");
    wsHandler.sendNetworkEvent("firebase_connected", "Database connection established");
    Serial.println("📡 Starting stream: /door_unlock_commands ...");
    WebSerial.println("📡 Starting stream: /door_unlock_commands ...");
    if (Firebase.RTDB.beginStream(&fbStream, "/door_unlock_commands")) {
      unlockStreamActive = true;
      Serial.println("✅ Stream connected to /door_unlock_commands");
      WebSerial.println("✅ Stream connected to /door_unlock_commands");
    } else {
      unlockStreamActive = false;
      Serial.println("❌ Failed to begin stream: " + fbStream.errorReason());
      WebSerial.println("❌ Failed to begin stream: " + fbStream.errorReason());
    }
  } else {
    firebaseConnected = false;
    if (usingCachedCredentials) {
      Serial.println("⚠️ Cached credentials invalid, clearing stored Firebase tokens");
      WebSerial.println("⚠️ Cached credentials invalid, clearing stored Firebase tokens");
      fsConfig.clearFirebaseTokens();
    }
    Serial.println("❌ Firebase authentication failed: " + fbdo.errorReason());
    WebSerial.println("❌ Firebase authentication failed: " + fbdo.errorReason());
    wsHandler.sendNetworkEvent("firebase_failed", "Database connection failed");
  }
}

void mytokenStatusCallback(TokenInfo info) {
  currentTokenStatus = info.status;

  if (info.status == token_status_ready) {
    Serial.println("✅ Firebase token is ready and valid.");
    WebSerial.println("✅ Firebase token is ready and valid.");

    const char *idTokenCStr = Firebase.getToken();
    const char *refreshTokenCStr = Firebase.getRefreshToken();
    String newIdToken = idTokenCStr ? String(idTokenCStr) : String("");
    String newRefreshToken = refreshTokenCStr ? String(refreshTokenCStr) : String("");
    unsigned long expiresAt = firebaseConfig.signer.tokens.expires;

    bool shouldPersist = newRefreshToken.length() > 0;
    if (shouldPersist) {
      if (fsConfig.config.firebase_refresh_token != newRefreshToken ||
          fsConfig.config.firebase_id_token != newIdToken ||
          fsConfig.config.firebase_token_expires_at != expiresAt) {
        fsConfig.storeFirebaseTokens(newIdToken, newRefreshToken, expiresAt);
        Serial.println("💾 Stored refreshed Firebase credentials to LittleFS");
        WebSerial.println("💾 Stored refreshed Firebase credentials to LittleFS");
      }
    }

    lastTokenRefreshAttempt = millis();
  } else if (info.status == token_status_on_refresh) {
    Serial.println("🔄 Firebase token refresh in progress...");
    WebSerial.println("🔄 Firebase token refresh in progress...");
  } else if (info.status == token_status_error) {
    Serial.printf("Token info: type = %s, status = %s\n", getTokenType(info), getTokenStatus(info));
    WebSerial.printf("Token info: type = %s, status = %s\n", getTokenType(info), getTokenStatus(info));
    Serial.printf("Token error: %s\n", getTokenError(info).c_str());
    WebSerial.printf("Token error: %s\n", getTokenError(info).c_str());
    Serial.println("Error");
    WebSerial.println("Error");

    fsConfig.clearFirebaseTokens();
    firebaseConnected = false;
    unlockStreamActive = false;
    lastTokenRefreshAttempt = millis();
  }
}

void maintainFirebaseSession(bool firebaseReady) {
  unsigned long now = millis();

  if (firebaseReady) {
    if (!lastFirebaseReadyState) {
      Serial.println("✅ Firebase session ready");
      WebSerial.println("✅ Firebase session ready");
    }
    lastFirebaseReadyState = true;
    firebaseConnected = true;
    lastTokenRefreshAttempt = now;
    return;
  }

  if (lastFirebaseReadyState) {
    Serial.println("⚠️ Firebase ready() reported false - monitoring token state");
    WebSerial.println("⚠️ Firebase ready() reported false - monitoring token state");
  }
  lastFirebaseReadyState = false;
  firebaseConnected = false;

  if (!networkMgr.isSTAConnected()) {
    return;
  }

  firebase_auth_token_status status = currentTokenStatus;

  if (status == token_status_on_initialize ||
      status == token_status_on_signing ||
      status == token_status_on_request ||
      status == token_status_on_refresh) {
    return; // Token workflow in progress.
  }

  if (status == token_status_error) {
    if (now - lastFirebaseReconnectAttempt >= FIREBASE_RECONNECT_INTERVAL) {
      Serial.println("🔄 Reconnecting to Firebase after token error...");
      WebSerial.println("🔄 Reconnecting to Firebase after token error...");
      connectFirebase();
    }
    return;
  }

  if (status == token_status_uninitialized) {
    if (now - lastFirebaseReconnectAttempt >= FIREBASE_RECONNECT_INTERVAL) {
      Serial.println("🔄 Firebase session uninitialized - attempting reconnect");
      WebSerial.println("🔄 Firebase session uninitialized - attempting reconnect");
      connectFirebase();
    }
    return;
  }

  if (now - lastTokenRefreshAttempt >= TOKEN_REFRESH_RETRY_INTERVAL) {
    Serial.println("🔄 Requesting Firebase token refresh...");
    WebSerial.println("🔄 Requesting Firebase token refresh...");
    Firebase.refreshToken(&firebaseConfig);
    lastTokenRefreshAttempt = now;
  }
}

// ---------- RFID Management ----------
String uidToString(byte *buffer, byte bufferSize) {
  String localUID = "";
  for (byte i = 0; i < bufferSize; i++) {
    if (buffer[i] < 0x10) localUID += "0";
    localUID += String(buffer[i], HEX);
    if (i < bufferSize - 1) localUID += ":";
  }
  localUID.toUpperCase();
  return localUID;
}

void initReader() {
  Serial.println("🔍 Initializing RFID readers...");
  WebSerial.println("🔍 Initializing RFID readers...");

  for (uint8_t reader = 0; reader < NR_OF_READERS; reader++) {
    mfrc522[reader].PCD_Init(ssPins[reader], rstPins[reader]);
    
    Serial.print("   Reader ");
    WebSerial.print("   Reader ");
    Serial.print(reader);
    WebSerial.print(reader);
    Serial.print(" (");
    WebSerial.print(" (");
    Serial.print(reader == 0 ? "Entry" : "Exit");
    WebSerial.print(reader == 0 ? "Entry" : "Exit");
    Serial.print("): ");
    WebSerial.print("): ");
    
    // Check if reader is connected
    byte version = mfrc522[reader].PCD_ReadRegister(mfrc522[reader].VersionReg);
    if (version == 0x00 || version == 0xFF) {
      Serial.println("❌ Not detected");
      WebSerial.println("❌ Not detected");
    } else {
      Serial.println("✅ Ready (v" + String(version, HEX) + ")");
      WebSerial.println("✅ Ready (v" + String(version, HEX) + ")");
    }
  }
}

void checkRFID() {
  for (uint8_t reader = 0; reader < NR_OF_READERS; reader++) {
    if (mfrc522[reader].PICC_IsNewCardPresent() && mfrc522[reader].PICC_ReadCardSerial()) {
      byte uidSize = mfrc522[reader].uid.size;

      if (uidSize == 4 || uidSize == 7) {
        String uid = uidToString(mfrc522[reader].uid.uidByte, uidSize);
        String readerName = (reader == 0) ? "Entry" : "Exit";
        
        Serial.println("\n🏷️  RFID Detected:");
        WebSerial.println("\n🏷️  RFID Detected:");
        Serial.println("   Reader: " + String(reader) + " (" + readerName + ")");
        WebSerial.println("   Reader: " + String(reader) + " (" + readerName + ")");
        Serial.println("   UID: " + uid);
        WebSerial.println("   UID: " + uid);
        Serial.println("   Size: " + String(uidSize) + " bytes");
        WebSerial.println("   Size: " + String(uidSize) + " bytes");

        // Send to WebSocket clients
        wsHandler.sendRfidScan(uid);
        
        // Handle scan mode vs access mode
        if (wsHandler.isScanMode()) {
          Serial.println("📝 Scan mode active - processing for database...");
          WebSerial.println("📝 Scan mode active - processing for database...");
          addOrUpdateRfidTag(uid);
        } else {
          Serial.println("🔐 Access mode - checking permissions...");
          WebSerial.println("🔐 Access mode - checking permissions...");
          doorLogic(uid, reader);
        }
      } else {
        Serial.println("⚠️  Invalid UID size detected: " + String(uidSize) + " bytes");
        WebSerial.println("⚠️  Invalid UID size detected: " + String(uidSize) + " bytes");
      }

      
      mfrc522[reader].PICC_HaltA();
      mfrc522[reader].PCD_StopCrypto1();
      delay(500); // Prevent multiple reads
    }
  }
}

// ---------- Firebase RFID Management ----------
void addOrUpdateRfidTag(String uid) {
  if (!firebaseConnected) {
    Serial.println("⚠️ Firebase not connected - cannot process RFID tag");
    WebSerial.println("⚠️ Firebase not connected - cannot process RFID tag");
    return;
  }

  String path = "/rfid_tags/" + uid;
  Serial.println("🔍 Checking if RFID tag exists in database: " + path);
  WebSerial.println("🔍 Checking if RFID tag exists in database: " + path);

  // Use get() to check for the node's existence.
  if (Firebase.RTDB.get(&fbdo, path)) {
    // The get() call was successful. If the data type is not 'null', the tag already exists.
    if (fbdo.dataTypeEnum() != fb_esp_rtdb_data_type_null) {
      Serial.println("❌ Duplicate RFID tag detected.");
      WebSerial.println("❌ Duplicate RFID tag detected.");
      wsHandler.sendRfidAddedStatus(uid, false, "duplicate"); // Send duplicate error
      return; // Stop here.
    }
  }

  // If get() failed with "path not exist" or succeeded but the data was "null", we can add the new tag.
  if (fbdo.errorCode() == FIREBASE_ERROR_PATH_NOT_EXIST || fbdo.dataTypeEnum() == fb_esp_rtdb_data_type_null) {
    Serial.println("🆕 New RFID tag detected - adding to database...");
    WebSerial.println("🆕 New RFID tag detected - adding to database...");
    FirebaseJson json;
    json.set("status", "inactive");
    json.set("createdAt/.sv", "timestamp");
    json.set("lastSeen/.sv", "timestamp");
    json.set("addedBy", "system");

    if (Firebase.RTDB.setJSON(&fbdo, path, &json)) {
      Serial.println("✅ RFID tag added to database");
      WebSerial.println("✅ RFID tag added to database");
      wsHandler.sendRfidAddedStatus(uid, true);
    } else {
      Serial.println("❌ Failed to add RFID tag: " + fbdo.errorReason());
      WebSerial.println("❌ Failed to add RFID tag: " + fbdo.errorReason());
      wsHandler.sendRfidAddedStatus(uid, false, "firebase_error");
    }
  } else {
    // Another type of error occurred during the initial get().
    Serial.println("❌ Database error during initial check: " + fbdo.errorReason());
    WebSerial.println("❌ Database error during initial check: " + fbdo.errorReason());
  }
}

void logAccessAttempt(String uid, String result, uint8_t reader) {
  if (!firebaseConnected) {
    Serial.println("⚠️ Firebase not connected - cannot log access attempt");
    WebSerial.println("⚠️ Firebase not connected - cannot log access attempt");
    return;
  }

  String path = "/access_logs";
  String readerRole = (reader == 0) ? "Entry" : "Exit";
  
  FirebaseJson json;
  json.set("uid", uid);
  json.set("result", result);
  json.set("readerRole", readerRole);
  json.set("reader", reader);
  json.set("timestamp/.sv", "timestamp");
  json.set("deviceIP", WiFi.localIP().toString());
  
  if (Firebase.RTDB.pushJSON(&fbdo, path, &json)) {
    Serial.println("📝 Logging access attempt for RFID: " + uid);
    WebSerial.println("📝 Logging access attempt for RFID: " + uid);
  } else {
    Serial.println("❌ Failed to log access attempt: " + fbdo.errorReason());
    WebSerial.println("❌ Failed to log access attempt: " + fbdo.errorReason());
  }
}

// ---------- Door Control ----------

void checkManualDoorUnlock() {
  // Only check if Firebase is connected and enough time has passed
  if (!firebaseConnected || (millis() - lastManualUnlockCheck < MANUAL_UNLOCK_CHECK_INTERVAL)) {
    return;
  }
  
  lastManualUnlockCheck = millis();
  
  String path = "/door_unlock_commands";
  
  // Get all door unlock requests
  if (Firebase.RTDB.get(&fbdo, path)) {
    if (fbdo.dataType() == "json") {
      FirebaseJson &json = fbdo.jsonObject();
      size_t len = json.iteratorBegin();
      String key, value;
      int type = 0;
      
      // Iterate through all teacher unlock commands
      for (size_t i = 0; i < len; i++) {
        json.iteratorGet(i, type, key, value);
        
        // Check if this request has pending status
        FirebaseJsonData statusData;
        if (json.get(statusData, key + "/status") && statusData.stringValue == "pending") {
          
          // Get teacher details
          FirebaseJsonData teacherNameData, teacherUidData, durationData;
          String teacherName = "";
          String teacherUid = "";
          int unlockDuration = 4000; // Default 4 seconds
          
          if (json.get(teacherNameData, key + "/teacherName")) {
            teacherName = teacherNameData.stringValue;
          }
          if (json.get(teacherUidData, key + "/teacherUid")) {
            teacherUid = teacherUidData.stringValue;
          }
          if (json.get(durationData, key + "/unlockDuration")) {
            unlockDuration = durationData.intValue;
          }
          
          Serial.println("\n🚪 MANUAL UNLOCK COMMAND DETECTED");
          WebSerial.println("\n🚪 MANUAL UNLOCK COMMAND DETECTED");
          Serial.println("   Teacher ID: " + key);
          WebSerial.println("   Teacher ID: " + key);
          Serial.println("   Teacher Name: " + teacherName);
          WebSerial.println("   Teacher Name: " + teacherName);
          Serial.println("   Duration: " + String(unlockDuration) + "ms");
          WebSerial.println("   Duration: " + String(unlockDuration) + "ms");
          
          // Execute manual unlock
          executeManualUnlock(key, teacherName, teacherUid, unlockDuration);
          break; // Process one request at a time
        }
      }
      json.iteratorEnd();
    }
  } else {
    // No unlock requests found or error occurred
    if (fbdo.errorCode() != FIREBASE_ERROR_PATH_NOT_EXIST) {
      Serial.println("❌ Error checking manual unlock commands: " + fbdo.errorReason());
      WebSerial.println("❌ Error checking manual unlock commands: " + fbdo.errorReason());
    }
  }
}

// Stream handler for unlock commands
void processUnlockStream() {
  if (!firebaseConnected || !unlockStreamActive) return;
  // Read any available stream updates
  if (!Firebase.RTDB.readStream(&fbStream)) {
    // If stream read fails, mark inactive and retry later
    static unsigned long lastRetry = 0;
    if (millis() - lastRetry > 5000) {
      Serial.println("❌ Firebase stream error: " + fbStream.errorReason());
      WebSerial.println("❌ Firebase stream error: " + fbStream.errorReason());
      unlockStreamActive = false;
      lastRetry = millis();
    }
    return;
  }

  if (!fbStream.streamAvailable()) return;

  String dataPath = fbStream.dataPath(); // e.g., /{teacherID} or /{teacherID}/status
  String eventType = fbStream.eventType();
  (void)eventType; // unused for now

  // Case 1: Full node written (JSON with pending status)
  if (fbStream.dataTypeEnum() == firebase_rtdb_data_type_json) {
    FirebaseJson *json = fbStream.jsonObjectPtr();
    FirebaseJsonData statusData, nameData, uidData, durData;
    if (json->get(statusData, F("/status")) && statusData.stringValue == "pending") {
      String teacherID = dataPath.startsWith("/") ? dataPath.substring(1) : dataPath;
      String teacherName = json->get(nameData, F("/teacherName")) ? nameData.stringValue : String("");
      String teacherUid = json->get(uidData, F("/teacherUid")) ? uidData.stringValue : String("");
      int unlockDuration = json->get(durData, F("/unlockDuration")) ? durData.intValue : 4000;
      Serial.println("🚪 Door unlock command received for teacher ID: " + teacherID);
      WebSerial.println("🚪 Door unlock command received for teacher ID: " + teacherID);
      executeManualUnlock(teacherID, teacherName, teacherUid, unlockDuration);
    }
    return;
  }

  // Case 2: Only status updated to pending
  if (fbStream.dataTypeEnum() == firebase_rtdb_data_type_string) {
    String leaf = dataPath;
    if (leaf.endsWith("/status")) {
      String teacherID = leaf.substring(1, leaf.length() - 7); // trim leading '/' and '/status'
      String status = fbStream.stringData();
      if (status == "pending") {
        // Fetch full command node to get details
        String nodePath = String("/door_unlock_commands/") + teacherID;
        if (Firebase.RTDB.get(&fbdo, nodePath)) {
          if (fbdo.dataType() == "json") {
            FirebaseJson &json = fbdo.jsonObject();
            FirebaseJsonData nameData, uidData, durData;
            String teacherName = json.get(nameData, "/teacherName") ? nameData.stringValue : String("");
            String teacherUid = json.get(uidData, "/teacherUid") ? uidData.stringValue : String("");
            int unlockDuration = json.get(durData, "/unlockDuration") ? durData.intValue : 4000;
            Serial.println("🚪 Door unlock command received for teacher ID: " + teacherID);
            WebSerial.println("🚪 Door unlock command received for teacher ID: " + teacherID);
            executeManualUnlock(teacherID, teacherName, teacherUid, unlockDuration);
          }
        } else {
          Serial.println("❌ Failed to fetch command node: " + fbdo.errorReason());
          WebSerial.println("❌ Failed to fetch command node: " + fbdo.errorReason());
        }
      }
    }
  }
}

void executeManualUnlock(String teacherID, String teacherName, String teacherUid, int duration) {
  // Update status to 'unlocked' in Firebase (commands path)
  String statusPath = "/door_unlock_commands/" + teacherID + "/status";
  String unlockedAtPath = "/door_unlock_commands/" + teacherID + "/unlockedAt";
  
  if (Firebase.RTDB.setString(&fbdo, statusPath, "unlocked") && 
      Firebase.RTDB.setTimestamp(&fbdo, unlockedAtPath)) {
    
    Serial.println("✅ Manual unlock status updated in database");
    WebSerial.println("✅ Manual unlock status updated in database");
    
    // Unlock the door physically
    digitalWrite(RELAY_PIN, HIGH);
    isDoorUnlocked = true;
    isManualUnlock = true;
    doorUnlockTime = millis();
    currentManualUnlockTeacherID = teacherID;
    manualUnlockDuration = duration; // Store the specific duration for this unlock
    
    
    Serial.println("🔓 Door manually unlocked for " + String(duration) + "ms");
    WebSerial.println("🔓 Door manually unlocked for " + String(duration) + "ms");
    Serial.println("   Requested by: " + teacherName + " (" + teacherID + ")");
    WebSerial.println("   Requested by: " + teacherName + " (" + teacherID + ")");
    
    // Log the manual unlock event
    logManualUnlockEvent(teacherID, teacherName, teacherUid, duration);
    
    // Schedule the completion update (will be handled in manageDoorLock)
    // The door will auto-lock after the specified duration
    
  } else {
    Serial.println("❌ Failed to update unlock status: " + fbdo.errorReason());
    WebSerial.println("❌ Failed to update unlock status: " + fbdo.errorReason());
  }
}

void logManualUnlockEvent(String teacherID, String teacherName, String teacherUid, int duration) {
  if (!firebaseConnected) return;
  
  String path = "/access_logs";
  
  FirebaseJson json;
  json.set("uid", "MANUAL_UNLOCK");
  json.set("result", "Manual Unlock Granted");
  json.set("teacherID", teacherID);
  json.set("teacherName", teacherName);
  json.set("teacherUid", teacherUid);
  json.set("unlockDuration", duration);
  json.set("readerRole", "Manual");
  json.set("reader", -1); // Use -1 to indicate manual unlock
  json.set("timestamp/.sv", "timestamp");
  json.set("deviceIP", WiFi.localIP().toString());
  
  if (Firebase.RTDB.pushJSON(&fbdo, path, &json)) {
    Serial.println("✅ Manual unlock event logged to history");
    WebSerial.println("✅ Manual unlock event logged to history");
  } else {
    Serial.println("❌ Failed to log unlock event: " + fbdo.errorReason());
    WebSerial.println("❌ Failed to log unlock event: " + fbdo.errorReason());
  }
}


void manageDoorLock() {
  if (isDoorUnlocked) {
    unsigned long currentDuration;
    
    // Use appropriate duration based on unlock type
    if (isManualUnlock) {
      currentDuration = manualUnlockDuration;
    } else {
      currentDuration = DOOR_OPEN_DURATION;
    }
    
    // Check if duration has elapsed
    if (millis() - doorUnlockTime >= currentDuration) {
      if (isManualUnlock) {
        // Handle manual unlock completion
        Serial.println("✅ Manual unlock completed for teacher ID: " + currentManualUnlockTeacherID);
        WebSerial.println("✅ Manual unlock completed for teacher ID: " + currentManualUnlockTeacherID);
        Serial.println("🔒 Manual unlock timeout reached (" + String(manualUnlockDuration) + "ms) - locking door");
        WebSerial.println("🔒 Manual unlock timeout reached (" + String(manualUnlockDuration) + "ms) - locking door");
        
        // Update Firebase status to 'completed' (commands path)
        String statusPath = "/door_unlock_commands/" + currentManualUnlockTeacherID + "/status";
        String completedAtPath = "/door_unlock_commands/" + currentManualUnlockTeacherID + "/completedAt";
        
        Firebase.RTDB.setString(&fbdo, statusPath, "completed");
        Firebase.RTDB.setTimestamp(&fbdo, completedAtPath);
        
        // Reset manual unlock flags
        isManualUnlock = false;
        currentManualUnlockTeacherID = "";
        manualUnlockDuration = 4000; // Reset to default
        
        wsHandler.sendNetworkEvent("manual_unlock_completed", "Manual unlock completed");
      } else {
        // This is a regular RFID unlock - handle normally
        Serial.println("🔒 Door timeout reached (" + String(DOOR_OPEN_DURATION) + "ms) - locking door");
        WebSerial.println("🔒 Door timeout reached (" + String(DOOR_OPEN_DURATION) + "ms) - locking door");
      }
      
      // Lock the door regardless of unlock type
      digitalWrite(RELAY_PIN, LOW);
      isDoorUnlocked = false;
      wsHandler.sendDoorStatus(false);
    }
  }
}

void doorLogic(String uid, uint8_t reader) {

  if (!Firebase.ready()) {
      Serial.println("⚠️ Firebase not ready, token might be refreshing. Access denied.");
      WebSerial.println("⚠️ Firebase not ready, token might be refreshing. Access denied.");
      logAccessAttempt(uid, "Denied (Firebase Not Ready)", reader);
      wsHandler.sendDoorStatus(false);
      return;
  }


  if (!firebaseConnected) {
    Serial.println("⚠️  Firebase not connected - access denied (offline mode)");
    WebSerial.println("⚠️  Firebase not connected - access denied (offline mode)");
    logAccessAttempt(uid, "Denied (Offline)", reader);
    wsHandler.sendDoorStatus(false);
    return;
  }

  String path = "/rfid_tags/" + uid;
  bool accessGranted = false;
  String reason = "Not Found";
  String assignedTeacherID = "";

  Serial.println("🔍 Checking database permissions for: " + uid);
  WebSerial.println("🔍 Checking database permissions for: " + uid);

  if (Firebase.RTDB.getString(&fbdo, path + "/status")) {
    if (fbdo.dataType() == "string") {
      String status = fbdo.stringData();
      Serial.println("   Database status: " + status);
      WebSerial.println("   Database status: " + status);
      
      if (status == "active") {
        accessGranted = true;
        reason = "Granted";
        
        // Get assigned teacher ID
        if (Firebase.RTDB.getString(&fbdo, path + "/assignedTo")) {
          assignedTeacherID = fbdo.stringData();
          Serial.println("   Assigned to: " + assignedTeacherID);
          WebSerial.println("   Assigned to: " + assignedTeacherID);
        } else {
          Serial.println("   No teacher assignment found");
          WebSerial.println("   No teacher assignment found");
        }
      } else {
        reason = "Denied (" + status + ")";
      }
    }
  } else {
    Serial.println("❌ Database lookup failed: " + fbdo.errorReason());
    WebSerial.println("❌ Database lookup failed: " + fbdo.errorReason());
    reason = "Database Error";
  }
  
  if (accessGranted) {
    Serial.println("✅ ACCESS GRANTED");
    WebSerial.println("✅ ACCESS GRANTED");
    digitalWrite(RELAY_PIN, HIGH);
    isDoorUnlocked = true;         
    doorUnlockTime = millis();
    
    wsHandler.sendDoorStatus(true);
    wsHandler.sendNetworkEvent("door_unlocked", "Access granted for: " + uid);
    
    if (!assignedTeacherID.isEmpty()) {
      Serial.println("👨‍🏫 Processing teacher attendance: " + assignedTeacherID);
      WebSerial.println("👨‍🏫 Processing teacher attendance: " + assignedTeacherID);
      updateTeacherStatus(assignedTeacherID, reader);
      logAttendance(assignedTeacherID, reader);
    }
  } else {
    Serial.println("❌ ACCESS DENIED - " + reason);
    WebSerial.println("❌ ACCESS DENIED - " + reason);
    wsHandler.sendDoorStatus(false);
    wsHandler.sendNetworkEvent("door_denied", "Access denied: " + reason);
  }
  
  logAccessAttempt(uid, reason, reader);
}

// ---------- Teacher Management ----------
void updateTeacherStatus(String teacherID, uint8_t reader) {
  if (!firebaseConnected) return;

  String teacherPath = "/roles/teacher";
  
  if (Firebase.RTDB.get(&fbdo, teacherPath)) {
    FirebaseJson &json = fbdo.jsonObject();
    size_t len = json.iteratorBegin();
    String key, value;
    int type = 0;
    
    for (size_t i = 0; i < len; i++) {
      json.iteratorGet(i, type, key, value);
      
      FirebaseJsonData data;
      if (json.get(data, key + "/teacherID")) {
        if (data.stringValue == teacherID) {
          String basePath = teacherPath + "/" + key;
          
          String newStatus = (reader == 0) ? "online" : "offline";
          
          // Update status and unified timestamp
          Firebase.RTDB.setString(&fbdo, basePath + "/active_status", newStatus);
          Firebase.RTDB.setTimestamp(&fbdo, basePath + "/status_changed_at");
          
          // Also update specific entry/exit timestamps
          if (reader == 0) {
            Firebase.RTDB.setTimestamp(&fbdo, basePath + "/last_entry_time");
            
            // Check if first entry today
            String todayKey = getCurrentDateKey(); // YYYYMMDD format
            String firstEntryPath = basePath + "/daily_first_entry/" + todayKey;
            if (!Firebase.RTDB.get(&fbdo, firstEntryPath)) {
              Firebase.RTDB.setTimestamp(&fbdo, firstEntryPath);
            }
          } else {
            Firebase.RTDB.setTimestamp(&fbdo, basePath + "/last_exit_time");
            
            // Update today's last exit
            String todayKey = getCurrentDateKey();
            Firebase.RTDB.setTimestamp(&fbdo, basePath + "/daily_last_exit/" + todayKey);
          }
          
          Serial.println("👨‍🏫 Updated " + teacherID + " status: " + newStatus);
          WebSerial.println("👨‍🏫 Updated " + teacherID + " status: " + newStatus);
          Serial.println("   Status changed at: " + String(millis()));
          WebSerial.println("   Status changed at: " + String(millis()));
          
          // Send WebSocket notification with status change
          wsHandler.sendTeacherStatusUpdate(teacherID, newStatus);
          
          break;
        }
      }
    }
    json.iteratorEnd();
  }
}

// Helper function to get current date as YYYYMMDD
String getCurrentDateKey() {
  time_t now;
  struct tm timeinfo;
  
  time(&now);
  localtime_r(&now, &timeinfo);
  
  char dateStr[9];
  sprintf(dateStr, "%04d%02d%02d", 
          timeinfo.tm_year + 1900,
          timeinfo.tm_mon + 1,
          timeinfo.tm_mday);
  
  return String(dateStr);
}

void logAttendance(String teacherID, uint8_t reader) {
  if (!firebaseConnected) return;

  String basePath = "/attendance_logs/" + teacherID;
  
  FirebaseJson logEntry;
  logEntry.set("timestamp/.sv", "timestamp");
  logEntry.set("action", (reader == 0) ? "entry" : "exit");
  logEntry.set("reader_id", reader);
  logEntry.set("device_ip", WiFi.localIP().toString());
  
  Firebase.RTDB.pushJSON(&fbdo, basePath + "/logs", &logEntry);
  
  String status = (reader == 0) ? "in" : "out";
  Firebase.RTDB.setString(&fbdo, basePath + "/current_status", status);
  Firebase.RTDB.setTimestamp(&fbdo, basePath + "/last_activity");
  
  Serial.println("📊 Attendance logged: " + teacherID + " - " + String((reader == 0) ? "Entry" : "Exit"));
  WebSerial.println("📊 Attendance logged: " + teacherID + " - " + String((reader == 0) ? "Entry" : "Exit"));
}