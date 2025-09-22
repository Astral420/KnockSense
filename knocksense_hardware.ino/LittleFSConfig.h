// File: LittleFSConfig.h

#ifndef LITTLEFS_CONFIG_H
#define LITTLEFS_CONFIG_H

#include <LittleFS.h>
#include <ArduinoJson.h>
#include <WiFi.h>

class LittleFSConfig {
private:
    const char* configFile = "/config.json";

public:
    struct Config {
        String wifi_ssid;
        String wifi_password;
        String ap_ssid;
        String ap_password;
        String admin_email;
        String admin_password;
        String firebase_api_key;
        String firebase_db_url;
        bool dhcp_enabled;
        IPAddress static_ip;
        IPAddress gateway;
        IPAddress subnet;
        IPAddress dns1;
        IPAddress dns2;
        int relay_pin;
        int door_open_duration;
        int ss_pins[2];
        int rst_pins[2];
        int wifi_fail_count;
        String last_known_ip;
        bool auto_reconnect;
        unsigned long last_connection_attempt;
    };

    Config config;

    bool begin();
    bool loadConfig();
    bool saveConfig();
    void setDefaults();
    void printConfig();
    bool format();
    void listFiles();
    size_t getFreeSpace();
    size_t getUsedSpace();
    size_t getTotalSpace();
    
    bool updateWiFiConfig(String ssid, String password);
    bool updateFirebaseConfig(String apiKey, String dbUrl, String email, String password);
    void incrementFailCount();
    void resetFailCount();
    bool shouldRetryConnection();
    void updateLastConnectionAttempt();
    String getConnectionStatus();
};

#endif // LITTLEFS_CONFIG_H