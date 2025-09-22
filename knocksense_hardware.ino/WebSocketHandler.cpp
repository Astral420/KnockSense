// File: WebSocketHandler.cpp

#include "WebSocketHandler.h"
#include "LittleFSConfig.h"

WebSocketHandler::WebSocketHandler(LittleFSConfig* cfg) 
    : ws("/ws"), scanModeActive(false), config(cfg), 
      wifiConfigUpdated(false), wifiReconnectRequested(false) {}

void WebSocketHandler::begin(AsyncWebServer* server) {
    ws.onEvent([this](AsyncWebSocket *server, AsyncWebSocketClient *client, AwsEventType type, void *arg, uint8_t *data, size_t len) {
        this->onEvent(server, client, type, arg, data, len);
    });
    server->addHandler(&ws);
}

void WebSocketHandler::onEvent(AsyncWebSocket *server, AsyncWebSocketClient *client, AwsEventType type, void *arg, uint8_t *data, size_t len) {
    if (type == WS_EVT_CONNECT) {
        Serial.printf("WebSocket client #%u connected\n", client->id());
        
        
        delay(100); 
        sendSystemStatus();
        
    } else if (type == WS_EVT_DISCONNECT) {
        Serial.printf("WebSocket client #%u disconnected\n", client->id());
    } else if (type == WS_EVT_DATA) {
        handleWebSocketMessage(arg, data, len, (AwsFrameInfo*)arg, client);
    }
}

void WebSocketHandler::handleWebSocketMessage(void *arg, uint8_t *data, size_t len, AwsFrameInfo *info, AsyncWebSocketClient *client) {
    if (info->final && info->index == 0 && info->len == len && info->opcode == WS_TEXT) {
        data[len] = 0;
        StaticJsonDocument<512> doc;
        if (deserializeJson(doc, (char*)data) == DeserializationError::Ok) {
            processCommand(doc, client);
        }
    }
}

void WebSocketHandler::processCommand(JsonDocument& doc, AsyncWebSocketClient *client) {
    const char* type = doc["type"];
    if (!type) return;

    if (strcmp(type, "scan_mode") == 0) {
        scanModeActive = doc["enabled"];
    } else if (strcmp(type, "wifi_config") == 0) {
        newSSID = doc["ssid"].as<String>();
        newPassword = doc["password"].as<String>();
        wifiConfigUpdated = true;
    } else if (strcmp(type, "wifi_reconnect") == 0) {
        wifiReconnectRequested = true;
    } else if (strcmp(type, "status") == 0 || strcmp(type, "system_status_request") == 0) {
        // Send current status immediately
        sendSystemStatus();
    }
    // Add other command handlers here
}

void WebSocketHandler::sendWifiStatus(bool connected, String ssid, String ip) {
    StaticJsonDocument<256> doc;
    doc["type"] = "wifi_status";
    doc["connected"] = connected;
    doc["wifi_connected"] = connected;
    doc["ssid"] = ssid;
    doc["ip"] = ip;
    
    String message;
    serializeJson(doc, message);
    ws.textAll(message);
}

void WebSocketHandler::sendSystemStatus() {
    StaticJsonDocument<512> doc;
    doc["type"] = "system_status";
    doc["wifi_connected"] = (WiFi.status() == WL_CONNECTED);
    doc["heap_free"] = ESP.getFreeHeap();
    doc["uptime"] = millis();
    
    if (WiFi.status() == WL_CONNECTED) {
        doc["ssid"] = WiFi.SSID();
        doc["ip"] = WiFi.localIP().toString();
    } else {
        doc["ssid"] = "";
        doc["ip"] = "";
    }
    
    String message;
    serializeJson(doc, message);
    ws.textAll(message);
    
    Serial.println("Sent system status - WiFi: " + String(WiFi.status() == WL_CONNECTED ? "connected" : "disconnected"));
}

void WebSocketHandler::getNewWifiConfig(String &ssid, String &password) { ssid = newSSID; password = newPassword; }
void WebSocketHandler::clearWifiConfigUpdate() { wifiConfigUpdated = false; }
void WebSocketHandler::clearReconnectRequest() { wifiReconnectRequested = false; }
void WebSocketHandler::notifyClients(String message) { ws.textAll(message); }
void WebSocketHandler::sendRfidScan(String uid) { /* Implementation here */ }
void WebSocketHandler::sendDoorStatus(bool u) { /* Implementation here */ }
void WebSocketHandler::sendNetworkEvent(String e, String d) { /* Implementation here */ }
void WebSocketHandler::sendConnectionProgress(String s, String d) { /* Implementation here */ }
void WebSocketHandler::loop() { ws.cleanupClients(); }