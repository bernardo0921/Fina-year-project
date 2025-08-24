#include <WiFiS3.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* ssid = "ZTE_Van Bommel _2.4G";
const char* password = "KennethVanBommel$$11";

// A WiFiServer listens for incoming clients on a specified port
WiFiServer server(80);

// Pin definitions
const int ACID_VALVE_PIN = 2;        // Bulb for Acid Valve
const int BASE_VALVE_PIN = 3;        // Bulb for Base Valve
const int TREATMENT_CONTAINER_PIN = 4; // Bulb for Treatment Container
const int INTAKE_CONTAINER_PIN = 5;  // Bulb for Intake Container
const int STATUS_LED_PIN = 6;        // Optional: System status LED

// pH constants
const float PH_MIN_SAFE = 6.5;
const float PH_MAX_SAFE = 8.5;
const float PH_ADJUSTMENT_RATE = 0.1; // pH units per treatment cycle
const int TREATMENT_DELAY = 2000;     // 2 seconds between adjustments
const int INTAKE_DURATION = 3000;     // 3 seconds for water intake simulation
const int POST_TREATMENT_DURATION = 5000; // 5 seconds for post-treatment blinking
const int BASE_VALVE_DELAY = 5000;    // 5 second delay before base valve opens

// Safety limits
const float PH_CRITICAL_LOW = 0.0;
const float PH_CRITICAL_HIGH = 14.0;
const int MAX_TREATMENT_CYCLES = 50; // Prevent infinite treatment loops

// Global state variables
float currentPH = 7.0;
float initialPH = 7.0; // Store initial pH for logging
bool systemEnabled = true;
bool emergencyStop = false;
int treatmentCycles = 0;

enum SystemState { 
  IDLE, 
  INTAKE, 
  TREATING, 
  POST_TREATMENT, 
  MANUAL_ACID, 
  MANUAL_BASE, 
  EMERGENCY_STOP,
  DISCHARGE
};

SystemState systemState = IDLE;
unsigned long baseValveDelayStart = 0; // Timer for the base valve delay
unsigned long stateStartTime = 0; // Track when current state started

// Timing variables for non-blocking operations
unsigned long lastUpdate = 0;
unsigned long lastBlink = 0;
const int BLINK_INTERVAL = 500; // 500ms blink speed
bool lightState = HIGH; // Initial state for reverse logic (HIGH = OFF)

// Statistics tracking
struct TreatmentStats {
  int totalTreatments = 0;
  int acidTreatments = 0;
  int baseTreatments = 0;
  float avgTreatmentTime = 0;
  unsigned long lastTreatmentTime = 0;
};
TreatmentStats stats;

void setup() {
  Serial.begin(115200);

  // Initialize pins
  pinMode(ACID_VALVE_PIN, OUTPUT);
  pinMode(BASE_VALVE_PIN, OUTPUT);
  pinMode(TREATMENT_CONTAINER_PIN, OUTPUT);
  pinMode(INTAKE_CONTAINER_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);

  // Turn off all outputs initially (HIGH for reverse logic)
  turnOffAllLights();

  // Connect to WiFi and start the server
  connectToWiFi();
  server.begin();

  Serial.println("Enhanced pH Treatment System Ready");
  Serial.println("Safety Features: Emergency stop, treatment cycle limits, critical pH detection");
  Serial.println("Waiting for a client to connect and send pH data...");
}

void loop() {
  // Listen for incoming clients
  WiFiClient client = server.available();
  if (client) {
    handleClient(client);
  }

  // Handle emergency stop
  if (emergencyStop) {
    handleEmergencyStop();
    return;
  }

  // Handle blinking based on the current state
  if (millis() - lastBlink >= BLINK_INTERVAL) {
    lightState = !lightState;
    lastBlink = millis();
    updateBulbs();
  }

  // Handle state-based actions
  if (systemEnabled) {
    switch (systemState) {
      case INTAKE:
        handleIntake();
        break;
      case TREATING:
        handleTreatment();
        break;
      case POST_TREATMENT:
        handlePostTreatment();
        break;
      case DISCHARGE:
        handleDischarge();
        break;
      case MANUAL_ACID:
        handleManualAcid();
        break;
      case MANUAL_BASE:
        handleManualBase();
        break;
      default:
        // Do nothing in IDLE or other states
        break;
    }
  }

  // Update status LED
  updateStatusLED();
}

