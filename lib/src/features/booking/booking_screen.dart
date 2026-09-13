import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parking/components/new_button.dart';
import 'package:parking/src/features/Payment/pay_back_screen.dart';
import 'package:parking/src/features/user/user_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../models/booking.dart';
import '../../models/slot.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final user = authService.getCurrentUser();

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not signed in!")));
    }

    return StreamBuilder<Booking?>(
      stream: firestoreService.getUserBooking(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final booking = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/detail', extra: {'slotId': booking.slotId});
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const _BookingGrid();
      },
    );
  }
}

class _BookingGrid extends StatefulWidget {
  const _BookingGrid();

  @override
  State<_BookingGrid> createState() => _BookingGridState();
}

class _BookingGridState extends State<_BookingGrid> {
  Timer? _expiryCheckTimer;
  Timer? _realtimePollingTimer; // 🔥 NEW: Fallback polling timer
  final DatabaseReference _realtimeDbRef = FirebaseDatabase.instance.ref();

  Map<String, Slot> _mergedSlots = {};
  StreamSubscription<DatabaseEvent>? _realtimeSubscription;
  bool _hasInitialRealtimeData = false;
  bool _isListenerActive = false; // 🔥 NEW: Track listener status

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExpiredSlots();
      _initializeRealtimeConnection(); // 🔥 NEW: Better initialization
    });

    _expiryCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkExpiredSlots(),
    );
  }

  void _checkExpiredSlots() {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    firestoreService.checkAndUpdateExpiredSlots();
  }

  // 🔥 NEW: Initialize Realtime DB with fallback
  Future<void> _initializeRealtimeConnection() async {
    print('🎯 Initializing Realtime Database connection...');

    // Try to set up the listener
    _listenToRealtimeDatabase();

    // Wait a bit to see if listener works
    await Future.delayed(const Duration(seconds: 2));

    if (!_isListenerActive && mounted) {
      print('⚠️ Listener failed, starting polling fallback...');
      _startPollingFallback();
    }
  }

  // 🔥 NEW: Polling fallback if listener fails
  void _startPollingFallback() {
    print('🔄 Starting polling mode (every 3 seconds)');

    // Fetch immediately
    _fetchRealtimeDataOnce();

    // Then poll every 3 seconds
    _realtimePollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _fetchRealtimeDataOnce(),
    );
  }

  // 🔥 NEW: One-time fetch from Realtime DB
  Future<void> _fetchRealtimeDataOnce() async {
    if (!mounted) return;

    try {
      print('📡 Polling Realtime DB...');
      final snapshot = await _realtimeDbRef
          .child('iot_parking')
          .get()
          .timeout(const Duration(seconds: 5));

      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          print('✅ Polling successful! Got ${data.length} slots');
          _updateSlotsWithRealtimeData(data);
        }
      } else {
        print('⚠️ Realtime DB snapshot does not exist');
      }
    } catch (e) {
      print('❌ Polling failed: $e');
    }
  }

  // 🔥 NEW: Update slots with realtime data (extracted for reuse)
  void _updateSlotsWithRealtimeData(Map<dynamic, dynamic> data) {
    setState(() {
      data.forEach((key, value) {
        if (value is Map) {
          final sensorStatus = value['sensor_status'] ?? false;
          final realtimeStatus = value['status'] ?? 'available';

          print(
            '🔍 Processing $key: sensor=$sensorStatus, status=$realtimeStatus',
          );

          if (_mergedSlots.containsKey(key)) {
            final oldFinalStatus = _mergedSlots[key]!.finalStatus;

            _mergedSlots[key] = _mergedSlots[key]!.copyWithSensor(
              sensorStatus: sensorStatus,
              realtimeStatus: realtimeStatus,
            );

            final newFinalStatus = _mergedSlots[key]!.finalStatus;

            if (oldFinalStatus != newFinalStatus) {
              print(
                '🔄 Slot $key status changed: $oldFinalStatus → $newFinalStatus',
              );
            }
          } else {
            print('⏳ Slot $key not yet loaded from Firestore');
          }
        }
      });

      _hasInitialRealtimeData = true;
    });

    // Debug: Print current status of all slots
    print('📊 Current slot statuses:');
    _mergedSlots.forEach((key, slot) {
      print(
        '   $key: sensor=${slot.sensorStatus}, firestore=${slot.status}, final=${slot.finalStatus}',
      );
    });
  }

  // 🔥 IMPROVED: Listen to Realtime Database with better error handling
  void _listenToRealtimeDatabase() {
    print('🎯 Setting up Realtime Database listener...');

    _realtimeSubscription = _realtimeDbRef
        .child('iot_parking')
        .onValue
        .listen(
          (DatabaseEvent event) {
            if (!mounted) return;

            print('🔥 Realtime DB Update Received via Listener!');
            _isListenerActive = true; // Mark listener as working

            // Cancel polling if it was started
            _realtimePollingTimer?.cancel();

            final data = event.snapshot.value as Map<dynamic, dynamic>?;

            if (data != null) {
              _updateSlotsWithRealtimeData(data);
            }
          },
          onError: (error) {
            print('❌ Realtime DB listener error: $error');
            _isListenerActive = false;

            // Start polling fallback if not already running
            if (_realtimePollingTimer == null ||
                !_realtimePollingTimer!.isActive) {
              print('🔄 Starting polling fallback due to listener error...');
              _startPollingFallback();
            }
          },
          cancelOnError: false, // Don't cancel on error, keep trying
        );
  }

  @override
  void dispose() {
    _expiryCheckTimer?.cancel();
    _realtimePollingTimer?.cancel(); // 🔥 NEW: Cancel polling timer
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );

    return StreamBuilder<List<Slot>>(
      stream: firestoreService.getSlots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Scaffold(
            body: Center(child: Text("No parking slots found!")),
          );
        }

        // Update _mergedSlots with latest Firestore data
        final firestoreSlots = snapshot.data!;

        for (var slot in firestoreSlots) {
          if (_mergedSlots.containsKey(slot.id)) {
            // Preserve sensor data while updating Firestore data
            final existingSensorStatus = _mergedSlots[slot.id]!.sensorStatus;
            final existingRealtimeStatus =
                _mergedSlots[slot.id]!.realtimeStatus;

            _mergedSlots[slot.id] = slot.copyWithSensor(
              sensorStatus: existingSensorStatus,
              realtimeStatus: existingRealtimeStatus,
            );
          } else {
            // New slot from Firestore
            _mergedSlots[slot.id] = slot;
          }
        }

        print('📦 Firestore Slots Count: ${firestoreSlots.length}');
        print('📦 Merged Slots: ${_mergedSlots.keys.toList()}');
        print('📦 Has Realtime Data: $_hasInitialRealtimeData');
        print('📦 Listener Active: $_isListenerActive');

        // Get merged slots list
        final slots = _mergedSlots.values.toList();

        // Calculate stats using finalStatus
        final availableCount = slots
            .where((s) => s.finalStatus == SlotStatus.available)
            .length;

        final reservedCount = slots
            .where((s) => s.finalStatus == SlotStatus.reserved)
            .length;

        final occupiedCount = slots
            .where((s) => s.finalStatus == SlotStatus.occupied)
            .length;

        print(
          '📊 Stats - Available: $availableCount, Reserved: $reservedCount, Occupied: $occupiedCount',
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            centerTitle: true,
            title: const Text('Select a Parking Slot'),
            actions: [
              // 🔥 NEW: Connection status indicator
              if (!_hasInitialRealtimeData)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.cloud_off, color: Colors.orange, size: 20),
                ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  final authService = Provider.of<AuthService>(
                    context,
                    listen: false,
                  );
                  await authService.signOut();
                  if (!context.mounted) return;
                  context.go('/onboarding');
                },
                tooltip: 'Logout',
              ),
            ],
          ),
          body: Column(
            children: [
              // Stats
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.check_circle,
                      label: 'Available',
                      count: availableCount,
                      color: Colors.greenAccent,
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _StatItem(
                      icon: Icons.timer,
                      label: 'Reserved',
                      count: reservedCount,
                      color: Colors.orangeAccent,
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _StatItem(
                      icon: Icons.cancel,
                      label: 'Occupied',
                      count: occupiedCount,
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ),

              // Legend
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendItem(
                      color: Colors.green.shade400,
                      label: 'Available',
                    ),
                    const SizedBox(width: 20),
                    _LegendItem(
                      color: Colors.orange.shade400,
                      label: 'Reserved',
                    ),
                    const SizedBox(width: 20),
                    _LegendItem(color: Colors.red.shade400, label: 'Occupied'),
                  ],
                ),
              ),

              // GRID VIEW
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, index) {
                    return _SlotWidget(slot: slots[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF212121)),
        ),
      ],
    );
  }
}

