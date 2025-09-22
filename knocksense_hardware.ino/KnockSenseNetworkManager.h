#ifndef KNOCKSENSE_NETWORK_MANAGER_H
#define KNOCKSENSE_NETWORK_MANAGER_H

#include <WiFi.h>
#include <ESPmDNS.h>
#include <esp_wifi.h>

// Forward declarations
class LittleFSConfig;
class WebSocketHandler;

void onWiFiEvent(arduino_event_id_t event, arduino_event_info_t info);

class KnockSenseNetworkManager {
private:
    LittleFSConfig* config;
    WebSocketHandler* wsHandler;

    bool staConnected;
    unsigned long lastConnectionAttempt;
    
    // Private methods
    void connectWiFi();
    void startAP();
    

public:
    KnockSenseNetworkManager(LittleFSConfig* cfg, WebSocketHandler* ws);

    void begin();
    void loop();
    void forceReconnect();
    void updateWiFiCredentials(String ssid, String password);
    void printNetworkInfo();
    
    void handleEvent(arduino_event_id_t event, arduino_event_info_t info);

    bool isSTAConnected() { return staConnected; }
};

#endif // KNOCKSENSE_NETWORK_MANAGER_H