void connectToWiFi() {
  if (WiFi.status() == WL_NO_MODULE) {
    Serial.println("Communication with WiFi module failed!");
    while (true);
  }
  Serial.print("Attempting to connect to WPA SSID: ");
  Serial.println(ssid);
  while (WiFi.status() != WL_CONNECTED) {
    WiFi.begin(ssid, password);
    Serial.print(".");
    delay(5000);
  }
  Serial.println();
  Serial.println("WiFi connected!");
  Serial.print("Arduino IP address: ");
  Serial.println(WiFi.localIP());
}

void handleClient(WiFiClient client) {
  Serial.println("New client connected!");
  String currentLine = "";
  String requestBody = "";
  bool readingBody = false;
  String method = "";
  String uri = "";
  unsigned long timeout = millis() + 60000;
  
  while (client.connected() && millis() < timeout) {
    if (client.available()) {
      char c = client.read();
      Serial.write(c);
      if (c == '\n') {
        if (currentLine.length() == 0) {
          readingBody = true;
        } else {
          if (method.length() == 0) {
            int firstSpace = currentLine.indexOf(' ');
            int secondSpace = currentLine.indexOf(' ', firstSpace + 1);
            if (firstSpace != -1 && secondSpace != -1) {
              method = currentLine.substring(0, firstSpace);
              uri = currentLine.substring(firstSpace + 1, secondSpace);
            }
          }
        }
        currentLine = "";
      } else if (c != '\r') {
        currentLine += c;
        if (readingBody) {
          requestBody += c;
        }
      }
    }
    if (method.length() > 0 && client.available() == 0) {
      timeout = millis() + 60000;
      if (method.equals("POST") && uri.equals("/setph")) {
        Serial.println("Received POST /setph request");
        processPHRequest(requestBody, client);
      } else if (method.equals("GET") && uri.equals("/status")) {
        Serial.println("Received GET /status request");
        handleGetStatusRequest(client);
      } else if (method.equals("POST") && uri.equals("/command")) {
        Serial.println("Received POST /command request");
        processCommandRequest(requestBody, client);
      } else if (method.equals("GET") && uri.equals("/stats")) {
        Serial.println("Received GET /stats request");
        handleGetStatsRequest(client);
      } else {
        sendErrorResponse(client, "Unsupported method or URI");
      }
      method = "";
      uri = "";
      requestBody = "";
      readingBody = false;
    }
  }
  if (client.connected()) {
    client.stop();
  }
  Serial.println("Client disconnected.");
}

void processPHRequest(String payload, WiFiClient client) {
  DynamicJsonDocument doc(256);
  DeserializationError error = deserializeJson(doc, payload);
  if (error) {
    Serial.println("Failed to parse JSON!");
    sendErrorResponse(client, "Failed to parse JSON");
    return;
  }
  if (!doc.containsKey("ph_value")) {
    Serial.println("JSON payload is missing 'ph_value'");
    sendErrorResponse(client, "JSON payload is missing 'ph_value'");
    return;
  }
  if (!systemEnabled || emergencyStop) {
    sendErrorResponse(client, "System is currently stopped or in emergency mode. Please start it first.");
    return;
  }
  
  float newPH = doc["ph_value"];
  
  // Safety check for critical pH values
  if (newPH < PH_CRITICAL_LOW || newPH > PH_CRITICAL_HIGH) {
    emergencyStop = true;
    String errorMsg = "CRITICAL pH DETECTED (" + String(newPH) + "). Emergency stop activated!";
    Serial.println(errorMsg);
    sendErrorResponse(client, errorMsg);
    return;
  }
  
  currentPH = newPH;
  initialPH = newPH;
  treatmentCycles = 0;
  
  Serial.println("Received new pH: " + String(currentPH));
  
  if (currentPH >= PH_MIN_SAFE && currentPH <= PH_MAX_SAFE) {
    sendOkResponse(client, "pH is already within safe range.", currentPH, true);
    turnOffAllLights();
    systemState = IDLE;
  } else {
    startIntakeProcess();
    sendOkResponse(client, "Intake process started.", currentPH, false);
  }
}

