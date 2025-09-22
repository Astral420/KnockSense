// File: KnockSenseNetworkManager.cpp

#include "KnockSenseNetworkManager.h"
#include "LittleFSConfig.h"
#include "WebSocketHandler.h"

KnockSenseNetworkManager* networkManagerInstance = nullptr;

void onWifiEvent(arduino_event_id_t event, arduino_event_info_t info) {
    if (networkManagerInstance) {
        networkManagerInstance->handleEvent(event, info);
    }
}

// Constructor
KnockSenseNetworkManager::KnockSenseNetworkManager(LittleFSConfig* cfg, WebSocketHandler* ws)
    : config(cfg), wsHandler(ws), staConnected(false) {
    // Set the global pointer to this instance
    networkManagerInstance = this;
}

void KnockSenseNetworkManager::begin() {
    Serial.println("\n=== Network Manager Starting ===");

    WiFi.mode(WIFI_AP_STA);

    Network.onEvent(onWifiEvent);

    startAP();

    if (MDNS.begin("knocksense")) {
        Serial.println("mDNS responder started: knocksense.local");
        MDNS.addService("http", "tcp", 81);
    }
    
    if (!config->config.wifi_ssid.isEmpty()) {
        connectWiFi();
    } else {
        Serial.println("No saved WiFi credentials - AP-only mode");
    }
}

void KnockSenseNetworkManager::loop() {
    // Reconnection logic
    if (!staConnected && config->shouldRetryConnection()) {
        Serial.println("Attempting WiFi reconnection...");
        connectWiFi();
    }
    
}

void KnockSenseNetworkManager::startAP() {
    Serial.println("Starting Access Point...");

    WiFi.AP.begin();

    IPAddress apIP(192, 168, 4, 1);
    IPAddress gateway(192, 168, 4, 1);
    IPAddress leaseStart(192, 168, 4, 2);
    IPAddress subnet(255, 255, 255, 0);
    IPAddress dns(8, 8, 4, 4);

    WiFi.AP.config(apIP, gateway, subnet, leaseStart, dns);
    WiFi.softAP(config->config.ap_ssid.c_str(), config->config.ap_password.c_str());
    Serial.println("✅ AP Started: " + config->config.ap_ssid + " at IP: " + WiFi.softAPIP().toString());
}

void KnockSenseNetworkManager::connectWiFi() {
    if (config->config.wifi_ssid.isEmpty()) return;
    
    Serial.println("Connecting to WiFi: " + config->config.wifi_ssid);
    if (wsHandler) {
        wsHandler->sendConnectionProgress("connecting", "Attempting connection...");
    }

    if (!config->config.dhcp_enabled) {
        WiFi.config(config->config.static_ip, config->config.gateway, config->config.subnet);
    }

    WiFi.begin(config->config.wifi_ssid.c_str(), config->config.wifi_password.c_str());
    lastConnectionAttempt = millis();
    config->updateLastConnectionAttempt();
}

void KnockSenseNetworkManager::forceReconnect() {
    Serial.println("Forcing WiFi reconnection");
    staConnected = false;
    WiFi.disconnect(true);
    delay(1000);
    config->resetFailCount();
    connectWiFi();
}

void KnockSenseNetworkManager::updateWiFiCredentials(String ssid, String password) {
    Serial.println("Updating WiFi credentials for: " + ssid);
    if (config->updateWiFiConfig(ssid, password)) {
        forceReconnect();
    }
}

void KnockSenseNetworkManager::printNetworkInfo() {
    Serial.println("\n=== Network Status ===");
    Serial.println("Access Point: " + config->config.ap_ssid + " (" + WiFi.softAPIP().toString() + ")");
    if (staConnected) {
        Serial.println("Station Mode: ✅ Connected to " + WiFi.SSID() + " (" + WiFi.localIP().toString() + ")");
    } else {
        Serial.println("Station Mode: ❌ Disconnected");
    }
    Serial.println("======================\n");
}

// --- The WiFi Event Handler ---
void KnockSenseNetworkManager::handleEvent(arduino_event_id_t event, arduino_event_info_t info) {
    switch (event) {
        case ARDUINO_EVENT_WIFI_AP_START:
            Serial.println("Event: AP Started");
            break;

        case ARDUINO_EVENT_WIFI_STA_START:
            Serial.println("Event: STA Started");
            break;

        case ARDUINO_EVENT_WIFI_STA_GOT_IP:
            Serial.println("Event: STA Got IP: " + WiFi.localIP().toString());
            staConnected = true;
            config->resetFailCount();

            // Use the Arduino Core NAPT function
            WiFi.AP.enableNAPT(true);
            Serial.println("NAPT Enabled on AP");

            if (wsHandler) {
                wsHandler->sendWifiStatus(true, WiFi.SSID(), WiFi.localIP().toString());
            }
            printNetworkInfo();
            break;

        case ARDUINO_EVENT_WIFI_STA_DISCONNECTED:
            Serial.println("Event: STA Disconnected.");
            staConnected = false;
            config->incrementFailCount();

            // Disable NAPT
            WiFi.AP.enableNAPT(false);
            Serial.println("NAPT Disabled on AP");

            if (wsHandler) {
                wsHandler->sendWifiStatus(false, "", "");
            }
            break;
            
        default:
            break;
    }
}