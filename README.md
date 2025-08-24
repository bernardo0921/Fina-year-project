💧 Water pH Treatment System 🔬
This project is an automated water treatment system that uses an Arduino microcontroller to monitor and adjust the pH of a water source. It also features a sleek mobile dashboard built with Flutter that allows for real-time monitoring and remote control of the system. 📱

The project consists of two main parts:

Arduino-based Water Treater: This smart device reads pH levels and automatically adds an acidic or basic solution to bring the water's pH within a safe, predefined range. It includes built-in safety features like an emergency stop and treatment cycle limits to prevent over-treatment. The device also hosts a web server to communicate with your phone.

Flutter-based Dashboard: This mobile app provides a beautiful and user-friendly interface to monitor the system's status, view real-time pH data, and control the treatment process from anywhere. You can either set a target pH for automated treatment or manually control the addition of acid or base.

✨ Key Features
Automated pH Correction: The system automatically detects if the water is too acidic or too basic and adds the appropriate solution to neutralize it.

Real-time Monitoring: The mobile app displays the current pH level and system status in real time.

Remote Control: The dashboard allows you to start, stop, or reset the system with just a tap.

Manual Override: You can switch to a manual mode to directly command the system to add acid or base.

Safety First!: The Arduino code includes an emergency stop feature that activates if the pH reaches a critical level, preventing potential damage or hazardous conditions.

Data Visualization: The mobile app includes a graph that tracks the pH trend over time, giving you a historical view of the water's quality.

📦 Components
1. Arduino Code (water_treater.ino)
This is the core logic that runs on the Arduino device.

WiFi Connectivity: It uses the WiFiS3 library to connect to a local WiFi network and establish communication.

Web Server: A WiFiServer is set up to listen for incoming requests on port 80.

Pin Definitions: It defines the digital pins for controlling the various components, including the valves for acid (ACID_VALVE_PIN) and base (BASE_VALVE_PIN), and bulbs for the intake, treatment, and status LEDs.

State Management: The system operates using a SystemState enum to manage its different modes, such as IDLE, INTAKE, TREATING, POST_TREATMENT, MANUAL_ACID, and EMERGENCY_STOP.

JSON API Endpoints: It handles various API requests from the mobile app to perform actions such as /setph, /status, and /command.

2. Flutter Dashboard (dashboard_screen.dart)
This is the mobile application that serves as the user interface.

API Communication: It uses the http package to send and receive data from the Arduino's web server.

State Management: The app uses a StatefulWidget to manage the UI state, including the currentPH value, systemStatus, and phHistory.

Animations: It incorporates subtle animations, such as a pulsing status badge, to provide visual feedback to the user.

User Interface: The UI is built with a clean, modern design featuring "glassmorphic" cards to display information clearly. It includes:

pH Level Monitor: A section to show the current pH value and its status (Acidic, Basic, or Neutral).

Control Panel: A card with a toggle switch to switch between automatic and manual modes, and buttons for sending commands to the Arduino.

pH Trend Analysis: A graph to visualize the pH changes over time.

🛠 How to Use
Hardware Setup:

Connect the Arduino to the pH sensor, valves, and bulbs according to the pin definitions in the water_treater.ino file.

Make sure the Arduino is connected to the same WiFi network as your mobile device.

Arduino Configuration:

Open water_treater.ino in the Arduino IDE.

Update the ssid and password variables with your local WiFi credentials.

Upload the code to your Arduino board.

Note the IP address that the Arduino prints to the Serial Monitor after connecting to the network.

Flutter App Configuration:

Open the dashboard_screen.dart file in a Flutter IDE.

Replace the arduinoIpAddress constant with the IP address you noted from the Arduino's Serial Monitor.

Run the Flutter app on your mobile device or an emulator.

The system is now ready to use! You can start a new treatment cycle by entering a pH value in the app or control the valves manually. 🧪