void processCommandRequest(String payload, WiFiClient client) {
  DynamicJsonDocument doc(256);
  DeserializationError error = deserializeJson(doc, payload);
  if (error) {
    Serial.println("Failed to parse JSON!");
    sendErrorResponse(client, "Failed to parse JSON");
    return;
  }
  if (!doc.containsKey("command")) {
    Serial.println("JSON payload is missing 'command'");
    sendErrorResponse(client, "JSON payload is missing 'command'");
    return;
  }
  
  String command = doc["command"];
  String statusMessage = "";

  if (command == "stop") {
    systemEnabled = false;
    turnOffAllLights();
    systemState = IDLE;
    statusMessage = "Stopped";
    Serial.println("System stopped by remote command.");
  } else if (command == "start") {
    systemEnabled = true;
    emergencyStop = false;
    systemState = IDLE;
    statusMessage = "Running";
    turnOffAllLights();
    Serial.println("System started by remote command.");
  } else if (command == "emergency_stop") {
    emergencyStop = true;
    statusMessage = "Emergency Stop";
    Serial.println("EMERGENCY STOP activated by remote command!");
  } else if (command == "reset_stats") {
    resetStats();
    statusMessage = "Stats Reset";
    Serial.println("Statistics reset by remote command.");
  } else if (command == "add_acid" && systemEnabled && !emergencyStop) {
    Serial.println("Manual command: Add Acid");
    turnOffAllLights();
    systemState = MANUAL_ACID;
    stateStartTime = millis();
    lastUpdate = millis();
    statusMessage = "Manual Acid";
  } else if (command == "add_base" && systemEnabled && !emergencyStop) {
    Serial.println("Manual command: Add Base");
    turnOffAllLights();
    systemState = MANUAL_BASE;
    stateStartTime = millis();
    lastUpdate = millis();
    statusMessage = "Manual Base";
  } else if (command == "stop_manual" && systemEnabled && !emergencyStop) {
    Serial.println("Manual command: Stop Manual Mode");
    turnOffAllLights();
    systemState = IDLE;
    statusMessage = "Idle";
  } else {
    sendErrorResponse(client, "Invalid command received or system is not operational.");
    return;
  }

  String response = "{\"status\":\"success\", \"message\":\"Command '" + command + "' received.\", \"system_status\":\"" + statusMessage + "\"}";
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: application/json");
  client.print("Content-Length: ");
  client.println(response.length());
  client.println("Connection: close");
  client.println();
  client.print(response);
}

void handleGetStatusRequest(WiFiClient client) {
  String statusText;
  switch(systemState) {
    case IDLE:
      statusText = emergencyStop ? "Emergency Stop" : "Idle";
      break;
    case INTAKE:
      statusText = "Intake";
      break;
    case TREATING:
      statusText = "Treating";
      break;
    case POST_TREATMENT:
      statusText = "Post-Treatment";
      break;
    case DISCHARGE:
      statusText = "Discharge";
      break;
    case MANUAL_ACID:
      statusText = "Manual Acid";
      break;
    case MANUAL_BASE:
      statusText = "Manual Base";
      break;
    case EMERGENCY_STOP:
      statusText = "Emergency Stop";
      break;
  }
  
  String response = "{\"ph\":" + String(currentPH, 2) + 
                    ", \"status\":\"" + statusText + 
                    "\", \"enabled\":" + (systemEnabled ? "true" : "false") +
                    ", \"emergency\":" + (emergencyStop ? "true" : "false") +
                    ", \"treatment_cycles\":" + String(treatmentCycles) + "}";
  
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: application/json");
  client.print("Content-Length: ");
  client.println(response.length());
  client.println("Connection: close");
  client.println();
  client.print(response);
}

void handleGetStatsRequest(WiFiClient client) {
  String response = "{\"total_treatments\":" + String(stats.totalTreatments) +
                    ", \"acid_treatments\":" + String(stats.acidTreatments) +
                    ", \"base_treatments\":" + String(stats.baseTreatments) +
                    ", \"avg_treatment_time\":" + String(stats.avgTreatmentTime, 2) +
                    ", \"last_treatment_time\":" + String(stats.lastTreatmentTime) + "}";
  
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: application/json");
  client.print("Content-Length: ");
  client.println(response.length());
  client.println("Connection: close");
  client.println();
  client.print(response);
}

void sendOkResponse(WiFiClient client, String message, float ph, bool safe) {
  String statusText = safe ? "safe" : "treating";
  String response = "{\"status\":\"success\", \"message\":\"" + message +
                    "\", \"updated_ph\":" + String(ph, 2) +
                    ", \"ph_status\":\"" + statusText + "\"}";
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: application/json");
  client.print("Content-Length: ");
  client.println(response.length());
  client.println("Connection: close");
  client.println();
  client.print(response);
}

void sendErrorResponse(WiFiClient client, String errorMessage) {
  client.println("HTTP/1.1 400 Bad Request");
  client.println("Content-Type: application/json");
  client.println("Connection: close");
  client.println();
  client.println("{\"status\":\"error\", \"message\":\"" + errorMessage + "\"}");
}

void startIntakeProcess() {
  Serial.println("Starting intake process...");
  turnOffAllLights();
  systemState = INTAKE;
  stateStartTime = millis();
  lastUpdate = millis();
}

void handleIntake() {
  if (millis() - lastUpdate >= INTAKE_DURATION) {
    Serial.println("Intake complete. Starting pH check...");
    processPH();
  }
}

