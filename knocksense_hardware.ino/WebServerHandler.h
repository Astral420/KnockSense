// Enhanced WebServerHandler.h
#ifndef WEBSERVER_HANDLER_H
#define WEBSERVER_HANDLER_H

#include <ESPAsyncWebServer.h>
#include <LittleFS.h>
#include <ArduinoJson.h>
#include <WiFi.h>

// Forward declaration
class LittleFSConfig;

class WebServerHandler {
private:
  AsyncWebServer* server;
  LittleFSConfig* config;
  
public:
  WebServerHandler(AsyncWebServer* srv, LittleFSConfig* cfg) : server(srv), config(cfg) {}
  
  void begin();
  void setupRoutes();
  void setupWiFiRoutes();
  void setupSystemRoutes();
  void serveStatic();
  String getContentType(String filename);
  void handleFileRead(AsyncWebServerRequest *request);
};

// Implementation
void WebServerHandler::begin() {
  if (!LittleFS.begin()) {
    Serial.println("LittleFS mount failed! Formatting...");
    LittleFS.format();
    if (!LittleFS.begin()) {
      Serial.println("LittleFS failed to start");
      return;
    }
  }
  Serial.println("LittleFS mounted successfully");
  
  setupRoutes();
  serveStatic();
  
  server->begin();
  Serial.println("Web server started on port 81");
  Serial.println("Access via: http://192.168.4.1:81 (Firebase Auth Compatible ✅)");
}

