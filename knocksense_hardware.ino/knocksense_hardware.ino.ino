#include <WiFi.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Firebase_ESP_Client.h>



// ---------- WiFi ----------
const char* WIFI_SSID = "DYWIFI";
const char* WIFI_PASS = "tJSRQ4zY";

// ---------- RFID / hardware ----------
#define NR_OF_READERS 2
#define SS_1  5
#define SS_2  17

#define RST_1 21
#define RST_2 22


#define RELAY_PIN 32 // solenoid relay pin

byte ssPins [] = {SS_1, SS_2};
byte rstPins [] = {RST_1, RST_2};

unsigned long doorUnlockTime = 0;
bool isDoorUnlocked = false;
const long doorOpenDuration = 6000;


MFRC522 mfrc522[NR_OF_READERS];


//FIREBASE INSTANCES
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

#define API_KEY ""
#define DATABASE_URL ""


#define ADMIN_EMAIL "fateh8er201@gmail.com" //ESP32 email
#define ADMIN_PASSWORD "Cv250a178abcd!"

String uidToString(byte *buffer, byte bufferSize) {
  String localUID = "";  // Use local variable instead of global
  for (byte i = 0; i < bufferSize; i++) {
    if (buffer[i] < 0x10) localUID += "0";
    localUID += String(buffer[i], HEX);
    if (i < bufferSize - 1) localUID += ":";
  }
  localUID.toUpperCase();
  return localUID;
}



void setup(){

Serial.begin(115200);   // Initialize serial communications with the PC
while (!Serial);        // Do nothing if no serial port is opened (for ATMEGA32U4 boards)

SPI.begin();            // Init SPI bus
initReader();
connectWiFi();
connectFirebase();


pinMode(RELAY_PIN, OUTPUT);
digitalWrite(RELAY_PIN, LOW);



}

void loop() {
  checkRFID();
  manageDoorLock();
}

void connectFirebase() {
  Serial.print("Connecting to Firebase... ");
  
  // Assign the project credentials
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  // <<< MODIFIED: Assign the user credentials for login
  auth.user.email = ADMIN_EMAIL;
  auth.user.password = ADMIN_PASSWORD;

  // Begin Firebase connection
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Check for connection status
  if (Firebase.ready()){
    Serial.println("Connected and authenticated.");
  } else {
    Serial.println("Authentication failed.");
    Serial.println("REASON: " + fbdo.errorReason()); // fbdo gives more detailed auth errors
  }
}


void addOrUpdateRfidTag(String uid) {
  // Construct the specific path for this UID.
  String path = "/rfid_tags/" + uid; 
  
  Serial.println("Processing RFID tag: " + uid);
  Serial.println();
  
  // Try to read just a specific field to check if tag exists
  // This is more reliable than trying to read the entire object
  String statusPath = path + "/status";
  
  if (Firebase.RTDB.getString(&fbdo, statusPath)) {
    // Tag exists - just update the lastSeen timestamp
    Serial.println("Known RFID tag. New timestamp for currently scanned UID.");
    
  } else {
    // Check if the error is because the path doesn't exist (which is what we want for new tags)
    if (fbdo.errorCode() == FIREBASE_ERROR_PATH_NOT_EXIST || fbdo.dataType() == "null") {
      // New tag - create it
      Serial.println("New RFID tag detected. Adding to database...");
      
      FirebaseJson json;
      json.set("status", "active"); //boolean in mob/web app 1 = active | 0 = inactive
      json.set("assignedTo", "null");
      json.set("createdAt/.sv", "timestamp");

      if (Firebase.RTDB.setJSON(&fbdo, path, &json)) {
        Serial.println("New tag added successfully!");
      } else {
        Serial.println("ERROR: Failed to add new tag: " + fbdo.errorReason());
      }
    } else {
      // Some other error occurred
      Serial.println("ERROR: Could not check for tag. Reason: " + fbdo.errorReason());
      Serial.println("Error code: " + String(fbdo.errorCode()));
    }
  }
}

