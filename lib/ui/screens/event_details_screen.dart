import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/db_helper.dart';
import '../../models/event_model.dart';

class EventDetailsScreen extends StatefulWidget {
  final int eventId;
  final String eventName;

  const EventDetailsScreen({super.key, required this.eventId, required this.eventName});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  EventModel? event;
  Map<String, dynamic>? stats;
  List<Map<String, dynamic>> dailyStats = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final storage = GetStorage();
    final userId = storage.read(AppConstants.userIdKey)?.toString() ?? 'user1';

    final eventData = await DBHelper.instance.getEventById(widget.eventId);
    final statsData = await DBHelper.instance.getEventStats(userId, widget.eventId);
    final daily = await DBHelper.instance.getDailyStatsForEvent(userId, widget.eventId);

    if (eventData == null) {
      setState(() => loading = false);
      return;
    }

    final statsMap = {for (var item in daily) item['date']: item};
    List<Map<String, dynamic>> fullDailyStats = [];

    DateTime current = eventData.eventFromDate;
    final end = DateTime(eventData.eventToDate.year, eventData.eventToDate.month, eventData.eventToDate.day);

    while (!current.isAfter(end)) {
      final dateStr = DateFormat('yyyy-MM-dd').format(current);
      fullDailyStats.add(statsMap[dateStr] ?? {'date': dateStr, 'steps': 0, 'distance': 0.0, 'calories': 0.0});
      current = current.add(const Duration(days: 1));
    }

