// File: LittleFSConfig.cpp

#include "LittleFSConfig.h"

bool LittleFSConfig::begin() {
    if (!LittleFS.begin(true)) {
        Serial.println("LittleFS mount failed!");
        return false;
    }
    Serial.println("LittleFS mounted successfully");
    if (!loadConfig()) {
        Serial.println("Failed to load config, using defaults");
        setDefaults();
        saveConfig();
    }
    return true;
}

bool LittleFSConfig::loadConfig() {
    File file = LittleFS.open(configFile, "r");
    if (!file) return false;

    StaticJsonDocument<2048> doc;
    DeserializationError error = deserializeJson(doc, file);
    file.close();

    if (error) {
        Serial.println("Failed to parse config file");
        return false;
    }

    config.wifi_ssid = doc["wifi_ssid"] | "";
    config.wifi_password = doc["wifi_password"] | "";
    config.ap_ssid = doc["ap_ssid"] | "KnockSense";
    config.ap_password = doc["ap_password"] | "12345678";
    config.admin_email = doc["admin_email"] | "";
    config.admin_password = doc["admin_password"] | "";
    config.firebase_api_key = doc["firebase_api_key"] | "";
    config.firebase_db_url = doc["firebase_db_url"] | "";
    config.dhcp_enabled = doc["dhcp_enabled"] | true;
    config.relay_pin = doc["relay_pin"] | 32;
    config.door_open_duration = doc["door_open_duration"] | 6000;
    config.wifi_fail_count = doc["wifi_fail_count"] | 0;
    config.last_known_ip = doc["last_known_ip"] | "";
    config.auto_reconnect = doc["auto_reconnect"] | true;
    config.last_connection_attempt = doc["last_connection_attempt"] | 0;

    return true;
}

bool LittleFSConfig::saveConfig() {
    StaticJsonDocument<2048> doc;
    doc["wifi_ssid"] = config.wifi_ssid;
    doc["wifi_password"] = config.wifi_password;
    doc["ap_ssid"] = config.ap_ssid;
    doc["ap_password"] = config.ap_password;
    doc["admin_email"] = config.admin_email;
    doc["admin_password"] = config.admin_password;
    doc["firebase_api_key"] = config.firebase_api_key;
    doc["firebase_db_url"] = config.firebase_db_url;
    doc["dhcp_enabled"] = config.dhcp_enabled;
    doc["relay_pin"] = config.relay_pin;
    doc["door_open_duration"] = config.door_open_duration;
    doc["wifi_fail_count"] = config.wifi_fail_count;
    doc["last_known_ip"] = config.last_known_ip;
    doc["auto_reconnect"] = config.auto_reconnect;
    doc["last_connection_attempt"] = config.last_connection_attempt;

    File file = LittleFS.open(configFile, "w");
    if (!file) return false;

    bool success = serializeJson(doc, file) > 0;
    file.close();
    return success;
}

void LittleFSConfig::setDefaults() {
    config.wifi_ssid = "DYWIFI";
    config.wifi_password = "tJSRQ4zY";
    config.ap_ssid = "KnockSense";
    config.ap_password = "12345678";
    config.admin_email = "coolrigby101@gmail.com";
    config.admin_password = "Cv250a178abcd!";
    config.firebase_api_key = "AIzaSyADwTJ55RaBvjvpulAY7T7ORW2dnxZFNqQ";
    config.firebase_db_url = "https://knocksense-21180-default-rtdb.asia-southeast1.firebasedatabase.app";
    config.dhcp_enabled = true;
    config.relay_pin = 32;
    config.door_open_duration = 6000;
    config.wifi_fail_count = 0;
    config.last_known_ip = "";
    config.auto_reconnect = true;
    config.last_connection_attempt = 0;
}

void LittleFSConfig::printConfig() { /* Implementation here */ }
bool LittleFSConfig::format() { return LittleFS.format(); }
void LittleFSConfig::listFiles() { /* Implementation here */ }
size_t LittleFSConfig::getFreeSpace() { return LittleFS.totalBytes() - LittleFS.usedBytes(); }
size_t LittleFSConfig::getUsedSpace() { return LittleFS.usedBytes(); }
size_t LittleFSConfig::getTotalSpace() { return LittleFS.totalBytes(); }
bool LittleFSConfig::updateWiFiConfig(String ssid, String password) { config.wifi_ssid = ssid; config.wifi_password = password; return saveConfig(); }
bool LittleFSConfig::updateFirebaseConfig(String apiKey, String dbUrl, String email, String password) { /* Implementation here */ return saveConfig(); }
void LittleFSConfig::incrementFailCount() { config.wifi_fail_count++; config.last_connection_attempt = millis(); saveConfig(); }
void LittleFSConfig::resetFailCount() { if (config.wifi_fail_count > 0) { config.wifi_fail_count = 0; saveConfig(); } }
bool LittleFSConfig::shouldRetryConnection() { if (!config.auto_reconnect || config.wifi_fail_count >= 5) return false; unsigned long retryDelay = 30000 * (config.wifi_fail_count + 1); return (millis() - config.last_connection_attempt) > retryDelay; }
void LittleFSConfig::updateLastConnectionAttempt() { config.last_connection_attempt = millis(); saveConfig(); }
String LittleFSConfig::getConnectionStatus() { /* Implementation here */ return ""; }