void WebServerHandler::setupRoutes() {
  setupSystemRoutes();
  setupWiFiRoutes();
  
  // Handle 404 and CORS
  server->onNotFound([this](AsyncWebServerRequest *request) {
    if (request->method() == HTTP_OPTIONS) {
      request->send(200);
    } else {
      handleFileRead(request);
    }
  });
  
  // CORS headers for Firebase compatibility
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Origin", "*");
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

void WebServerHandler::setupSystemRoutes() {
  // System information endpoint
  server->on("/api/system", HTTP_GET, [this](AsyncWebServerRequest *request) {
    StaticJsonDocument<512> doc;
    doc["heap_free"] = ESP.getFreeHeap();
    doc["heap_size"] = ESP.getHeapSize();
    doc["heap_min_free"] = ESP.getMinFreeHeap();
    doc["chip_model"] = ESP.getChipModel();
    doc["chip_cores"] = ESP.getChipCores();
    doc["cpu_freq"] = ESP.getCpuFreqMHz();
    doc["flash_size"] = ESP.getFlashChipSize();
    doc["uptime"] = millis();
    doc["wifi_status"] = (WiFi.status() == WL_CONNECTED);
    doc["free_sketch_space"] = ESP.getFreeSketchSpace();
    
    // LittleFS info
    doc["fs_total"] = config->getTotalSpace();
    doc["fs_used"] = config->getUsedSpace();
    doc["fs_free"] = config->getFreeSpace();
    
    String response;
    serializeJson(doc, response);
    request->send(200, "application/json", response);
  });
  
  // System restart endpoint
  server->on("/api/system/restart", HTTP_POST, [](AsyncWebServerRequest *request) {
    request->send(200, "text/plain", "System restarting...");
    delay(1000);
    ESP.restart();
  });
  
  // Factory reset endpoint (use with caution)
  server->on("/api/system/factory-reset", HTTP_POST, [this](AsyncWebServerRequest *request) {
    // Verify admin credentials or add authentication here
    config->format();
    request->send(200, "text/plain", "Factory reset initiated. System restarting...");
    delay(2000);
    ESP.restart();
  });
}

void WebServerHandler::setupWiFiRoutes() {
  // WiFi status endpoint
  server->on("/api/wifi/status", HTTP_GET, [this](AsyncWebServerRequest *request) {
    StaticJsonDocument<512> doc;
    doc["sta_connected"] = (WiFi.status() == WL_CONNECTED);
    doc["sta_ssid"] = WiFi.SSID();
    doc["sta_ip"] = WiFi.localIP().toString();
    doc["sta_gateway"] = WiFi.gatewayIP().toString();
    doc["sta_dns"] = WiFi.dnsIP().toString();
    doc["sta_rssi"] = WiFi.RSSI();
    doc["sta_channel"] = WiFi.channel();
    
    doc["ap_ssid"] = config->config.ap_ssid;
    doc["ap_ip"] = WiFi.softAPIP().toString();
    doc["ap_clients"] = WiFi.softAPgetStationNum();
    
    doc["connection_status"] = config->getConnectionStatus();
    doc["fail_count"] = config->config.wifi_fail_count;
    doc["last_known_ip"] = config->config.last_known_ip;
    doc["auto_reconnect"] = config->config.auto_reconnect;
    
    String response;
    serializeJson(doc, response);
    request->send(200, "application/json", response);
  });
  
  // WiFi scan endpoint
  server->on("/api/wifi/scan", HTTP_GET, [](AsyncWebServerRequest *request) {
    int scanResult = WiFi.scanNetworks(true); // Async scan
    
    StaticJsonDocument<128> doc;
    if (scanResult == WIFI_SCAN_RUNNING) {
      doc["status"] = "scanning";
      doc["message"] = "WiFi scan in progress";
    } else if (scanResult == WIFI_SCAN_FAILED) {
      doc["status"] = "failed";
      doc["message"] = "WiFi scan failed";
    } else {
      doc["status"] = "started";
      doc["message"] = "WiFi scan started";
    }
    
    String response;
    serializeJson(doc, response);
    request->send(202, "application/json", response);
  });
  
  // WiFi scan results endpoint
  server->on("/api/wifi/networks", HTTP_GET, [](AsyncWebServerRequest *request) {
    int n = WiFi.scanComplete();
    
    if (n == WIFI_SCAN_RUNNING) {
      StaticJsonDocument<128> doc;
      doc["status"] = "scanning";
      doc["message"] = "Scan still in progress";
      String response;
      serializeJson(doc, response);
      request->send(202, "application/json", response);
      return;
    }
    
    if (n == WIFI_SCAN_FAILED) {
      StaticJsonDocument<128> doc;
      doc["status"] = "failed";
      doc["message"] = "WiFi scan failed";
      String response;
      serializeJson(doc, response);
      request->send(500, "application/json", response);
      return;
    }
    
    // Build networks response
    DynamicJsonDocument doc(2048);
    doc["status"] = "complete";
    doc["count"] = n;
    JsonArray networks = doc.createNestedArray("networks");
    
    for (int i = 0; i < n; i++) {
      JsonObject network = networks.createNestedObject();
      network["ssid"] = WiFi.SSID(i);
      network["rssi"] = WiFi.RSSI(i);
      network["channel"] = WiFi.channel(i);
      network["encryption"] = (WiFi.encryptionType(i) == WIFI_AUTH_OPEN) ? "open" : "secured";
      network["bssid"] = WiFi.BSSIDstr(i);
    }
    
    String response;
    serializeJson(doc, response);
    request->send(200, "application/json", response);
    
    WiFi.scanDelete(); // Clean up scan results
  });
  
  // WiFi connect endpoint
  server->on("/api/wifi/connect", HTTP_POST, [this](AsyncWebServerRequest *request) {
    if (!request->hasParam("ssid", true)) {
      request->send(400, "application/json", "{\"error\":\"SSID required\"}");
      return;
    }
    
    String ssid = request->getParam("ssid", true)->value();
    String password = "";
    
    if (request->hasParam("password", true)) {
      password = request->getParam("password", true)->value();
    }
    
    // Validate SSID
    if (ssid.length() == 0 || ssid.length() > 32) {
      request->send(400, "application/json", "{\"error\":\"Invalid SSID length\"}");
      return;
    }
    
    // Update configuration
    if (config->updateWiFiConfig(ssid, password)) {
      StaticJsonDocument<200> doc;
      doc["status"] = "connecting";
      doc["message"] = "WiFi credentials updated, attempting connection";
      doc["ssid"] = ssid;
      
      String response;
      serializeJson(doc, response);
      request->send(200, "application/json", response);
      
      // Trigger reconnection in main loop
      Serial.println("WiFi config updated via API: " + ssid);
      
    } else {
      request->send(500, "application/json", "{\"error\":\"Failed to update configuration\"}");
    }
  });
  
  // WiFi disconnect endpoint
  server->on("/api/wifi/disconnect", HTTP_POST, [this](AsyncWebServerRequest *request) {
    WiFi.disconnect();
    config->incrementFailCount(); // Treat manual disconnect as failure to prevent auto-reconnect
    
    StaticJsonDocument<128> doc;
    doc["status"] = "disconnected";
    doc["message"] = "Disconnected from WiFi network";
    
    String response;
    serializeJson(doc, response);
    request->send(200, "application/json", response);
  });
  
  // WiFi settings endpoint
  server->on("/api/wifi/settings", HTTP_GET, [this](AsyncWebServerRequest *request) {
    StaticJsonDocument<256> doc;
    doc["ssid"] = config->config.wifi_ssid;
    doc["has_password"] = !config->config.wifi_password.isEmpty();
    doc["password_length"] = config->config.wifi_password.length();
    doc["auto_reconnect"] = config->config.auto_reconnect;
    doc["ap_ssid"] = config->config.ap_ssid;
    doc["dhcp_enabled"] = config->config.dhcp_enabled;
    
    String response;
    serializeJson(doc, response);
    request->send(200, "application/json", response);
  });
  
  // Update WiFi settings
  server->on("/api/wifi/settings", HTTP_PUT, [this](AsyncWebServerRequest *request) {
    bool updated = false;
    
    if (request->hasParam("auto_reconnect", true)) {
      config->config.auto_reconnect = (request->getParam("auto_reconnect", true)->value() == "true");
      updated = true;
    }
    
    if (request->hasParam("ap_ssid", true)) {
      config->config.ap_ssid = request->getParam("ap_ssid", true)->value();
      updated = true;
    }
    
    if (request->hasParam("ap_password", true)) {
      config->config.ap_password = request->getParam("ap_password", true)->value();
      updated = true;
    }
    
    if (updated) {
      config->saveConfig();
      request->send(200, "application/json", "{\"message\":\"Settings updated\"}");
    } else {
      request->send(400, "application/json", "{\"error\":\"No valid parameters provided\"}");
    }
  });
  
  // Force WiFi reconnection
  server->on("/api/wifi/reconnect", HTTP_POST, [this](AsyncWebServerRequest *request) {
    config->resetFailCount();
    config->updateLastConnectionAttempt();
    
    request->send(200, "application/json", "{\"message\":\"Reconnection triggered\"}");
    
    // Trigger reconnection
    WiFi.disconnect();
    delay(1000);
    Serial.println("Manual reconnection triggered via API");
  });
}

void WebServerHandler::serveStatic() {
  server->serveStatic("/", LittleFS, "/")
    .setDefaultFile("index.html")
    .setCacheControl("max-age=86400");
    
  server->on("/", HTTP_GET, [this](AsyncWebServerRequest *request) {
    handleFileRead(request);
  });
}

String WebServerHandler::getContentType(String filename) {
  if (filename.endsWith(".html")) return "text/html";
  else if (filename.endsWith(".css")) return "text/css";
  else if (filename.endsWith(".js")) return "application/javascript";
  else if (filename.endsWith(".json")) return "application/json";
  else if (filename.endsWith(".png")) return "image/png";
  else if (filename.endsWith(".jpg")) return "image/jpeg";
  else if (filename.endsWith(".gif")) return "image/gif";
  else if (filename.endsWith(".ico")) return "image/x-icon";
  else if (filename.endsWith(".svg")) return "image/svg+xml";
  else if (filename.endsWith(".xml")) return "text/xml";
  else if (filename.endsWith(".pdf")) return "application/pdf";
  else if (filename.endsWith(".zip")) return "application/zip";
  else if (filename.endsWith(".gz")) return "application/x-gzip";
  return "text/plain";
}

void WebServerHandler::handleFileRead(AsyncWebServerRequest *request) {
  String path = request->url();
  
  if (path.endsWith("/")) {
    path += "index.html";
  }
  
  String pathWithGz = path + ".gz";
  
  if (LittleFS.exists(pathWithGz)) {
    AsyncWebServerResponse *response = request->beginResponse(
      LittleFS, pathWithGz, getContentType(path)
    );
    response->addHeader("Content-Encoding", "gzip");
    request->send(response);
    Serial.println("Served (gzip): " + pathWithGz);
    return;
  }
  
  if (LittleFS.exists(path)) {
    request->send(LittleFS, path, getContentType(path));
    Serial.println("Served: " + path);
    return;
  }
  
  Serial.println("File not found: " + path);
  
  // For SPA, serve index.html for unknown routes
  if (LittleFS.exists("/index.html.gz")) {
    AsyncWebServerResponse *response = request->beginResponse(
      LittleFS, "/index.html.gz", "text/html"
    );
    response->addHeader("Content-Encoding", "gzip");
    request->send(response);
  } else if (LittleFS.exists("/index.html")) {
    request->send(LittleFS, "/index.html", "text/html");
  } else {
    request->send(404, "text/plain", "404: Not Found");
  }
}

#endif // WEBSERVER_HANDLER_H