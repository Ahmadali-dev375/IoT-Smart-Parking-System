import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../../components/new_button.dart';

class UserDetailScreen extends StatefulWidget {
  final String? userId;
  final String? slotId;

  const UserDetailScreen({super.key, this.userId, this.slotId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  String _userName = '';
  String _slotNumber = '';
  String _actualSlotId = '';
  DateTime? _bookedAt;
  int _totalMinutes = 0;
  int _remainingMinutes = 0;
  int _reservedUntil = 0;

  StreamSubscription<DocumentSnapshot>? _slotSubscription;
  Timer? _countdownTimer;
  bool _hasShownExtendDialog = false;

  @override
  void initState() {
    super.initState();
    _fetchBookingData();
  }

  // 🔥 NEW: Detect when widget parameters change
  @override
  void didUpdateWidget(UserDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If slotId or userId changed, refetch data
    if (oldWidget.slotId != widget.slotId ||
        oldWidget.userId != widget.userId) {
      print('🔄 Widget updated, refetching booking data...');
      _resetState();
      _fetchBookingData();
    }
  }

  // 🔥 NEW: Reset all state variables
  void _resetState() {
    _slotSubscription?.cancel();
    _countdownTimer?.cancel();

    setState(() {
      _hasShownExtendDialog = false;
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _userName = '';
      _slotNumber = '';
      _actualSlotId = '';
      _bookedAt = null;
      _totalMinutes = 0;
      _remainingMinutes = 0;
      _reservedUntil = 0;
    });
  }

  @override
  void dispose() {
    _slotSubscription?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBookingData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // ✅ PRINT TO DEBUG
      print('🔍 Fetching booking data...');
      print('🔍 widget.slotId: ${widget.slotId}');
      print('🔍 widget.userId: ${widget.userId}');

      if (widget.slotId != null) {
        print('✅ Using provided slotId: ${widget.slotId}');
        await _fetchSlotData(widget.slotId!);
      } else {
        print('⚠️ No slotId provided, finding active booking...');
        await _findActiveBooking();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching booking: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchSlotData(String slotId) async {
    final slotDoc = await _db.collection('parking_slots').doc(slotId).get();

    if (!slotDoc.exists) {
      throw Exception('Slot not found');
    }

    final data = slotDoc.data() as Map<String, dynamic>;
    final status = data['status'] as String;

    if (status != 'reserved') {
      throw Exception('This slot is not currently reserved');
    }

    _actualSlotId = slotId;
    _parseSlotData(slotId, data);
    _setupRealtimeListener(slotId);
    _startCountdownTimer();
  }

  Future<void> _findActiveBooking() async {
    final slotsSnapshot = await _db.collection('parking_slots').get();

    for (var doc in slotsSnapshot.docs) {
      final data = doc.data();
      if (data['status'] == 'reserved') {
        if (widget.userId != null) {
          if (data['reserved_by'] == widget.userId) {
            _actualSlotId = doc.id;
            print('✅ Found slot for user ${widget.userId}: ${doc.id}');
            _parseSlotData(doc.id, data);
            _setupRealtimeListener(doc.id);
            _startCountdownTimer();
            return;
          }
          continue;
        } else {
          _actualSlotId = doc.id;
          print('✅ Found first reserved slot: ${doc.id}');
          _parseSlotData(doc.id, data);
          _setupRealtimeListener(doc.id);
          _startCountdownTimer();
          return;
        }
      }
    }

    if (widget.userId != null) {
      throw Exception('No active booking found for user: ${widget.userId}');
    } else {
      throw Exception('No active booking found');
    }
  }

  void _parseSlotData(String slotId, Map<String, dynamic> data) {
    final carNumber = data['car_number'];

    _userName = carNumber != null && carNumber.toString().isNotEmpty
        ? carNumber.toString()
        : 'Unknown';
    print('car_number value: ${data['car_number']}');
    print('car_number type: ${data['car_number'].runtimeType}');

    _slotNumber = slotId.replaceAll('slot', '');
    _reservedUntil = data['reserved_until'] as int? ?? 0;

    final now = DateTime.now().millisecondsSinceEpoch;

    if (_reservedUntil > now) {
      _remainingMinutes = ((_reservedUntil - now) / 1000 / 60).ceil();
    } else {
      _remainingMinutes = 0;
    }

    final bookingDuration = data['booking_duration'] as int?;

    if (bookingDuration != null) {
      _totalMinutes = bookingDuration;
      final totalMilliseconds = _totalMinutes * 60 * 1000;
      _bookedAt = DateTime.fromMillisecondsSinceEpoch(
        _reservedUntil - totalMilliseconds,
      );
    } else {
      _totalMinutes = _remainingMinutes;
      _bookedAt = DateTime.now();
    }
  }

  void _setupRealtimeListener(String slotId) {
    _slotSubscription?.cancel();

    _slotSubscription = _db
        .collection('parking_slots')
        .doc(slotId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>;

              if (data['status'] != 'reserved') {
                if (mounted) {
                  context.go('/booking');
                }
                return;
              }

              setState(() {
                _parseSlotData(slotId, data);
              });
            } else {
              if (mounted) {
                context.go('/booking');
              }
            }
          },
          onError: (error) {
            print('❌ Realtime listener error: $error');
          },
        );
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      setState(() {
        if (_reservedUntil > now) {
          _remainingMinutes = ((_reservedUntil - now) / 1000 / 60).ceil();

          if (_reservedUntil - now <= 30000 && !_hasShownExtendDialog) {
            _hasShownExtendDialog = true;
            _showExtendTimeDialog();
          }
        } else {
          _remainingMinutes = 0;

          if (!_hasShownExtendDialog) {
            _hasShownExtendDialog = true;
            _showExtendTimeDialog();
          }
        }
      });
    });
  }

