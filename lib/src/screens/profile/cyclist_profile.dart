import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/user_preferences_service.dart';

class CyclistProfile extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const CyclistProfile({super.key, this.userData});

  @override
  State<CyclistProfile> createState() => _CyclistProfileState();
}

class _CyclistProfileState extends State<CyclistProfile> {
  final DatabaseService _databaseService = DatabaseService();
  final UserPreferencesService _userPreferencesService =
      UserPreferencesService();
  bool _isLoading = true;

  // Profile data
  String _name = 'Cyclist Name';
  String _mobileNumber = '';
  String _vehicleNumber = '';
  String? _profileImageUrl;

  // Statistics
  int _totalPollings = 0;
  List<Map<String, dynamic>> _dailyStats = [];
  List<Map<String, dynamic>> _monthlyStats = [];
  List<Map<String, dynamic>> _yearlyStats = [];

  String _selectedView = 'day'; // 'day', 'month', 'year'

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadProfileData();
    _loadStatistics();
  }

  Future<void> _loadProfileData() async {
    // Load user data from widget or shared preferences
    if (widget.userData != null) {
      setState(() {
        _name = widget.userData!['username'] ?? 'Cyclist Name';
        _mobileNumber = widget.userData!['mobileno'] ?? '';
        _vehicleNumber = widget.userData!['vehicleno'] ?? '';
        _profileImageUrl = widget.userData!['profileImageUrl'];
      });
    } else {
      // Load from SharedPreferences if userData is not provided
      final userData = await _userPreferencesService.getUserData();
      if (userData != null) {
        setState(() {
          _name = userData['username'] ?? 'Cyclist Name';
          _mobileNumber = userData['mobileno'] ?? '';
          _vehicleNumber = userData['vehicleno'] ?? '';
        });
      }
    }
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final total = await _databaseService.getTotalPollingCount();
      final daily = await _databaseService.getPollingStatsByDay();
      final monthly = await _databaseService.getPollingStatsByMonth();
      final yearly = await _databaseService.getPollingStatsByYear();

      if (mounted) {
        setState(() {
          _totalPollings = total;
          _dailyStats = daily;
          _monthlyStats = monthly;
          _yearlyStats = yearly;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading statistics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  String _formatMonth(String monthStr) {
    try {
      final parts = monthStr.split('-');
      if (parts.length == 2) {
        final monthNames = [
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
        final monthIndex = int.parse(parts[1]) - 1;
        return '${monthNames[monthIndex]} ${parts[0]}';
      }
      return monthStr;
    } catch (e) {
      return monthStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade700,
              Colors.deepPurple.shade400,
              Colors.blue.shade600,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header with back button
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Expanded(
                              child: Text(
                                'Profile',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.white,
                              ),
                              onPressed: _loadStatistics,
                            ),
                          ],
                        ),
                      ),

                      // Profile Section
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Profile Photo
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child:
                                    _profileImageUrl != null &&
                                        _profileImageUrl!.isNotEmpty
                                    ? Image.network(
                                        _profileImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return _buildDefaultAvatar();
                                            },
                                      )
                                    : _buildDefaultAvatar(),
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Name
                            Column(
                              children: [
                                Text(
                                  _name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Mobile Number
                                if (_mobileNumber.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _mobileNumber,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Vehicle Number
                                if (_vehicleNumber.isNotEmpty)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.directions_bike,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _vehicleNumber,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Total Pollings Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Pollings',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$_totalPollings',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // View Toggle Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildViewToggleButton(
                                'Day',
                                'day',
                                Icons.calendar_today,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildViewToggleButton(
                                'Month',
                                'month',
                                Icons.calendar_month,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildViewToggleButton(
                                'Year',
                                'year',
                                Icons.calendar_view_month,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Statistics List
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          // color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: _buildStatisticsList(),
                      ),

                      const SizedBox(height: 24),

                      // Event Duration Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event, color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Event Duration',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '50-60 Days',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.deepPurple.shade300,
      child: const Icon(Icons.person, size: 60, color: Colors.white),
    );
  }

  Widget _buildViewToggleButton(String label, String value, IconData icon) {
    final isSelected = _selectedView == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedView = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsList() {
    List<Map<String, dynamic>> stats = [];
    String Function(String) formatter;

    if (_selectedView == 'day') {
      stats = _dailyStats;
      formatter = _formatDate;
    } else if (_selectedView == 'month') {
      stats = _monthlyStats;
      formatter = _formatMonth;
    } else {
      stats = _yearlyStats;
      formatter = (str) => str;
    }

    if (stats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.bar_chart,
                size: 48,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No polling data available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // padding: const EdgeInsets.all(16),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        final date =
            stat['date'] as String? ??
            stat['month'] as String? ??
            stat['year'] as String? ??
            '';
        final count = stat['count'] as int? ?? 0;

        return Container(
          // margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),

            // borderRadius: BorderRadius.circular(12),
            // border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatter(date),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedView == 'day'
                          ? 'DAY'
                          : _selectedView == 'month'
                          ? 'MONTH'
                          : 'YEAR',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
