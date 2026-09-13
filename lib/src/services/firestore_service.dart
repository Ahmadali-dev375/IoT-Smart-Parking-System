import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking.dart';
import '../models/slot.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Slot>> getSlots() {
    print('🚀 Starting to fetch slots from Firestore...');

    return _db
        .collection('parking_slots')
        .snapshots()
        .map((snapshot) {
          print('📊 Snapshot received!');
          print('📊 Number of documents: ${snapshot.docs.length}');
          print('📊 Documents: ${snapshot.docs.map((d) => d.id).toList()}');

          if (snapshot.docs.isEmpty) {
            print('⚠️ No documents found in parking_slots collection!');
            return <Slot>[];
          }

          try {
            final slots = snapshot.docs.map((doc) {
              print('---');
              print('Processing document: ${doc.id}');
              return Slot.fromFirestore(doc);
            }).toList();

            print('✅ Successfully parsed ${slots.length} slots');
            print('✅ Slot numbers: ${slots.map((s) => s.number).toList()}');
            return slots;
          } catch (e, stackTrace) {
            print('❌ Error parsing slots: $e');
            print('❌ Stack trace: $stackTrace');
            return <Slot>[];
          }
        })
        .handleError((error) {
          print('❌ Stream error: $error');
          return <Slot>[];
        });
  }

  Stream<Booking?> getUserBooking(String userId) {
    print('🔍 Fetching booking for user: $userId');

    return _db
        .collection('bookings')
        .where('anonUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .map((snapshot) {
          print('📊 Booking snapshot: ${snapshot.docs.length} documents');
          if (snapshot.docs.isEmpty) {
            print('✅ No active booking found');
            return null;
          }
          print('✅ Active booking found');
          return Booking.fromFirestore(snapshot.docs.first);
        });
  }

  Future<void> bookSlot(String slotId, String userId) async {
    final slotRef = _db.collection('parking_slots').doc(slotId);
    final bookingRef = _db.collection('bookings').doc();

    await _db.runTransaction((transaction) async {
      final slotSnapshot = await transaction.get(slotRef);
      if (!slotSnapshot.exists) {
        throw Exception("Slot does not exist!");
      }

      final slot = Slot.fromFirestore(slotSnapshot);
      if (slot.status != SlotStatus.available) {
        throw Exception("Slot is not available for booking!");
      }

      transaction.update(slotRef, {
        'status': 'reserved',
        'reserved_by': userId,
        'reserved_until':
            DateTime.now().millisecondsSinceEpoch + (30 * 60 * 1000),
      });

      transaction.set(
        bookingRef,
        Booking(
          id: bookingRef.id,
          anonUserId: userId,
          slotId: slotId,
          time: DateTime.now(),
          status: 'active',
        ).toFirestore(),
      );
    });
  }

  Future<void> cancelBooking(String bookingId, String slotId) async {
    final bookingRef = _db.collection('bookings').doc(bookingId);
    final slotRef = _db.collection('parking_slots').doc(slotId);

    await _db.runTransaction((transaction) async {
      transaction.update(bookingRef, {'status': 'cancelled'});
      transaction.update(slotRef, {
        'status': 'available',
        'reserved_by': '',
        'reserved_until': 0,
      });
    });
  }

  Future<void> updateSlotStatus(String slotId, SlotStatus newStatus) async {
    await _db.collection('parking_slots').doc(slotId).update({
      'status': newStatus.name,
      'reserved_by': '',
      'reserved_until': 0,
    });
  }

  // Add this method to your FirestoreService class

  Future<void> checkAndUpdateExpiredSlots() async {
    print('⏰ Checking for expired reservations...');

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Get all reserved slots
      final reservedSlots = await _db
          .collection('parking_slots')
          .where('status', isEqualTo: 'reserved')
          .get();

      print('Found ${reservedSlots.docs.length} reserved slots');

      // Check each one
      for (var doc in reservedSlots.docs) {
        final data = doc.data();
        final reservedUntil = data['reserved_until'] as int;

        // If the reservation has expired
        if (reservedUntil <= now) {
          print('⏰ Slot ${doc.id} reservation expired! Releasing...');

          // Update to available
          await doc.reference.update({
            'status': 'available',
            'reserved_by': '',
            'reserved_until': 0,
          });

          print('✅ Slot ${doc.id} is now available');
        }
      }
    } catch (e) {
      print('❌ Error checking expired slots: $e');
    }
  }
}
