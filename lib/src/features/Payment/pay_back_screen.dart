import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class PayBackBooking extends StatefulWidget {
  final int slotNumber;

  const PayBackBooking({super.key, required this.slotNumber});

  @override
  State<PayBackBooking> createState() => _PayBackBookingState();
}

class _PayBackBookingState extends State<PayBackBooking> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedTimeUnit = 'Minutes';
  double _selectedValue = 35;
  bool _isBooking = false;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  double get _minValue {
    switch (_selectedTimeUnit) {
      case 'Seconds':
        return 35;
      case 'Minutes':
        return 10;
      case 'Hours':
        return 1;
      default:
        return 10;
    }
  }

  double get _maxValue {
    switch (_selectedTimeUnit) {
      case 'Seconds':
        return 120;
      case 'Minutes':
        return 180;
      case 'Hours':
        return 12;
      default:
        return 180;
    }
  }

  int get _divisions {
    switch (_selectedTimeUnit) {
      case 'Seconds':
        return 21;
      case 'Minutes':
        return 17;
      case 'Hours':
        return 11;
      default:
        return 17;
    }
  }

  // ✅ NEW: Format the display value smartly
  String _formatDisplayValue() {
    final value = _selectedValue.toInt();
    switch (_selectedTimeUnit) {
      case 'Seconds':
        if (value >= 60) {
          final mins = value ~/ 60;
          final secs = value % 60;
          if (secs == 0) return '$mins min';
          return '$mins min $secs sec';
        }
        return '$value sec';
      case 'Minutes':
        if (value >= 60) {
          final hrs = value ~/ 60;
          final mins = value % 60;
          if (mins == 0) return '${hrs}h';
          return '${hrs}h ${mins}min';
        }
        return '$value min';
      case 'Hours':
        return '${value}h';
      default:
        return '$value $_selectedTimeUnit';
    }
  }

  Future<void> _confirmBooking() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your car number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      // ✅ GET CURRENT USER (ANONYMOUS)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception("User not authenticated!");
      }

      print('🔐 Current User ID: ${currentUser.uid}');

      // Convert to minutes for storage
      int durationInMinutes;
      switch (_selectedTimeUnit) {
        case 'Seconds':
          durationInMinutes = (_selectedValue / 60).ceil();
          break;
        case 'Hours':
          durationInMinutes = (_selectedValue * 60).toInt();
          break;
        case 'Minutes':
        default:
          durationInMinutes = _selectedValue.toInt();
      }

      String slotId = 'slot${widget.slotNumber}';
      String carNumber = _nameController.text.trim();

      // Calculate reserved_until timestamp
      int reservedUntil = _selectedTimeUnit == 'Seconds'
          ? DateTime.now().millisecondsSinceEpoch +
                (_selectedValue * 1000).toInt()
          : DateTime.now().millisecondsSinceEpoch +
                (durationInMinutes * 60 * 1000);

      final slotRef = _db.collection('parking_slots').doc(slotId);

      // Use transaction to ensure atomicity
      await _db.runTransaction((transaction) async {
        final slotSnapshot = await transaction.get(slotRef);

        if (!slotSnapshot.exists) {
          throw Exception("Slot does not exist!");
        }

        final slotData = slotSnapshot.data() as Map<String, dynamic>;
        final currentStatus = slotData['status'] as String;

        if (currentStatus != 'available') {
          throw Exception("Slot is already reserved!");
        }

        // ✅ CRITICAL FIX: Add user_id field!
        transaction.update(slotRef, {
          'status': 'reserved',
          'user_id': currentUser.uid,
          'car_number': carNumber,
          'reserved_until': reservedUntil,
          'booking_duration': durationInMinutes,
        });
      });

      print('✅ Booking successful!');
      print('📦 Slot: $slotId');
      print('👤 User ID: ${currentUser.uid}');

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Slot ${widget.slotNumber} booked successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to detail screen AFTER successful booking
      context.go(
        '/detail',
        extra: {'slotId': slotId, 'userId': currentUser.uid},
      );
    } catch (e) {
      print('❌ Booking failed: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Book Slot ${widget.slotNumber}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Animated Car Parking Scene
            Container(
              margin: const EdgeInsets.all(20),
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
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Parking Lot Animation
                  SizedBox(
                    height: 140,
                    child: Stack(
                      children: [
                        // Parking Lines
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              3,
                              (index) => Container(
                                width: 80,
                                height: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Icon(
                                    index == 1
                                        ? Icons.directions_car
                                        : Icons.local_parking,
                                    size: index == 1 ? 50 : 30,
                                    color: index == 1
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Arrow pointing to middle slot
                        const Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Icon(
                            Icons.arrow_downward,
                            color: Colors.yellowAccent,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Text
                  const Text(
                    'Reserve Your Perfect Spot! 🎯',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Form Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name Input
                  const Text(
                    'Enter your Car Number',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    enabled: !_isBooking,
                    onChanged: (_) => setState(() {}), // ✅ refresh summary
                    decoration: InputDecoration(
                      hintText: 'Car Number',
                      prefixIcon: const Icon(
                        Icons.directions_car,
                        color: Color(0xFF0D47A1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF0D47A1),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Time Selection with Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Parking Duration',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212121),
                        ),
                      ),
                      // Toggle between Seconds, Minutes and Hours
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            _buildToggleButton('Seconds'),
                            _buildToggleButton('Minutes'),
                            _buildToggleButton('Hours'),
                          ],
                        ),
                      ),
                    ],
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
                      children: [
                        // ✅ Time Display — now shows smart format
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Color(0xFF0D47A1),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatDisplayValue(), // ✅ CHANGED
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Slider
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: const Color(0xFF0D47A1),
                            inactiveTrackColor: Colors.grey.shade300,
                            thumbColor: const Color(0xFF0D47A1),
                            overlayColor: const Color(
                              0xFF0D47A1,
                            ).withOpacity(0.2),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12,
                            ),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: _selectedValue,
                            min: _minValue,
                            max: _maxValue,
                            divisions: _divisions,
                            onChanged: _isBooking
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedValue = value;
                                    });
                                  },
                          ),
                        ),

                        // Min and Max labels
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedTimeUnit == 'Seconds'
                                    ? '${_minValue.toInt()} sec'
                                    : '${_minValue.toInt()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                _selectedTimeUnit == 'Seconds'
                                    ? '${_maxValue.toInt()} sec (2 min)'
                                    : '${_maxValue.toInt()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Booking Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Booking Summary',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // ✅ CHANGED: uses _formatDisplayValue() instead of raw number
                        _buildSummaryRow('Duration', _formatDisplayValue()),
                        _buildSummaryRow(
                          'Slot Number',
                          'P-${widget.slotNumber}',
                        ),
                        if (_nameController.text.trim().isNotEmpty)
                          _buildSummaryRow(
                            'Car Number',
                            _nameController.text.trim(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Confirm Button
                  ElevatedButton(
                    onPressed: _isBooking ? null : _confirmBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    child: _isBooking
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Booking...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Confirm Booking',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label) {
    final isSelected = _selectedTimeUnit == label;
    return GestureDetector(
      onTap: _isBooking
          ? null
          : () {
              setState(() {
                _selectedTimeUnit = label;
                if (label == 'Seconds') {
                  _selectedValue = 35;
                } else if (label == 'Minutes') {
                  _selectedValue = 30;
                } else {
                  _selectedValue = 2;
                }
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D47A1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
        ],
      ),
    );
  }
}