  Map<String, int> _getHoursAndMinutes(int totalMinutes) {
    return {'hours': totalMinutes ~/ 60, 'minutes': totalMinutes % 60};
  }

  void _showExtendTimeDialog() {
    final TextEditingController hoursController = TextEditingController(
      text: '0',
    );
    final TextEditingController minutesController = TextEditingController(
      text: '0',
    );
    final TextEditingController secondsController = TextEditingController(
      text: '0',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.access_time_filled,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Time Expired!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your parking session has ended. Would you like to extend your time?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF757575)),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Time:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Hours',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: hoursController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D47A1),
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Minutes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: minutesController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D47A1),
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Seconds',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: secondsController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D47A1),
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () async {
                // 🔥 FIXED: Now properly ends the parking session
                try {
                  print(
                    '🔴 Ending parking from extend dialog for slot: $_actualSlotId',
                  );

                  await _db
                      .collection('parking_slots')
                      .doc(_actualSlotId)
                      .update({
                        'status': 'available',
                        'reserved_by': '',
                        'reserved_until': 0,
                        'booking_duration': FieldValue.delete(),
                      });

                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Slot $_slotNumber parking ended successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );

                  context.go('/booking');
                } catch (e) {
                  print('❌ Error ending parking: $e');
                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error ending session: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'End Session',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final hours = int.tryParse(hoursController.text) ?? 0;
                final minutes = int.tryParse(minutesController.text) ?? 0;
                final seconds = int.tryParse(secondsController.text) ?? 0;

                final totalMilliseconds =
                    (hours * 3600 * 1000) +
                    (minutes * 60 * 1000) +
                    (seconds * 1000);

                if (totalMilliseconds <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please add at least some time!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  final now = DateTime.now().millisecondsSinceEpoch;
                  final newReservedUntil = now + totalMilliseconds;

                  await _db
                      .collection('parking_slots')
                      .doc(_actualSlotId)
                      .update({'reserved_until': newReservedUntil});

                  _hasShownExtendDialog = false;

                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Time extended by ${hours}h ${minutes}m ${seconds}s',
                      ),
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text(
                'Extend Time',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          centerTitle: true,
          title: const Text('My Parking'),
          // 🔥 NEW: Prevent back navigation
          automaticallyImplyLeading: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          centerTitle: true,
          title: const Text('My Parking'),
          // 🔥 NEW: Prevent back navigation
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'No Active Booking',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/booking'),
                  icon: const Icon(Icons.add),
                  label: const Text('Book a Slot'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final remaining = _getHoursAndMinutes(_remainingMinutes);
    final total = _getHoursAndMinutes(_totalMinutes);

    return PopScope(
      // 🔥 NEW: Prevent back navigation with system back button
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Optionally show a dialog or just do nothing
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Use "End Parking" button to exit'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          centerTitle: true,
          title: const Text('My Parking'),
          // 🔥 NEW: Removed back button
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          child: const Icon(
                            Icons.person,
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Parked by',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 👇 This goes to the far right (empty space)
                        OpenBarrierButton(
                          size: 80,
                          holdDuration: const Duration(seconds: 2),
                          onPressed: () async {
                            try {
                              final databaseRef = FirebaseDatabase.instance
                                  .ref();

                              await databaseRef
                                  .child("barrier")
                                  .child("openRequest")
                                  .set(true);

                              print("✅ Barrier open request sent successfully");

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Barrier opening...'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }

                              await Future.delayed(const Duration(seconds: 5));
                              await databaseRef
                                  .child("barrier")
                                  .child("openRequest")
                                  .set(false);
                              print("🔒 Barrier request reset");
                            } catch (e) {
                              print("❌ Error sending barrier request: $e");
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        //************ */
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Slot No $_slotNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),

                          //
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _InfoCard(
                      icon: Icons.access_time,
                      iconColor: _remainingMinutes < 30
                          ? Colors.red
                          : Colors.orange,
                      title: 'Time Remaining',
                      value: remaining['hours']! > 0
                          ? '${remaining['hours']}h ${remaining['minutes']}min'
                          : '${remaining['minutes']}min',
                      subtitle: total['hours']! > 0
                          ? 'of ${total['hours']}h ${total['minutes']}min booked'
                          : 'of ${total['minutes']}min booked',
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      icon: Icons.schedule,
                      iconColor: Colors.green,
                      title: 'Booked At',
                      value: _formatTime(_bookedAt ?? DateTime.now()),
                      subtitle: _formatDate(_bookedAt ?? DateTime.now()),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Parking Duration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212121),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _totalMinutes > 0
                                  ? (_totalMinutes - _remainingMinutes) /
                                        _totalMinutes
                                  : 0,
                              minHeight: 12,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _remainingMinutes < 30
                                    ? Colors.red
                                    : const Color(0xFF0D47A1),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(_totalMinutes > 0 ? ((_totalMinutes - _remainingMinutes) / _totalMinutes * 100) : 0).toInt()}% Complete',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '${total['hours']} hours ${total['minutes']} min total',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showExtendTimeDialog(),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Extend Time'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        minimumSize: const Size(double.infinity, 56),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showEndParkingDialog(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('End Parking'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size(double.infinity, 56),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _formatDate(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    final isToday =
        dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    if (isToday) {
      return 'Today, ${dateTime.day} ${months[dateTime.month - 1]}';
    } else {
      return '${dateTime.day} ${months[dateTime.month - 1]}, ${dateTime.year}';
    }
  }

  void _showEndParkingDialog(BuildContext context) {
    // ✅ Calculate time spent
    final timeSpentMinutes = _totalMinutes - _remainingMinutes;
    final spentHours = timeSpentMinutes ~/ 60;
    final spentMins = timeSpentMinutes % 60;
    final timeSpentString = spentHours > 0
        ? '${spentHours}h ${spentMins}min'
        : '${spentMins}min';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 12),
              Text('End Parking?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to end your parking session?'),
              const SizedBox(height: 16),

              const SizedBox(height: 10),

              // ✅ NEW: Time spent row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0D47A1).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Color(0xFF0D47A1),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13),
                          children: [
                            const TextSpan(
                              text: 'Time Spent: ',
                              style: TextStyle(color: Color(0xFF757575)),
                            ),
                            TextSpan(
                              text: timeSpentString,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  print('🔴 Ending parking for slot: $_actualSlotId');

                  await _db
                      .collection('parking_slots')
                      .doc(_actualSlotId)
                      .update({
                        'status': 'available',
                        'reserved_by': '',
                        'reserved_until': 0,
                        'booking_duration': FieldValue.delete(),
                      });

                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Slot $_slotNumber parking ended successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );

                  context.go('/booking');
                } catch (e) {
                  print('❌ Error ending parking: $e');
                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('End Session'),
            ),
          ],
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
