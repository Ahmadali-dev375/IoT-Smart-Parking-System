import 'package:cloud_firestore/cloud_firestore.dart';

enum SlotStatus { available, reserved, occupied }

class Slot {
  final String id;
  final int number;
  final SlotStatus status;
  final String reservedBy;
  final int reservedUntil;
  final int? bookingDuration; // ✅ ADDED: booking_duration from Firestore

  // Sensor data from Realtime Database
  final bool sensorStatus; // true = car detected by sensor
  final String realtimeStatus; // status from Realtime DB

  Slot({
    required this.id,
    required this.number,
    required this.status,
    required this.reservedBy,
    required this.reservedUntil,
    this.bookingDuration, // ✅ ADDED: optional, no required
    this.sensorStatus = false,
    this.realtimeStatus = 'available',
  });

  // 🔥 FIXED: Correct logic - ONLY show occupied when BOTH reserved AND sensor true
  SlotStatus get finalStatus {
    print(
      '🔍 finalStatus for $id: firestoreStatus=$status, reserved_until=$reservedUntil, sensor=$sensorStatus',
    );

    final now = DateTime.now().millisecondsSinceEpoch;

    // Priority 1: Check if slot is RESERVED in Firestore
    if (status == SlotStatus.reserved &&
        reservedUntil > 0 &&
        now < reservedUntil) {
      // Valid reservation exists

      // If sensor detects car → OCCUPIED (RED)
      if (sensorStatus == true) {
        print('✅ Slot $id: OCCUPIED (reserved + car present)');
        return SlotStatus.occupied;
      }

      // If no car yet → RESERVED (ORANGE)
      print('✅ Slot $id: RESERVED (waiting for car)');
      return SlotStatus.reserved;
    }

    // Priority 2: Check if reservation expired
    if (status == SlotStatus.reserved &&
        reservedUntil > 0 &&
        now >= reservedUntil) {
      print('⚠️ Slot $id: Reservation EXPIRED');
      // Expired reservation → treat as available
    }

    // Priority 3: If Firestore says occupied (manual override)
    if (status == SlotStatus.occupied) {
      print('✅ Slot $id: OCCUPIED (from Firestore override)');
      return SlotStatus.occupied;
    }

    // Priority 4: If sensor detects car but NO reservation → STILL AVAILABLE
    // (This is an illegal/unauthorized parking)
    if (sensorStatus == true && status == SlotStatus.available) {
      print(
        '⚠️ Slot $id: Car detected but NOT reserved - showing as AVAILABLE (unauthorized parking)',
      );
      return SlotStatus.available;
    }

    // Default: AVAILABLE (GREEN)
    print('✅ Slot $id: AVAILABLE (default)');
    return SlotStatus.available;
  }

  factory Slot.fromFirestore(DocumentSnapshot doc) {
    print('🔍 Raw document ID: ${doc.id}');
    print('🔍 Raw document data: ${doc.data()}');

    final data = doc.data() as Map<String, dynamic>;

    // Extract number from document ID (slot1 → 1, slot2 → 2)
    final number = int.tryParse(doc.id.replaceAll("slot", "")) ?? 0;
    print('✅ Parsed number: $number');

    // SAFE status parsing with fallback
    SlotStatus status;
    final statusStr = (data['status'] ?? 'available').toString().toLowerCase();
    print('✅ Status string: $statusStr');

    switch (statusStr) {
      case 'available':
        status = SlotStatus.available;
        break;
      case 'reserved':
        status = SlotStatus.reserved;
        break;
      case 'occupied':
        status = SlotStatus.occupied;
        break;
      default:
        print('⚠️ Unknown status: $statusStr, defaulting to available');
        status = SlotStatus.available;
    }

    final slot = Slot(
      id: doc.id,
      number: number,
      status: status,
      reservedBy: data['reserved_by']?.toString() ?? "",
      reservedUntil: (data['reserved_until'] is int)
          ? data['reserved_until']
          : 0,
      bookingDuration:
          (data['booking_duration'] is int) // ✅ ADDED
          ? data['booking_duration']
          : null,
      sensorStatus: data['sensor_status'] == true,
      realtimeStatus: data['status']?.toString() ?? 'available',
    );

    print('✅ Created slot: P-${slot.number} (${slot.status})');
    return slot;
  }

  // Copy with updated sensor data
  Slot copyWithSensor({bool? sensorStatus, String? realtimeStatus}) {
    return Slot(
      id: id,
      number: number,
      status: status,
      reservedBy: reservedBy,
      reservedUntil: reservedUntil,
      bookingDuration: bookingDuration, // ✅ ADDED: preserve bookingDuration
      sensorStatus: sensorStatus ?? this.sensorStatus,
      realtimeStatus: realtimeStatus ?? this.realtimeStatus,
    );
  }

  Slot copyWith({
    String? id,
    int? number,
    SlotStatus? status,
    String? reservedBy,
    int? reservedUntil,
    int? bookingDuration, // ✅ ADDED
    bool? sensorStatus,
    String? realtimeStatus,
  }) {
    return Slot(
      id: id ?? this.id,
      number: number ?? this.number,
      status: status ?? this.status,
      reservedBy: reservedBy ?? this.reservedBy,
      reservedUntil: reservedUntil ?? this.reservedUntil,
      bookingDuration: bookingDuration ?? this.bookingDuration, // ✅ ADDED
      sensorStatus: sensorStatus ?? this.sensorStatus,
      realtimeStatus: realtimeStatus ?? this.realtimeStatus,
    );
  }
}