    setState(() {
      event = eventData;
      stats = statsData;
      dailyStats = fullDailyStats;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(widget.eventName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventTimeInfo(),
                  const SizedBox(height: 25),
                  _buildEventStepCounter(),
                  const SizedBox(height: 25),
                  _buildEventActivityStats(),
                  const SizedBox(height: 25),
                  if (dailyStats.length > 1) ...[
                    _buildEventDateScroller(),
                    const SizedBox(height: 25),
                  ],
                  _buildEventDetails(),
                  const SizedBox(height: 25),
                  _buildEventProgress(),
                  const SizedBox(height: 25),
                  _buildTimeWindow(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SLIVER APP BAR ====================
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppConstants.primaryColor,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.eventName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(0, 1), blurRadius: 2)],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(child: Icon(Icons.directions_walk, size: 80, color: Colors.white38)),
        ),
      ),
    );
  }

  // ==================== EVENT TIME INFO ====================
  Widget _buildEventTimeInfo() {
    final isActive = _isEventActive;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? AppConstants.primaryColor.withValues(alpha: 0.1) : Colors.orange[50],
        borderRadius: BorderRadius.circular(AppConstants.radius),
        border: Border.all(
          color: isActive ? AppConstants.primaryColor.withValues(alpha: 0.3) : Colors.orange[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.timer : Icons.schedule,
                color: isActive ? AppConstants.primaryColor : Colors.orange[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? 'Event Active Now!' : 'Event Schedule',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppConstants.primaryColor : Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Daily Time: ${event!.eventFromTime} - ${event!.eventToTime}',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Duration: ${event!.eventDurationMinutes} minutes',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Event Dates: ${DateFormat('MMM dd').format(event!.eventFromDate)} - ${DateFormat('MMM dd, yyyy').format(event!.eventToDate)}',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
          if (event!.eventLocation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(child: Text(event!.eventLocation, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==================== EVENT STEP COUNTER ====================
  Widget _buildEventStepCounter() {
    final totalSteps = stats?['steps'] ?? 0;
    final goalSteps = int.tryParse(event?.eventGoal ?? '0') ?? 5000;
    final progress = goalSteps > 0 ? (totalSteps / goalSteps).clamp(0.0, 1.0) : 0.0;
    final isActive = _isEventActive;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radius),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text('Event Steps', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppConstants.primaryColor)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [AppConstants.primaryColor, AppConstants.secondaryColor]
                    : [Colors.orange[400]!, Colors.orange[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radius * 2),
              boxShadow: [
                BoxShadow(
                  color: (isActive ? AppConstants.primaryColor : Colors.orange).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Circular Progress
                SizedBox(
                  height: 200,
                  width: 200,
                  child: Stack(
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 12,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.transparent),
                        ),
                      ),
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatNumber(totalSteps),
                              style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text('Event Steps', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white.withValues(alpha: 0.9))),
                            const SizedBox(height: 8),
                            Text('${(progress * 100).toInt()}%', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Progress Text
                Text(
                  progress >= 1.0
                      ? 'Event Goal Completed! 🎉'
                      : isActive
                          ? "Keep going! You're ${(progress * 100).toInt()}% there"
                          : 'Event not active - Steps paused',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                if (progress < 1.0 && isActive) ...[
                  const SizedBox(height: 4),
                  Text('Goal: $goalSteps ${event?.eventGoalType ?? 'steps'}', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
                ],
                const SizedBox(height: 16),
                // Status Message
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _getEventStatusMessage(),
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EVENT ACTIVITY STATS ====================
  Widget _buildEventActivityStats() {
    final distance = (stats?['distance'] ?? 0.0) / 1000;
    final calories = stats?['calories'] ?? 0.0;
    final isActive = _isEventActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Event Activity', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _buildEventStatCard(Icons.straighten, 'Distance', distance.toStringAsFixed(2), Colors.blue, 'Kilometers', isActive)),
            const SizedBox(width: 12),
            Expanded(child: _buildEventStatCard(Icons.local_fire_department, 'Calories', calories.toStringAsFixed(0), Colors.orange, 'Burned', isActive)),
            const SizedBox(width: 12),
            Expanded(child: _buildEventStatCard(Icons.timer, 'Duration', '$_durationDays', Colors.purple, 'Days', isActive)),
          ],
        ),
      ],
    );
  }

  Widget _buildEventStatCard(IconData icon, String title, String value, Color color, String subtitle, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radius),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: (isActive ? color : Colors.grey).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: isActive ? color : Colors.grey[600], size: 24),
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: isActive ? AppConstants.primaryColor : Colors.grey[600])),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          Text(subtitle, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ==================== EVENT DATE SCROLLER ====================
  Widget _buildEventDateScroller() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Event Daily Progress', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
        const SizedBox(height: 15),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: dailyStats.length,
            itemBuilder: (context, index) => _buildEventDateCard(dailyStats[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildEventDateCard(Map<String, dynamic> day) {
    final date = DateTime.parse(day['date']);
    final isToday = _isSameDay(date, DateTime.now());
    final isFutureDate = date.isAfter(DateTime.now());
    final steps = day['steps'] as int;
    final goalSteps = int.tryParse(event?.eventGoal ?? '0') ?? 5000;
    final isGoalAchieved = steps >= goalSteps;
    final progress = goalSteps > 0 ? (steps / goalSteps).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: 90,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radius),
        border: Border.all(
          color: isToday
              ? AppConstants.primaryColor
              : isGoalAchieved
                  ? AppConstants.primaryColor.withValues(alpha: 0.3)
                  : Colors.grey[200]!,
          width: isToday ? 2 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(DateFormat('EEE').format(date), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: isToday ? AppConstants.primaryColor : isFutureDate ? Colors.grey[400] : Colors.grey[600])),
              Text('${date.day}', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: isToday ? AppConstants.primaryColor : isFutureDate ? Colors.grey[400] : AppConstants.primaryColor)),
            ],
          ),
          Column(
            children: [
              Text(isFutureDate ? '--' : _formatSteps(steps), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: isFutureDate ? Colors.grey[400] : AppConstants.primaryColor)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                height: 3,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: Colors.grey[200]),
                child: isFutureDate
                    ? null
                    : FractionallySizedBox(
                        widthFactor: progress,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: isGoalAchieved ? AppConstants.primaryColor : AppConstants.primaryColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          if (isToday)
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppConstants.primaryColor, shape: BoxShape.circle))
          else if (isGoalAchieved && !isFutureDate)
            const Icon(Icons.check_circle, size: 16, color: AppConstants.primaryColor)
          else if (isFutureDate)
            Icon(Icons.schedule, size: 16, color: Colors.grey[400])
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==================== EVENT DETAILS ====================
  Widget _buildEventDetails() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Event Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppConstants.primaryColor)),
          const SizedBox(height: 12),
          Text(
            event!.eventDesc.isNotEmpty ? event!.eventDesc : 'No description available.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Event Type', event!.eventType.capitalize ?? event!.eventType),
          _buildDetailRow('Goal', '${event!.eventGoal} ${event!.eventGoalType}'),
          _buildDetailRow('Duration', '$_durationDays days'),
          if (event!.eventPrizeDesc.isNotEmpty) _buildDetailRow('Reward', event!.eventPrizeDesc),
        ],
      ),
    );
  }

  // ==================== EVENT PROGRESS ====================
  Widget _buildEventProgress() {
    final daysCompleted = _durationDays - _remainingDays;
    final progress = _durationDays > 0 ? daysCompleted / _durationDays : 0.0;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Event Progress', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppConstants.primaryColor)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Days Remaining', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
              Text('$_remainingDays of $_durationDays', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppConstants.primaryColor)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(event!.status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor)),
          ),
        ],
      ),
    );
  }

  // ==================== TIME WINDOW ====================
  Widget _buildTimeWindow() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Time Window', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppConstants.primaryColor)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTimeCard('Start Time', event!.eventFromTime, Icons.access_time, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildTimeCard('End Time', event!.eventToTime, Icons.access_time_filled, Colors.orange)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTimeCard(
            'Current Status',
            _isInTimeWindow ? 'In Time Window' : 'Outside Time Window',
            _isInTimeWindow ? Icons.check_circle : Icons.schedule,
            _isInTimeWindow ? AppConstants.primaryColor : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================
  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radius),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[800])),
        ],
      ),
    );
  }

  // ==================== COMPUTED PROPERTIES ====================
  bool get _isEventActive {
    if (event == null) return false;
    final now = DateTime.now();
    return now.isAfter(event!.eventFromDate) && now.isBefore(event!.eventToDate.add(const Duration(days: 1))) && _isInTimeWindow;
  }

  bool get _isInTimeWindow {
    if (event == null) return false;
    final now = DateTime.now();
    final startParts = event!.eventFromTime.split(':');
    final endParts = event!.eventToTime.split(':');
    final startTime = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
    final endTime = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  int get _durationDays => event != null ? event!.eventToDate.difference(event!.eventFromDate).inDays + 1 : 0;

  int get _remainingDays {
    if (event == null) return 0;
    final now = DateTime.now();
    if (now.isBefore(event!.eventFromDate)) return _durationDays;
    if (now.isAfter(event!.eventToDate)) return 0;
    return event!.eventToDate.difference(now).inDays + 1;
  }

  Color get _statusColor {
    switch (event?.status.toLowerCase()) {
      case 'active':
        return AppConstants.primaryColor;
      case 'upcoming':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _getEventStatusMessage() {
    if (_isEventActive) return 'Event is active! Steps are being counted';
    if (event!.eventFromDate.isAfter(DateTime.now())) return "Event hasn't started yet";
    if (event!.eventToDate.isBefore(DateTime.now())) return 'Event has ended';
    if (!_isInTimeWindow) return 'Outside event time window (${event!.eventFromTime} - ${event!.eventToTime})';
    return 'Event inactive';
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatNumber(int num) => num.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _formatSteps(int steps) => steps >= 1000 ? '${(steps / 1000).toStringAsFixed(1)}K' : steps.toString();
}
