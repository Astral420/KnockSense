import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

// Model for knocked history item
class KnockedHistoryItem {
  final String teacherUid;
  final String teacherName;
  final String teacherInitials;
  final String? teacherPhotoUrl;
  final DateTime knockedAt;
  final String status; // 'waiting', 'completed', 'denied', 'pending'
  final String? requestMessage;
  final DateTime? respondedAt;

  KnockedHistoryItem({
    required this.teacherUid,
    required this.teacherName,
    required this.teacherInitials,
    this.teacherPhotoUrl,
    required this.knockedAt,
    required this.status,
    this.requestMessage,
    this.respondedAt,
  });
}

// Provider for date range filter
final dateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

// Provider for mock history data (will be replaced with Firebase stream)
final knockedHistoryProvider = Provider<List<KnockedHistoryItem>>((ref) {
  // Hard coded data for now
  return [
    KnockedHistoryItem(
      teacherUid: 'uid1',
      teacherName: 'Prof. Santos',
      teacherInitials: 'PS',
      teacherPhotoUrl: null,
      knockedAt: DateTime(2025, 8, 23, 1, 4),
      status: 'waiting',
      requestMessage: 'Your request is waiting for Prof. Santos',
    ),
    KnockedHistoryItem(
      teacherUid: 'uid2',
      teacherName: 'Prof. Gonzales',
      teacherInitials: 'PG',
      teacherPhotoUrl: null,
      knockedAt: DateTime(2025, 8, 21, 2, 6),
      status: 'completed',
      requestMessage: null,
      respondedAt: DateTime(2025, 8, 21, 2, 30),
    ),
    KnockedHistoryItem(
      teacherUid: 'uid3',
      teacherName: 'Prof. Kim',
      teacherInitials: 'PK',
      teacherPhotoUrl: null,
      knockedAt: DateTime(2025, 8, 21, 10, 0),
      status: 'completed',
      requestMessage: null,
      respondedAt: DateTime(2025, 8, 21, 10, 15),
    ),
    KnockedHistoryItem(
      teacherUid: 'uid4',
      teacherName: 'Prof. Garcia',
      teacherInitials: 'GG',
      teacherPhotoUrl: null,
      knockedAt: DateTime(2025, 8, 20, 3, 30),
      status: 'denied',
      requestMessage: 'Your request was denied by Prof. Garcia',
      respondedAt: DateTime(2025, 8, 20, 3, 45),
    ),
    KnockedHistoryItem(
      teacherUid: 'uid5',
      teacherName: 'Prof. Reyes',
      teacherInitials: 'PR',
      teacherPhotoUrl: null,
      knockedAt: DateTime(2025, 8, 19, 9, 15),
      status: 'pending',
      requestMessage: 'Your request is waiting for Prof. Reyes',
    ),
  ];
});

// Filtered history based on date range
final filteredHistoryProvider = Provider<List<KnockedHistoryItem>>((ref) {
  final history = ref.watch(knockedHistoryProvider);
  final dateRange = ref.watch(dateRangeProvider);
  
  if (dateRange == null) return history;
  
  return history.where((item) {
    return item.knockedAt.isAfter(dateRange.start) &&
           item.knockedAt.isBefore(dateRange.end.add(const Duration(days: 1)));
  }).toList();
});

class KnockedHistoryPage extends ConsumerWidget {
  const KnockedHistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredHistory = ref.watch(filteredHistoryProvider);
    final dateRange = ref.watch(dateRangeProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Knocked History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Student',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.amber),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Date Range Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by Date Range:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'Start Date',
                          date: dateRange?.start,
                          onTap: () => _selectDateRange(context, ref),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DatePickerField(
                          label: 'End Date',
                          date: dateRange?.end,
                          onTap: () => _selectDateRange(context, ref),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // History List
            Expanded(
              child: filteredHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No knocked history found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, index) {
                        final item = filteredHistory[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _KnockedHistoryCard(item: item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context, WidgetRef ref) async {
    final initialDateRange = ref.read(dateRangeProvider) ?? DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(dateRangeProvider.notifier).state = picked;
    }
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              date != null
                  ? DateFormat('MMM dd, yyyy').format(date!)
                  : label,
              style: TextStyle(
                fontSize: 14,
                color: date != null ? Colors.black : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KnockedHistoryCard extends StatelessWidget {
  final KnockedHistoryItem item;

  const _KnockedHistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Teacher Avatar
            item.teacherPhotoUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.teacherPhotoUrl!,
                    imageBuilder: (context, imageProvider) => CircleAvatar(
                      radius: 24,
                      backgroundImage: imageProvider,
                    ),
                    placeholder: (context, url) => CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.amber,
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.amber,
                      child: Text(
                        item.teacherInitials,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.amber,
                    child: Text(
                      item.teacherInitials,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
            const SizedBox(width: 12),
            
            // Teacher Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.teacherName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('M/d/yyyy, h:mm a').format(item.knockedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // Status Widget
            _buildStatusWidget(item.status, item.requestMessage),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusWidget(String status, String? message) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return const RequestWaitingWidget();
      case 'completed':
        return const RequestCompletedWidget();
      case 'denied':
        return const RequestDeniedWidget();
      case 'pending':
        return const RequestPendingWidget();
      default:
        return const SizedBox();
    }
  }
}

// Status Widget 1: Waiting
class RequestWaitingWidget extends StatelessWidget {
  const RequestWaitingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Waiting',
        style: TextStyle(
          color: Colors.orange,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Status Widget 2: Completed
class RequestCompletedWidget extends StatelessWidget {
  const RequestCompletedWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Completed',
        style: TextStyle(
          color: Colors.green,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Status Widget 3: Denied
class RequestDeniedWidget extends StatelessWidget {
  const RequestDeniedWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.close,
            size: 14,
            color: Colors.red,
          ),
          SizedBox(width: 4),
          Text(
            'Denied',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Status Widget 4: Pending (Additional status for flexibility)
class RequestPendingWidget extends StatelessWidget {
  const RequestPendingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 14,
            color: Colors.amber,
          ),
          SizedBox(width: 4),
          Text(
            'Pending',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}