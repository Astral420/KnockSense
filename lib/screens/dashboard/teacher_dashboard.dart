// screens/teacher_dashboard.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:cached_network_image/cached_network_image.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/provider/teacher_service_provider.dart';
import 'package:knocksense/provider/appointment_provider.dart';
//import 'package:knocksense/services/teacher_service.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:knocksense/widgets/teacher_dash/add_note_modal.dart';
import 'package:knocksense/screens/teacher/recent_knocks_screen.dart';
import 'package:knocksense/widgets/common/useravatar_widget.dart';

class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {

  Widget _buildOverlappingAvatars(List<dynamic> appointments) {
    final displayedAppointments = appointments.take(3).toList();
    const double avatarRadius = 24;
    const double overlap = 20;

    if (displayedAppointments.isEmpty) {
      return Container(height: avatarRadius * 2);
    }

    return SizedBox(
      height: avatarRadius * 2,
      width: (avatarRadius * 2) + (overlap * (displayedAppointments.length - 1)),
      child: Stack(
        children: List.generate(displayedAppointments.length, (index) {
          final appointment = displayedAppointments[index];
          return Positioned(
            left: index * overlap,
            child: UserAvatar.custom(
              photoUrl: appointment.studentPhotoUrl,
              displayName: appointment.cleanedStudentName,
              radius: avatarRadius,
              showBorder: true,
              // Use the new, cleaner properties directly
              borderColor: const Color(0xFFFFE69C),
              borderWidth: 2,
              backgroundColor: const Color(0xFFFFC107),
              textColor: Colors.black87,
            ),
          );
        }).reversed.toList(),
      ),
    );
  }

  
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    //final authService = ref.read(authServiceProvider);
    // Use the active appointments provider for notification badge
    final activeAppointments = ref.watch(teacherActiveAppointmentsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: user.when(
          data: (userData) {
            if (userData == null) {
              return const Center(child: Text('User data not found.'));
            }


            final statusStream = ref.watch(teacherStatusProvider(userData.uid));
            final noteStream = ref.watch(teacherNoteProvider(userData.uid));
            
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
                                'Teacher',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Stack(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.notifications_outlined),
                                  onPressed: () {
                                    // Navigate to Recent Knocks when notification icon is pressed
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const RecentKnocksScreen(),
                                      ),
                                    );
                                  },
                                ),
                                // Show red dot if there are active appointments
                                activeAppointments.when(
                                  data: (appointments) {
                                    if (appointments.isNotEmpty) {
                                      return Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Cards Grid
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0, // Make cards square
                    ),
                    delegate: SliverChildListDelegate([
                      // Recent Knocks Card with active appointments data
                      activeAppointments.when(
                        data: (appointments) => _buildRecentKnocksCard(appointments),
                        loading: () => _buildRecentKnocksCard([]),
                        error: (_, __) => _buildRecentKnocksCard([]),
                      ),
                      
                      // Status Card
                      statusStream.when(
                        data: (status) => _buildStatusCard(status, userData.uid),
                        loading: () => _buildStatusCard('offline', userData.uid),
                        error: (_, __) => _buildStatusCard('offline', userData.uid),
                      ),
                      
                      // Add Notes Card
                      noteStream.when(
                        data: (note) => _buildAddNotesCard(note, userData.uid),
                        loading: () => _buildAddNotesCard(null, userData.uid),
                        error: (_, __) => _buildAddNotesCard(null, userData.uid),
                      ),

                      // NEW: Manual Door Unlock Card
                      _buildManualDoorUnlockCard(userData),
                    ]),
                  ),
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

  Widget _buildRecentKnocksCard(List<dynamic> activeAppointments) {
    final hasAppointments = activeAppointments.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RecentKnocksScreen(),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD), // Light yellow/amber background
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Knocks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF856404), // Brown color
                    ),
                  ),
                  if (hasAppointments)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${activeAppointments.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                hasAppointments
                    ? '${activeAppointments.length} student${activeAppointments.length > 1 ? 's are' : ' is'} waiting'
                    : 'No students are waiting',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.brown[600],
                  height: 1.2,
                ),
              ),
              // This is the new section with overlapping avatars
              if (hasAppointments)
                _buildOverlappingAvatars(activeAppointments)
              else
                // Show a placeholder icon when no one is waiting
                Container(
                  height: 48, // Match the avatar height
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    Icons.notifications_off_outlined,
                    color: Colors.brown.withOpacity(0.6),
                    size: 32,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(String currentStatus, String teacherUid) {
  final user = ref.watch(currentUserProvider);
  final isOffline = currentStatus.toLowerCase() == 'offline';
  final isBusy = currentStatus.toLowerCase() == 'busy';
  
  // Watch the enhanced status stream with duration
  final statusWithDuration = ref.watch(teacherStatusWithDurationProvider(teacherUid));
  
  Color backgroundColor;
  Color textColor;
  String statusText;
  
  if (isOffline) {
    backgroundColor = const Color(0xFF424242); // Dark grey
    textColor = Colors.white;
    statusText = 'Offline';
  } else if (isBusy) {
    backgroundColor = const Color(0xFFFFE0B2); // Light orange
    textColor = const Color(0xFFE65100); // Dark orange
    statusText = 'Busy';
  } else {
    backgroundColor = const Color.fromARGB(255, 22, 163, 74); // Light green
    textColor = const Color.fromARGB(255, 23, 83, 23); // Dark green
    statusText = 'Online';
  }
  
  return GestureDetector(
    // Only allow toggling if not offline
    onTap: isOffline ? null : () => _toggleStatus(teacherUid, currentStatus),
    child: Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isOffline ? Colors.white70 : textColor,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              isOffline 
                  ? 'Controlled by RFID\nreader system'
                  : 'Tap to toggle\nbetween online/busy',
              style: TextStyle(
                fontSize: 13,
                color: isOffline ? Colors.white60 : textColor.withOpacity(0.8),
                height: 1.2,
              ),
            ),
            const Spacer(),
            
            // Inner container with status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: isBusy 
                    ? const Color(0xFFFF9800) // Orange for busy
                    : isOffline 
                        ? Colors.black.withOpacity(0.3)
                        : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Use current user's photo
                      user.when(
                        data: (userData) {
                          if (userData != null) {
                            return UserAvatar.custom(
                              photoUrl: userData.photoUrl,
                              displayName: userData.displayName,
                              radius: 20,
                              showBorder: false,
                              backgroundColor: isBusy 
                                  ? const Color(0xFFE65100) 
                                  : isOffline
                                      ? Colors.grey[700]
                                      : const Color(0xFF2E7D32),
                              textColor: Colors.white,
                            );
                          }
                          return _buildDefaultAvatar(isBusy, isOffline);
                        },
                        loading: () => _buildDefaultAvatar(isBusy, isOffline),
                        error: (_, __) => _buildDefaultAvatar(isBusy, isOffline),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        isBusy 
                            ? Icons.person_off
                            : isOffline 
                                ? Icons.person_off
                                : Icons.person,
                        color: Colors.white,
                        size: 32,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Display real-time duration
                  statusWithDuration.when(
                    data: (statusData) {
                      final duration = statusData?.duration ?? 'Unknown';
                      return Text(
                        duration,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        key: ValueKey('${statusData?.status}_${statusData?.changedAt?.millisecondsSinceEpoch}'),
                      );
                    },
                    loading: () => Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    error: (_, __) => Text(
                      'Unknown',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  
}

Widget _buildDefaultAvatar(bool isBusy, bool isOffline) {
  return CircleAvatar(
    radius: 20,
    backgroundColor: isBusy 
        ? const Color(0xFFE65100) 
        : isOffline
            ? Colors.grey[700]
            : const Color(0xFF2E7D32),
    child: const Text(
      'T',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    ),
  );
}

  Widget _buildAddNotesCard(String? currentNote, String teacherUid) {
    return GestureDetector(
      onTap: () => _showAddNoteModal(context, teacherUid, currentNote),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE1BEE7), // Light purple
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A148C), // Dark purple
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Update the students\nabout your status.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6A1B9A), // Medium purple
                  height: 1.2,
                ),
              ),
              const Spacer(),
              // Inner container with note preview or add button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0), // Purple
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        
                        const SizedBox(width: 0.5),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    if (currentNote != null && currentNote.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currentNote.length > 20 
                              ? '${currentNote.substring(0, 20)}...'
                              : currentNote,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        'Add note',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Manual Door Unlock Card
  Widget _buildManualDoorUnlockCard(dynamic userData) {
    final manualUnlockState = ref.watch(manualDoorUnlockProvider);
    final manualUnlockStatus = ref.watch(manualUnlockStatusProvider(userData.uid));

    return GestureDetector(
      onTap: () => _requestManualUnlock(userData),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E8), // Light green
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Door Unlock',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32), // Dark green
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Open door for 4 seconds\nwithout RFID scan.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF388E3C), // Medium green
                  height: 1.2,
                ),
              ),
              const Spacer(),
              
              // Inner container with unlock button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50), // Green
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    // Show different states based on unlock status
                    manualUnlockState.when(
                      data: (success) {
                        if (success) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_open,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          );
                        }
                      },
                      loading: () => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      error: (_, __) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Status text
                    manualUnlockState.when(
                      data: (success) {
                        if (success) {
                          return manualUnlockStatus.when(
                            data: (status) {
                              switch (status) {
                                case 'pending':
                                  return const Text(
                                    'Requested...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                case 'unlocked':
                                  return const Text(
                                    'Door Unlocked!',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                case 'completed':
                                  return const Text(
                                    'Completed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                default:
                                  return const Text(
                                    'Tap to unlock',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                              }
                            },
                            loading: () => const Text(
                              'Checking...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            error: (_, __) => const Text(
                              'Tap to unlock',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        } else {
                          return const Text(
                            'Tap to unlock',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                      },
                      loading: () => const Text(
                        'Processing...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      error: (_, __) => const Text(
                        'Error - Try again',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleStatus(String teacherUid, String currentStatus) async {
  final teacherService = ref.read(teacherServiceProvider);
  
  // Toggle between online and busy only
  String newStatus = currentStatus.toLowerCase() == 'online' ? 'busy' : 'online';
  
  print('🔄 Toggling status from $currentStatus to $newStatus for teacher $teacherUid');

  await teacherService.updateTeacherStatus(teacherUid, newStatus);
}

  // NEW: Request manual door unlock
  Future<void> _requestManualUnlock(dynamic userData) async {
    final manualUnlockNotifier = ref.read(manualDoorUnlockProvider.notifier);
    
    // Show confirmation dialog
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Door Unlock'),
        content: const Text('This will unlock the door for 4 seconds. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Unlock Door'),
          ),
        ],
      ),
    );

    if (shouldProceed == true) {
      await manualUnlockNotifier.requestUnlock(
        userData.uid,
        userData.displayName,
        userData.teacherID ?? '',
      );
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Door unlock requested successfully'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showAddNoteModal(BuildContext context, String teacherUid, String? currentNote) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddNoteModal(
        teacherUid: teacherUid,
        currentNote: currentNote,
      ),
    );
  }
}