void processPH() {
  if (!systemEnabled || emergencyStop) {
    Serial.println("System is stopped or in emergency mode, not processing pH.");
    return;
  }
  
  Serial.println("Processing pH: " + String(currentPH));
  turnOffAllLights();
  
  if (currentPH >= PH_MIN_SAFE && currentPH <= PH_MAX_SAFE) {
    Serial.println("pH is within safe range. No treatment needed.");
    systemState = DISCHARGE; // Go to discharge instead of idle
    stateStartTime = millis();
  } else {
    Serial.println("pH is outside safe range - starting treatment");
    digitalWrite(TREATMENT_CONTAINER_PIN, LOW); // Turn on treatment bulb
    systemState = TREATING;
    stateStartTime = millis();
    lastUpdate = millis();
    baseValveDelayStart = 0;
  }
}

void handleTreatment() {
  // Safety check: prevent infinite treatment loops
  if (treatmentCycles >= MAX_TREATMENT_CYCLES) {
    Serial.println("Maximum treatment cycles reached. Stopping treatment.");
    emergencyStop = true;
    return;
  }
  
  // If pH is too low, handle base valve delay
  if (currentPH < PH_MIN_SAFE) {
    if (baseValveDelayStart == 0) {
      baseValveDelayStart = millis();
      Serial.println("Detected acidic pH. Waiting before adding base...");
    }

    if (millis() - baseValveDelayStart >= BASE_VALVE_DELAY) {
      // Delay passed, start adjusting pH
      if (millis() - lastUpdate >= TREATMENT_DELAY) {
        currentPH += PH_ADJUSTMENT_RATE;
        treatmentCycles++;
        Serial.println("Adding base - New pH: " + String(currentPH) + " (Cycle: " + String(treatmentCycles) + ")");
        lastUpdate = millis();
      }
    }
  } else if (currentPH > PH_MAX_SAFE) {
    // If pH is too high, start adjusting pH immediately
    if (millis() - lastUpdate >= TREATMENT_DELAY) {
      currentPH -= PH_ADJUSTMENT_RATE;
      treatmentCycles++;
      Serial.println("Adding acid - New pH: " + String(currentPH) + " (Cycle: " + String(treatmentCycles) + ")");
      lastUpdate = millis();
    }
  }
  
  // Check for treatment completion after each adjustment
  if (currentPH >= PH_MIN_SAFE && currentPH <= PH_MAX_SAFE) {
    Serial.println("Treatment successful - pH now in safe range");
    updateTreatmentStats();
    turnOffAllLights();
    systemState = POST_TREATMENT;
    stateStartTime = millis();
    lastUpdate = millis();
    Serial.println("Starting post-treatment mixing...");
  }
}

void handlePostTreatment() {
  if (millis() - lastUpdate >= POST_TREATMENT_DURATION) {
    Serial.println("Post-treatment mixing complete. Starting discharge...");
    systemState = DISCHARGE;
    stateStartTime = millis();
  }
}

void handleDischarge() {
  // Simulate discharge process with blinking treatment container
  if (millis() - stateStartTime >= POST_TREATMENT_DURATION) {
    Serial.println("Discharge complete. System ready for next batch.");
    turnOffAllLights();
    systemState = IDLE;
  }
}

void handleEmergencyStop() {
  turnOffAllLights();
  systemState = EMERGENCY_STOP;
  systemEnabled = false;
  
  // Flash all lights rapidly to indicate emergency
  static unsigned long lastEmergencyBlink = 0;
  if (millis() - lastEmergencyBlink >= 200) {
    static bool emergencyLightState = false;
    emergencyLightState = !emergencyLightState;
    
    digitalWrite(ACID_VALVE_PIN, emergencyLightState ? LOW : HIGH);
    digitalWrite(BASE_VALVE_PIN, emergencyLightState ? LOW : HIGH);
    digitalWrite(TREATMENT_CONTAINER_PIN, emergencyLightState ? LOW : HIGH);
    digitalWrite(INTAKE_CONTAINER_PIN, emergencyLightState ? LOW : HIGH);
    
    lastEmergencyBlink = millis();
  }
}

