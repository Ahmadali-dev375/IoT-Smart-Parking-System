import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String anonUserId;
  final String slotId;
  final DateTime time;
  final String status;

  Booking({
    required this.id,
    required this.anonUserId,
    required this.slotId,
    required this.time,
    required this.status,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      anonUserId: data['anonUserId'],
      slotId: data['slotId'],
      time: (data['time'] as Timestamp).toDate(),
      status: data['status'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'anonUserId': anonUserId,
      'slotId': slotId,
      'time': Timestamp.fromDate(time),
      'status': status,
    };
  }
}
