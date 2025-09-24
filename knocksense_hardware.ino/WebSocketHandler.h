// File: WebSocketHandler.h

#ifndef WEBSOCKET_HANDLER_H
#define WEBSOCKET_HANDLER_H

#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <WiFi.h>

class LittleFSConfig; // Forward declaration

class WebSocketHandler {
private:
    AsyncWebSocket ws;
    bool scanModeActive;
    LittleFSConfig* config;
    String newSSID;
    String newPassword;
    bool wifiConfigUpdated;
    bool wifiReconnectRequested;

    void handleWebSocketMessage(void *arg, uint8_t *data, size_t len, AwsFrameInfo *info, AsyncWebSocketClient *client);
    void onEvent(AsyncWebSocket *server, AsyncWebSocketClient *client, AwsEventType type, void *arg, uint8_t *data, size_t len);
    void processCommand(JsonDocument& doc, AsyncWebSocketClient *client);

public:
    WebSocketHandler(LittleFSConfig* cfg);

    void begin(AsyncWebServer* server);
    void loop();

    void notifyClients(String message);
    void sendRfidScan(String uid);
    void sendWifiStatus(bool connected, String ssid, String ip);
    void sendSystemStatus();
    void sendDoorStatus(bool unlocked);
    void sendNetworkEvent(String event, String details);
    void sendConnectionProgress(String stage, String details);
    void sendRfidAddedStatus(String uid, bool success, String error = "");
    void sendTeacherStatusUpdate(String teacherID, String newStatus);

    bool isScanMode() { return scanModeActive; }
    bool hasNewWifiConfig() { return wifiConfigUpdated; }
    bool hasReconnectRequest() { return wifiReconnectRequested; }
    void getNewWifiConfig(String &ssid, String &password);
    void clearWifiConfigUpdate();
    void clearReconnectRequest();
};

#endif // WEBSOCKET_HANDLER_H