void updateBulbs() {
  if (emergencyStop) return; // Emergency stop handles its own lighting
  
  // Turn off all bulbs before setting the new state
  turnOffAllLights();
  
  // Set the bulbs based on the current system state
  switch (systemState) {
    case INTAKE:
      digitalWrite(INTAKE_CONTAINER_PIN, lightState);
      break;
    case TREATING:
      digitalWrite(TREATMENT_CONTAINER_PIN, LOW); // Solid ON
      if (currentPH < PH_MIN_SAFE && (baseValveDelayStart > 0 && millis() - baseValveDelayStart >= BASE_VALVE_DELAY)) {
        digitalWrite(BASE_VALVE_PIN, lightState);
      } else if (currentPH > PH_MAX_SAFE) {
        digitalWrite(ACID_VALVE_PIN, lightState);
      }
      break;
    case POST_TREATMENT:
      digitalWrite(TREATMENT_CONTAINER_PIN, lightState);
      break;
    case DISCHARGE:
      digitalWrite(TREATMENT_CONTAINER_PIN, lightState);
      break;
    case MANUAL_ACID:
      digitalWrite(ACID_VALVE_PIN, lightState);
      break;
    case MANUAL_BASE:
      digitalWrite(BASE_VALVE_PIN, lightState);
      break;
    default:
      // All lights are off in IDLE state
      break;
  }
}

void updateStatusLED() {
  static unsigned long lastStatusUpdate = 0;
  static bool statusLedState = false;
  
  if (millis() - lastStatusUpdate >= 1000) { // Update every second
    if (emergencyStop) {
      statusLedState = !statusLedState; // Fast blink for emergency
    } else if (systemEnabled) {
      statusLedState = true; // Solid on when running
    } else {
      statusLedState = false; // Off when stopped
    }
    
    digitalWrite(STATUS_LED_PIN, statusLedState ? LOW : HIGH);
    lastStatusUpdate = millis();
  }
}

void updateTreatmentStats() {
  stats.totalTreatments++;
  stats.lastTreatmentTime = millis() - stateStartTime;
  
  if (initialPH < PH_MIN_SAFE) {
    stats.baseTreatments++;
  } else {
    stats.acidTreatments++;
  }
  
  // Update average treatment time
  stats.avgTreatmentTime = (stats.avgTreatmentTime * (stats.totalTreatments - 1) + stats.lastTreatmentTime) / stats.totalTreatments;
  
  Serial.println("Treatment Stats Updated:");
  Serial.println("  Total: " + String(stats.totalTreatments));
  Serial.println("  Last Duration: " + String(stats.lastTreatmentTime) + "ms");
  Serial.println("  Average Duration: " + String(stats.avgTreatmentTime, 2) + "ms");
}

void resetStats() {
  stats.totalTreatments = 0;
  stats.acidTreatments = 0;
  stats.baseTreatments = 0;
  stats.avgTreatmentTime = 0;
  stats.lastTreatmentTime = 0;
}

void turnOffAllLights() {
  digitalWrite(ACID_VALVE_PIN, HIGH);
  digitalWrite(BASE_VALVE_PIN, HIGH);
  digitalWrite(TREATMENT_CONTAINER_PIN, HIGH);
  digitalWrite(INTAKE_CONTAINER_PIN, HIGH);
}

void handleManualAcid() {
  // Continuously add acid while in manual acid mode
  if (millis() - lastUpdate >= TREATMENT_DELAY) {
    float oldPH = currentPH;
    currentPH -= PH_ADJUSTMENT_RATE;
    
    // Prevent pH from going too low
    if (currentPH < PH_CRITICAL_LOW) {
      currentPH = PH_CRITICAL_LOW;
      Serial.println("WARNING: pH reached critical low limit!");
    }
    
    Serial.println("Manual Acid Addition - pH: " + String(oldPH, 2) + " -> " + String(currentPH, 2));
    lastUpdate = millis();
    
    // Optional: Auto-stop if pH gets too low for safety
    if (currentPH <= PH_CRITICAL_LOW) {
      Serial.println("Auto-stopping manual acid addition due to critical pH level");
      systemState = IDLE;
      turnOffAllLights();
    }
  }
}

void handleManualBase() {
  // Continuously add base while in manual base mode
  if (millis() - lastUpdate >= TREATMENT_DELAY) {
    float oldPH = currentPH;
    currentPH += PH_ADJUSTMENT_RATE;
    
    // Prevent pH from going too high
    if (currentPH > PH_CRITICAL_HIGH) {
      currentPH = PH_CRITICAL_HIGH;
      Serial.println("WARNING: pH reached critical high limit!");
    }
    
    Serial.println("Manual Base Addition - pH: " + String(oldPH, 2) + " -> " + String(currentPH, 2));
    lastUpdate = millis();
    
    // Optional: Auto-stop if pH gets too high for safety
    if (currentPH >= PH_CRITICAL_HIGH) {
      Serial.println("Auto-stopping manual base addition due to critical pH level");
      systemState = IDLE;
      turnOffAllLights();
    }
  }
}