class _SlotWidget extends StatefulWidget {
  final Slot slot;

  const _SlotWidget({required this.slot});

  @override
  State<_SlotWidget> createState() => _SlotWidgetState();
}

class _SlotWidgetState extends State<_SlotWidget> {
  Timer? _countdownTimer;
  String _remainingTime = '';

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didUpdateWidget(_SlotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ Only restart timer if reservedUntil actually changed
    // Ignore finalStatus flicker from ESP32 signal drops
    if (oldWidget.slot.reservedUntil != widget.slot.reservedUntil) {
      _countdownTimer?.cancel();
      _startCountdown();
    }
    // ✅ If slot just became occupied and timer isn't running, start it
    if (widget.slot.finalStatus == SlotStatus.occupied &&
        (_countdownTimer == null || !_countdownTimer!.isActive)) {
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (widget.slot.finalStatus == SlotStatus.occupied &&
        widget.slot.reservedUntil != null) {
      _updateRemainingTime();

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          _updateRemainingTime();
        }
      });
    }
  }

  String _formatBookingDuration(int minutes) {
    if (minutes < 60) {
      return 'Reserved ${minutes}min';
    }
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) {
      return 'Reserved ${hours}h';
    }
    return 'Reserved ${hours}h ${remaining}min';
  }

  void _updateRemainingTime() {
    if (widget.slot.reservedUntil == null) {
      setState(() => _remainingTime = '');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = widget.slot.reservedUntil! - now;

    if (difference <= 0) {
      setState(() => _remainingTime = 'EXPIRED');
      _countdownTimer?.cancel();
      return;
    }

    final totalSeconds = (difference / 1000).floor();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    setState(() {
      if (hours > 0) {
        _remainingTime =
            '${hours}h : ${minutes.toString().padLeft(2, '0')}m : ${seconds.toString().padLeft(2, '0')}s';
      } else {
        _remainingTime =
            '${minutes.toString().padLeft(2, '0')}m : ${seconds.toString().padLeft(2, '0')}s';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(widget.slot.finalStatus);
    final icon = _getStatusIcon(widget.slot.finalStatus);
    final isAvailable = widget.slot.finalStatus == SlotStatus.available;
    final isReserved = widget.slot.finalStatus == SlotStatus.reserved;
    final isOccupied = widget.slot.finalStatus == SlotStatus.occupied;

    return InkWell(
      onTap: isAvailable ? () => _showBookingConfirmation(context) : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white.withOpacity(0.9), size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'P-${widget.slot.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                    ),
                  ),

                  if (isAvailable)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'TAP TO BOOK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // ✅ RESERVED: Show static "Booked for Xh Ymin" label
                  if (isReserved && widget.slot.bookingDuration != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatBookingDuration(widget.slot.bookingDuration!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // ✅ OCCUPIED: Show live countdown timer
                  if (isOccupied && _remainingTime.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _remainingTime,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (!isAvailable)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(SlotStatus status) {
    switch (status) {
      case SlotStatus.available:
        return Colors.green.shade400;
      case SlotStatus.reserved:
        return Colors.orange.shade400;
      case SlotStatus.occupied:
        return Colors.red.shade400;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(SlotStatus status) {
    switch (status) {
      case SlotStatus.available:
        return Icons.approval;
      case SlotStatus.reserved:
        return Icons.schedule;
      case SlotStatus.occupied:
        return Icons.directions_car;
      default:
        return Icons.help_outline;
    }
  }

  void _showBookingConfirmation(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final user = authService.getCurrentUser();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_parking,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(width: 12),
              const Text('Confirm Booking'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Do you want to book parking slot P-${widget.slot.number}?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF0D47A1)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This slot will be reserved for you.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Book Now'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PayBackBooking(slotNumber: widget.slot.number),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
