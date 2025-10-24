import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/provider/appointment_provider.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/provider/teacher_provider.dart';
import 'package:knocksense/provider/teacher_service_provider.dart';
import 'package:knocksense/services/teacher_service.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:knocksense/widgets/student_dash/teacher_detail_modal.dart';
import 'package:knocksense/widgets/common/notification_icon_widget.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Watch the filtered provider instead of the raw stream provider
    final teachers = ref.watch(filteredTeachersProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: user.when(
          data: (userData) {
            if (userData == null) {
              return const Center(child: Text('User data not found.'));
            }
            return CustomScrollView(
              slivers: [
                // App Bar
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'KnockSense',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const NotificationIconWidget(),
                      ],
                    ),
                  ),
                ),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      // Update the debounced provider on change
                      onChanged: (query) => ref
                          .read(debouncedSearchQueryProvider.notifier)
                          .updateQuery(query),
                      decoration: InputDecoration(
                        hintText: 'Search Faculty Members',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),

                // Faculty Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Faculty',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Teachers Grid (Horizontal) - now automatically filtered
                teachers.when(
                  data: (teachersList) {
                    if (teachersList.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Container(
                          height: 140,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Center(
                            child: Text(
                              'No faculty members found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: teachersList.length,
                          itemBuilder: (context, index) {
                            final teacher = teachersList[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: GestureDetector(
                                onTap: () => context.showTeacherDetail(teacher),
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        // Updated to use CachedNetworkImage
                                        teacher.photoUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: teacher.photoUrl!,
                                                imageBuilder: (context, imageProvider) => CircleAvatar(
                                                  radius: 40,
                                                  backgroundImage: imageProvider,
                                                ),
                                                placeholder: (context, url) => CircleAvatar(
                                                  radius: 40,
                                                  backgroundColor: Colors.amber,
                                                  child: const SizedBox(
                                                    width: 30,
                                                    height: 30,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                ),
                                                errorWidget: (context, url, error) => CircleAvatar(
                                                  radius: 40,
                                                  backgroundColor: Colors.amber,
                                                  child: Text(
                                                    teacher.initials,
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : CircleAvatar(
                                                radius: 40,
                                                backgroundColor: Colors.amber,
                                                child: Text(
                                                  teacher.initials,
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(teacher.activeStatus),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        _getDisplayName(teacher.displayName),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) => SliverToBoxAdapter(
                    child: Center(child: Text('Error loading teachers: $err')),
                  ),
                ),

                // Recently Knocked Section (Placeholder for now)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recently Knocked',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Watch the student appointments and show recent ones
                        Consumer(
                          builder: (context, ref, child) {
                            final appointmentsAsync = ref.watch(studentAppointmentsProvider);
                            
                            return appointmentsAsync.when(
                              data: (appointments) {
                                // Get the 3 most recent appointments
                                final recentAppointments = appointments.take(3).toList();
                                
                                if (recentAppointments.isEmpty) {
                                  return Card(
                                    elevation: 0,
                                    color: Colors.grey[100],
                                    child: const ListTile(
                                      leading: Icon(Icons.schedule, color: Colors.grey),
                                      title: Text('No recent appointments'),
                                      subtitle: Text('Your recent appointments will appear here'),
                                    ),
                                  );
                                }
                                
                                return Column(
                                  children: recentAppointments.map((appointment) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Card(
                                        elevation: 0,
                                        color: Colors.white,
                                        child: ListTile(
                                          leading: appointment.teacherPhotoUrl != null
                                              ? CachedNetworkImage(
                                                  imageUrl: appointment.teacherPhotoUrl!,
                                                  imageBuilder: (context, imageProvider) => CircleAvatar(
                                                    radius: 20,
                                                    backgroundImage: imageProvider,
                                                  ),
                                                  placeholder: (context, url) => const CircleAvatar(
                                                    radius: 20,
                                                    backgroundColor: Colors.amber,
                                                    child: SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => CircleAvatar(
                                                    radius: 20,
                                                    backgroundColor: Colors.amber,
                                                    child: Text(
                                                      _getTeacherInitials(appointment.cleanedTeacherName),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor: Colors.amber,
                                                  child: Text(
                                                    _getTeacherInitials(appointment.cleanedTeacherName),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                          title: Text(
                                            appointment.cleanedTeacherName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            _formatAppointmentDate(appointment.createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getAppointmentStatusColor(appointment.status)
                                                  .withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column( // ✅ Use a Column to hold multiple widgets
                                              mainAxisSize: MainAxisSize.min, // Ensure column doesn't expand
                                              crossAxisAlignment: CrossAxisAlignment.end, // Align text to the right
                                              children: [
                                                Text(
                                                  _formatAppointmentStatus(appointment),
                                                  style: TextStyle(
                                                    color: _getAppointmentStatusColor(appointment.status),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                // ✅ Use a collection `if` inside the children list
                                                if (appointment.isScheduled && appointment.scheduledTime != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2.0), // Optional spacing
                                                    child: Text(
                                                      DateFormat('h:mm a').format(appointment.scheduledTime!),
                                                      style: TextStyle(
                                                        color: _getAppointmentStatusColor(appointment.status)
                                                            .withOpacity(0.7),
                                                        fontSize: 9,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                              loading: () => Card(
                                elevation: 0,
                                color: Colors.grey[100],
                                child: const ListTile(
                                  leading: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  title: Text('Loading recent appointments...'),
                                ),
                              ),
                              error: (error, stack) => Card(
                                elevation: 0,
                                color: Colors.red[50],
                                child: ListTile(
                                  leading: Icon(Icons.error_outline, color: Colors.red[400]),
                                  title: const Text('Error loading appointments'),
                                  subtitle: Text(error.toString()),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Teachers List with Status (Vertical) - now automatically filtered
                teachers.when(
                  data: (teachersList) {
                    if (teachersList.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Card(
                            elevation: 0,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No faculty members available',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final teacher = teachersList[index];
                          
                          // Watch the teacher's status with duration
                          final statusWithDuration = ref.watch(
                            teacherStatusWithDurationProvider(teacher.uid)
                          );
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Card(
                              elevation: 0,
                              color: Colors.white,
                              child: ListTile(
                                leading: teacher.photoUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: teacher.photoUrl!,
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
                                            teacher.initials,
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
                                          teacher.initials,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                title: Text(
                                  _cleanTeacherName(teacher.displayName),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                // START MODIFICATION
                                subtitle: statusWithDuration.when(
                                  data: (statusData) {
                                    String? durationText;
                                    if (statusData != null && statusData.changedAt != null) {
                                      durationText = TeacherService.calculateDurationRealTime(
                                        statusData.changedAt,
                                      );
                                    }

                                    if (durationText == null && (teacher.teacherMsg == null || teacher.teacherMsg!.isEmpty)) {
                                      return const SizedBox.shrink();
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (durationText != null)
                                          Text(
                                            durationText,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (teacher.teacherMsg != null && teacher.teacherMsg!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              '“${teacher.teacherMsg!}”',
                                              style: TextStyle(
                                                color: Colors.grey[800],
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                ),
                                // END MODIFICATION
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(teacher.activeStatus)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatStatus(teacher.activeStatus),
                                        style: TextStyle(
                                          color: _getStatusColor(teacher.activeStatus),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      statusWithDuration.when(
                                        data: (statusData) {
                                          if (statusData != null && statusData.changedAt != null) {
                                            // Use real-time duration
                                            final duration = TeacherService.calculateDurationRealTime(statusData.changedAt);
                                            return Text(
                                              duration,
                                              style: TextStyle(
                                                color: _getStatusColor(teacher.activeStatus)
                                                    .withOpacity(0.7),
                                                fontSize: 9,
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                        loading: () => const SizedBox.shrink(),
                                        error: (_, __) => const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () => context.showTeacherDetail(teacher),
                              ),
                            ),
                          );
                        },
                        childCount: teachersList.length,
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) => SliverToBoxAdapter(
                    child: Center(child: Text('Error: $err')),
                  ),
                ),

                // Add extra padding at bottom to avoid content being hidden behind bottom nav
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            );
          },
          loading: () => const LoadingWidget(),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
      
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'busy':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  // New function to clean teacher names (removes "(Faculty)" and properly formats)
  String _cleanTeacherName(String fullName) {
    // Remove "(Faculty)" or any parenthetical content
    String cleanedName = fullName.replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim();
    
    // Handle "LastName, FirstName" format
    if (cleanedName.contains(',')) {
      final parts = cleanedName.split(',').map((part) => part.trim()).toList();
      if (parts.length == 2) {
        // Swap to "FirstName LastName" format
        return '${parts[1]} ${parts[0]}';
      }
    }
    
    return cleanedName;
  }

  // Updated function for horizontal display (shows first and last name)
  String _getDisplayName(String fullName) {
    // Clean the name first
    String cleanedName = fullName.replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim();
    
    // Handle "LastName, FirstName" format
    if (cleanedName.contains(',')) {
      final parts = cleanedName.split(',').map((part) => part.trim()).toList();
      if (parts.length == 2) {
        // Return "FirstName LastName" format
        return '${parts[1]} ${parts[0]}';
      }
    }
    
    return cleanedName;
  }
}

String _getTeacherInitials(String teacherName) {
  final cleanedName = teacherName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

  if (cleanedName.isEmpty) {
    return '??';
  }

  // Handle "LastName, FirstName" format
  if (cleanedName.contains(',')) {
    final parts = cleanedName.split(',').map((part) => part.trim()).toList();
    if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
  }

  // Handle "FirstName MiddleName LastName" format
  final matches = RegExp(r'\b\w').allMatches(cleanedName);
  final initials = matches.map((m) => m.group(0)!).toList();

  if (initials.isEmpty) {
    return '??';
  } else if (initials.length == 1) {
    return initials.first.toUpperCase();
  } else {
    return '${initials.first}${initials.last}'.toUpperCase();
  }
}

String _formatAppointmentDate(DateTime date) {
  final now = DateTime.now();
  
  // Get the start of today (midnight)
  final todayStart = DateTime(now.year, now.month, now.day);
  final dateStart = DateTime(date.year, date.month, date.day);
  
  // Calculate difference in actual calendar days
  final dayDifference = todayStart.difference(dateStart).inDays;
  
  if (dayDifference == 0) {
    // Same calendar day
    return 'Today ${_formatTime(date)}';
  } else if (dayDifference == 1) {
    // Yesterday
    return 'Yesterday ${_formatTime(date)}';
  } else if (dayDifference < 7) {
    // Within a week
    return '$dayDifference days ago';
  } else if (dayDifference < 30) {
    // Within a month
    final weeks = (dayDifference / 7).floor();
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  } else {
    // Older than a month - show full date
    return DateFormat('MMM d, yyyy').format(date);
  }
}

// Also update the _formatTime function to be cleaner:
String _formatTime(DateTime date) {
  return DateFormat('h:mm a').format(date);
}

// // Alternative more detailed version if you want relative time for today:
// String _formatAppointmentDateDetailed(DateTime date) {
//   final now = DateTime.now();
//   final difference = now.difference(date);
  
//   // Get the start of today (midnight)
//   final todayStart = DateTime(now.year, now.month, now.day);
//   final dateStart = DateTime(date.year, date.month, date.day);
//   final dayDifference = todayStart.difference(dateStart).inDays;
  
//   if (dayDifference == 0) {
//     // Same calendar day - show relative time
//     if (difference.inMinutes < 60) {
//       return '${difference.inMinutes} min${difference.inMinutes != 1 ? 's' : ''} ago';
//     } else if (difference.inHours < 12) {
//       return '${difference.inHours} hour${difference.inHours != 1 ? 's' : ''} ago';
//     } else {
//       return 'Today ${_formatTime(date)}';
//     }
//   } else if (dayDifference == 1) {
//     return 'Yesterday ${_formatTime(date)}';
//   } else if (dayDifference < 7) {
//     return '$dayDifference days ago';
//   } else if (dayDifference < 30) {
//     final weeks = (dayDifference / 7).floor();
//     return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
//   } else {
//     return DateFormat('MMM d, yyyy').format(date);
//   }
// }

Color _getAppointmentStatusColor(AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.pending:
      return Colors.orange;
    case AppointmentStatus.accepted:
      return Colors.green;
    case AppointmentStatus.denied:
      return Colors.red;
    case AppointmentStatus.completed:
      return Colors.blue;
    case AppointmentStatus.cancelled:
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

String _formatAppointmentStatus(AppointmentModel appointment) {
  // Handle scheduled appointments
  if (appointment.isScheduled) {
    if (appointment.status == AppointmentStatus.pending) {
      return 'Scheduled';
    } else if (appointment.status == AppointmentStatus.accepted) {
      return 'Confirmed';
    } else if (appointment.status == AppointmentStatus.denied) {
      return 'Rejected';
    }
  }
  
  // Your existing logic for immediate appointments
  if (appointment.status == AppointmentStatus.accepted) {
    switch (appointment.teacherAction) {
      case TeacherAction.meetNow:
        return 'Meet Now';
      case TeacherAction.wait5Minutes:
        return 'Wait 5 Min';
      case TeacherAction.meetLater:
        return 'Later';
      default:
        return 'Accepted';
    }
  }

  switch (appointment.status) {
    case AppointmentStatus.pending:
      return 'Pending';
    case AppointmentStatus.denied:
      return 'Denied';
    case AppointmentStatus.completed:
      return 'Completed';
    case AppointmentStatus.cancelled:
      return 'Cancelled';
    default:
      return 'Unknown';
  }
}