void logAccessAttempt(String uid, String result, uint8_t reader) {
  String path = "/access_logs";
  String readerRole = "";
  FirebaseJson json;

  if(reader == 0){
    readerRole = "Entry";
  }else if (reader == 1){
    readerRole = "Exit";
  }else{
    Serial.println("Reader detection failed");
  }

  json.set("uid", uid);
  json.set("result", result);
  json.set("readerRole", readerRole);
  json.set("timestamp/.sv", "timestamp");
  Firebase.RTDB.pushJSON(&fbdo, path, &json);
}

void manageDoorLock() {
  // If the door is unlocked and 6 seconds have passed...
  if (isDoorUnlocked && (millis() - doorUnlockTime >= doorOpenDuration)) {
    Serial.println("6 seconds have passed. Locking the door.");
    digitalWrite(RELAY_PIN, LOW); // Lock the door
    isDoorUnlocked = false;       // Update the state
  }
}




void doorLogic(String uid, uint8_t reader) { // We no longer need the 'reader' index here.
  String path = "/rfid_tags/" + uid;
  bool accessGranted = false;
  String reason = "Not Found";

  Serial.println("Checking database for UID: " + uid);

  // Query Firebase for the status of this specific UID
  if (Firebase.RTDB.getString(&fbdo, path + "/status")) {
    if (fbdo.dataType() == "string") {
      String status = fbdo.stringData();
      Serial.println("Database status: " + status);
      if (status == "active") {
        accessGranted = true;
        reason = "Granted";
      } else {
        reason = "Denied (" + status + ")";
      }
    }
  } else {
      Serial.println("Error fetching status: " + fbdo.errorReason());
  }
  
  // --- Perform Action Based on Query Result ---
  if (accessGranted) {
    Serial.println("ACCESS GRANTED");
    digitalWrite(RELAY_PIN, HIGH);
    isDoorUnlocked = true;         
    doorUnlockTime = millis();  
    //digitalWrite(RELAY_PIN, LOW);
  } else {
    Serial.println("ACCESS DENIED");
  }
  
  // Log the final result of the attempt
  logAccessAttempt(uid, reason, reader);
}

void checkRFID() {
  for (uint8_t reader = 0; reader < NR_OF_READERS; reader++) {
    // Look for new cards and read their serial number
    if (mfrc522[reader].PICC_IsNewCardPresent() && mfrc522[reader].PICC_ReadCardSerial()) {

      byte uidSize = mfrc522[reader].uid.size;

      if (uidSize == 4 || uidSize == 7) {
        String uid = uidToString(mfrc522[reader].uid.uidByte, uidSize);
        
        Serial.print("\nReader " + String(reader) + ": Valid Card Scanned. UID: " + uid);
        Serial.println();
        
        addOrUpdateRfidTag(uid);
        
        doorLogic(uid, reader);

      } else {
        Serial.print("\nReader " + String(reader) + ": Invalid UID size detected (" + String(uidSize) + " bytes). Ignoring scan.");
      }
      
      mfrc522[reader].PICC_HaltA();
      mfrc522[reader].PCD_StopCrypto1();
      
      delay(500); 
    }
  }
}

void dump_byte_array(byte *buffer, byte bufferSize) {
  for (byte i = 0; i < bufferSize; i++) {
    Serial.print(buffer[i] < 0x10 ? " 0" : " ");
    Serial.print(buffer[i], HEX);
  }
}




void connectWiFi() {
  WiFi.mode(WIFI_AP_STA);
  WiFi.begin();

  Serial.print("Connecting to WiFi ..");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print('.');
    delay(1000);
  }
  Serial.println();
  Serial.println(WiFi.localIP());
}

  void initReader() {
  for (uint8_t reader = 0; reader < NR_OF_READERS; reader++) {
    mfrc522[reader].PCD_Init(ssPins[reader], rstPins[reader]); // Init each MFRC522 card
    Serial.print(F("Reader "));
    Serial.print(reader);
    Serial.print(F(": "));
    mfrc522[reader].PCD_DumpVersionToSerial();
  }
}
