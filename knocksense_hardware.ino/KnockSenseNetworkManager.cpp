// File: KnockSenseNetworkManager.cpp

#include "KnockSenseNetworkManager.h"
#include "LittleFSConfig.h"
#include "WebSocketHandler.h"
#include <WebSerial.h>

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
    WebSerial.println("\n=== Network Manager Starting ===");

    WiFi.mode(WIFI_AP_STA);

    Network.onEvent(onWifiEvent);

    startAP();

    if (MDNS.begin("knocksense")) {
        WebSerial.println("mDNS responder started: knocksense.local");
        MDNS.addService("http", "tcp", 81);
    }
    
    if (!config->config.wifi_ssid.isEmpty()) {
        connectWiFi();
    } else {
        WebSerial.println("No saved WiFi credentials - AP-only mode");
    }
}

void KnockSenseNetworkManager::loop() {
    // Reconnection logic
    if (!staConnected && config->shouldRetryConnection()) {
        WebSerial.println("Attempting WiFi reconnection...");
        connectWiFi();
    }
    
}

void KnockSenseNetworkManager::startAP() {
    WebSerial.println("Starting Access Point...");

    WiFi.AP.begin();

    IPAddress apIP(192, 168, 4, 1);
    IPAddress gateway(192, 168, 4, 1);
    IPAddress leaseStart(192, 168, 4, 2);
    IPAddress subnet(255, 255, 255, 0);
    IPAddress dns(8, 8, 4, 4);

    WiFi.AP.config(apIP, gateway, subnet, leaseStart, dns);
    WiFi.softAP(config->config.ap_ssid.c_str(), config->config.ap_password.c_str());
    WebSerial.println("✅ AP Started: " + config->config.ap_ssid + " at IP: " + WiFi.softAPIP().toString());
}

void KnockSenseNetworkManager::connectWiFi() {
    if (config->config.wifi_ssid.isEmpty()) return;
    
    WebSerial.println("Connecting to WiFi: " + config->config.wifi_ssid);
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
    WebSerial.println("Forcing WiFi reconnection");
    staConnected = false;
    WiFi.disconnect(false);
    delay(1000);
    config->resetFailCount();
    connectWiFi();
}

void KnockSenseNetworkManager::updateWiFiCredentials(String ssid, String password) {
    WebSerial.println("Updating WiFi credentials for: " + ssid);
    if (config->updateWiFiConfig(ssid, password)) {
        forceReconnect();
    }
}

void KnockSenseNetworkManager::printNetworkInfo() {
    WebSerial.println("\n=== Network Status ===");
    WebSerial.println("Access Point: " + config->config.ap_ssid + " (" + WiFi.softAPIP().toString() + ")");
    if (staConnected) {
        WebSerial.println("Station Mode: ✅ Connected to " + WiFi.SSID() + " (" + WiFi.localIP().toString() + ")");
    } else {
        WebSerial.println("Station Mode: ❌ Disconnected");
    }
    WebSerial.println("======================\n");
}

// --- The WiFi Event Handler ---
void KnockSenseNetworkManager::handleEvent(arduino_event_id_t event, arduino_event_info_t info) {
    switch (event) {
        case ARDUINO_EVENT_WIFI_AP_START:
            WebSerial.println("Event: AP Started");
            break;

        case ARDUINO_EVENT_WIFI_STA_START:
            WebSerial.println("Event: STA Started");
            break;

        case ARDUINO_EVENT_WIFI_STA_GOT_IP:
            WebSerial.println("Event: STA Got IP: " + WiFi.localIP().toString());
            staConnected = true;
            config->resetFailCount();

            // Use the Arduino Core NAPT function
            WiFi.AP.enableNAPT(true);
            WebSerial.println("NAPT Enabled on AP");

            if (wsHandler) {
                wsHandler->sendWifiStatus(true, WiFi.SSID(), WiFi.localIP().toString());
            }
            printNetworkInfo();
            break;

        case ARDUINO_EVENT_WIFI_STA_DISCONNECTED:
            WebSerial.println("Event: STA Disconnected.");
            staConnected = false;
            config->incrementFailCount();

            // Disable NAPT
            WiFi.AP.enableNAPT(false);
            WebSerial.println("NAPT Disabled on AP");

            if (wsHandler) {
                wsHandler->sendWifiStatus(false, "", "");
            }
            break;
            
        default:
            break;
    }
}