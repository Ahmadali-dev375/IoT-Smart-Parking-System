# 🚗 IoT Smart Parking System

> A Flutter + Firebase IoT parking solution that combines mobile reservations with real-time ESP32 sensor data.

**University Team Project · My Role: Software Developer**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Cloud Firestore](https://img.shields.io/badge/Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com/docs/firestore)
[![Realtime Database](https://img.shields.io/badge/Realtime_DB-FFA000?style=for-the-badge&logo=firebase&logoColor=white)](https://firebase.google.com/docs/database)
[![ESP32](https://img.shields.io/badge/ESP32-E7352C?style=for-the-badge&logo=espressif&logoColor=white)](https://www.espressif.com)
[![IoT](https://img.shields.io/badge/IoT-Sensors_&_Servo-blue?style=for-the-badge)](https://en.wikipedia.org/wiki/Internet_of_things)

---
## 📱 Project Preview

<p align="center">
  <img src="media/screenshots/splash.png" width="22%" alt="SmartPark Splash" />
  &nbsp;
  <img src="media/screenshots/slots.png" width="22%" alt="Select Parking Slot" />
  &nbsp;
  <img src="media/screenshots/booking.png" width="22%" alt="Book Parking Slot" />
  &nbsp;
  <img src="media/screenshots/my-parking.png" width="22%" alt="My Parking" />
</p>

---

## ℹ️ About the Project

Developed as a university team DLD project, this smart parking system bridges a mobile user interface with a physical IoT parking model. The Flutter application allows drivers to discover available spaces, book designated parking spots with custom durations, monitor active parking sessions with live countdowns, and remotely actuate an entry barrier servo gate.

---

## ✨ Key Features

- **Live Multi-State Slots**: Real-time visualization of slots categorized as **Available** (Green), **Reserved** (Orange), or **Occupied** (Red).
- **Flexible Duration Booking**: Interactive slider supporting reservations in seconds (demo/testing), minutes, or hours.
- **Hybrid State Engine**: Cloud reservation records with physical IR sensor readings to detect arrivals and unauthorized parking.
- **Hardware Barrier Control**: Animated 2-second press-and-hold button in Flutter that sends an actuation signal to the ESP32 via RTDB.
- **Time Extension & Expiry Sweeps**: In-app parking time extension and automatic cleanup sweeps for expired reservations.
- **Failsafe Telemetry**: Realtime Database stream listener with an automated 3-second polling fallback in case of connection interruptions.

---

## 🗄️ Firebase + IoT Architecture

### Cloud Firestore
Serves as the persistent store for user reservations and session metadata:
- `parking_slots/{slotId}`: stores `status`, `user_id`, `car_number`, `booking_duration`, and `reserved_until` (epoch timestamp).

### Firebase Realtime Database
Optimized for low-latency hardware telemetry and barrier commands:

```text
iot_parking/
├── slot1/
│   ├── sensor_status: bool   # true = car present, false = empty
│   └── status: string        # "available" / "occupied"
├── slot2/
├── slot3/
└── slot4/

barrier/
└── openRequest: bool         # true = open requested by app; false = idle
```

---

## 👥 Team & Contributions

This project was developed as a collaborative university team effort:

- **Software Developer (My Role)**:
  - Architected the Flutter mobile application (UI/UX, GoRouter, Provider state management).
  - Implemented the dual-database integration (Cloud Firestore + Firebase Realtime Database).
- **Hardware & Embedded Teammates**:
  - Constructed the physical scale-model parking layout and barrier gate.
  - Wired the ESP32 microcontroller, IR proximity sensors, and SG90 servo motor.
  - Implemented the embedded firmware logic for sensor reading and barrier actuation.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.9+)
- A Firebase project with Cloud Firestore and Realtime Database enabled

### Configuration
1. Clone the repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/iot-smart-parking.git
   cd iot-smart-parking
   ```
2. Set up Firebase configuration files:
   - Copy `lib/firebase_options.dart.example` to `lib/firebase_options.dart` and fill in your Firebase credentials (or run `flutterfire configure`).
   - Copy `android/app/google-services.json.example` to `android/app/google-services.json` with your Android app config.
3. Install dependencies and run:
   ```bash
   flutter pub get
   flutter run
   ```
