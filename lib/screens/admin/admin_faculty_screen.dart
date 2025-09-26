// admin_faculty_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:knocksense/models/rfid_model.dart';
import 'package:knocksense/models/teacher_model.dart';
import 'package:knocksense/provider/nfc_provider.dart';
import 'package:knocksense/provider/teacher_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminFacultyScreen extends ConsumerWidget {
  const AdminFacultyScreen({Key? key}) : super(key: key);

  // Design system colors
  static const Color kBg = Color(0xFFF7F8FB);
  static const Color kSurface = Color(0xFFFFFFFF);
  static const Color kText = Color(0xFF000000);
  static const Color kMuted = Color(0xFF888888);
  static const Color kYellow = Color(0xFFFACC15);
  static const Color kGreen = Color(0xFF16A34A);
  static const Color kRed = Color(0xFFDC2626);
  static const Color kBorder = Color(0x0F000000);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredTeachers = ref.watch(filteredTeachersProvider);
    final searchQuery = ref.watch(teacherSearchQueryProvider);

    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSearchBar(ref, searchQuery),
          ),
          
          // Teachers List
          Expanded(
            child: filteredTeachers.when(
              data: (teachers) => _buildTeachersList(context, ref, teachers),
              loading: () => const LoadingWidget(message: 'Loading faculty...'),
              error: (err, stack) => Center(
                child: Text('Error loading faculty: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: kSurface,
      elevation: 0.5,
      title: Text(
        'Account Management',
        style: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: kText,
        ),
      ),
    );
  }

  Widget _buildSearchBar(WidgetRef ref, String currentQuery) {
    return Container(
      height: 43,
      decoration: BoxDecoration(
        color: const Color(0xFFECEDF2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x03000000)),
      ),
      child: TextField(
        onChanged: (value) {
          ref.read(teacherSearchQueryProvider.notifier).state = value;
          ref.read(debouncedSearchQueryProvider.notifier).updateQuery(value);
        },
        style: GoogleFonts.roboto(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: kText,
        ),
        decoration: InputDecoration(
          hintText: 'Search RFID/Card',
          hintStyle: GoogleFonts.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF565E6C),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(16, 9, 16, 8),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset(
              'assets/icons/search.svg',
              width: 20,
              height: 20,
              semanticsLabel: 'Search',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeachersList(BuildContext context, WidgetRef ref, List<TeacherModel> teachers) {
    if (teachers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No faculty members found',
              style: GoogleFonts.roboto(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: teachers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final teacher = teachers[index];
        return _buildFacultyCard(context, ref, teacher);
      },
    );
  }

  Widget _buildFacultyCard(BuildContext context, WidgetRef ref, TeacherModel teacher) {
    final isOnline = teacher.activeStatus == 'online';
    final statusColor = isOnline ? kGreen : kRed;
    final statusText = isOnline ? 'Online' : 'Offline';

    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showTeacherDetails(context, teacher),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: avatar + info + status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  _buildAvatar(teacher),
                  const SizedBox(width: 12),

                  // Name + RFID info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cleanTeacherName(teacher.displayName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: kText,
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: kText,
                            ),
                            children: [
                              const TextSpan(
                                text: 'RFID: ',
                                style: TextStyle(fontWeight: FontWeight.w400),
                              ),
                              TextSpan(
                                text: teacher.rfidUid ?? 'Not assigned',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Status
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActionButton(
                    label: 'Change RFID',
                    svgPath: 'assets/icons/id_card.svg',
                    onTap: () => _showChangeRfidDialog(context, ref, teacher),
                    minWidth: 120,
                  ),
                  _buildActionButton(
                    label: 'Delete',
                    svgPath: 'assets/icons/trash.svg',
                    onTap: () => _showDeleteDialog(context, ref, teacher),
                    minWidth: 80,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(TeacherModel teacher) {
  // Check if the photoUrl is valid
  if (teacher.photoUrl != null && teacher.photoUrl!.isNotEmpty) {
    return CachedNetworkImage(
      imageUrl: teacher.photoUrl!,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: 25,
        backgroundImage: imageProvider,
        backgroundColor: kYellow,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: 25,
        backgroundColor: kYellow.withOpacity(0.5),
        child: const CircularProgressIndicator(
          strokeWidth: 2.0,
          color: kText,
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: 25,
        backgroundColor: kYellow,
        child: Text(
          teacher.initials,
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: kText,
          ),
        ),
      ),
    );
  } else {
    // Fallback for when there is no photoUrl
    return CircleAvatar(
      radius: 25,
      backgroundColor: kYellow,
      child: Text(
        teacher.initials,
        style: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: kText,
        ),
      ),
    );
  }
}

  Widget _buildActionButton({
    required String label,
    required String svgPath,
    required VoidCallback onTap,
    double minWidth = 100,
    double height = 36,
  }) {
    final iconSize = height * 0.45;
    final textSize = height * 0.45;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: SizedBox(
        height: height,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: kBorder, width: 0.72),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: Colors.black,
            visualDensity: VisualDensity.compact,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                svgPath,
                width: iconSize,
                height: iconSize,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: textSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _cleanTeacherName(String fullName) {
    // Remove "(Faculty)" or any parenthetical content
    String cleanedName = fullName.replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim();
    
    // Handle "LastName, FirstName" format
    if (cleanedName.contains(',')) {
      final parts = cleanedName.split(',').map((part) => part.trim()).toList();
      if (parts.length == 2) {
        return 'Prof. ${parts[1]} ${parts[0]}';
      }
    }
    
    return 'Prof. $cleanedName';
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      ),
    );
  }

  void _showTeacherDetails(BuildContext context, TeacherModel teacher) {
    // Show teacher details dialog or navigate to details page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View details for ${_cleanTeacherName(teacher.displayName)}'),
      ),
    );
  }

  // ✅ UPDATED: Full implementation of the change RFID dialog
  void _showChangeRfidDialog(BuildContext context, WidgetRef ref, TeacherModel teacher) {
    showDialog(
      context: context,
      builder: (context) {
        return _ChangeRfidDialogContent(teacher: teacher);
      },
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, TeacherModel teacher) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete this faculty account?'),
              const SizedBox(height: 8),
              Text(
                'Teacher: ${_cleanTeacherName(teacher.displayName)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                // Implement delete functionality
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Account deleted for ${_cleanTeacherName(teacher.displayName)}'),
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

// ✅ NEW: Stateful widget to manage the dialog's state
class _ChangeRfidDialogContent extends ConsumerStatefulWidget {
  final TeacherModel teacher;
  const _ChangeRfidDialogContent({required this.teacher});

  @override
  ConsumerState<_ChangeRfidDialogContent> createState() => _ChangeRfidDialogContentState();
}

class _ChangeRfidDialogContentState extends ConsumerState<_ChangeRfidDialogContent> {
  bool _isLoading = true;
  List<RFIDModel> _availableTags = [];
  String? _selectedRfidUid;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAvailableRfids();
  }

  Future<void> _fetchAvailableRfids() async {
    try {
      final nfcService = ref.read(nfcServiceProvider);
      final tags = await nfcService.getUnassignedRfidTags();
      if (mounted) {
        setState(() {
          _availableTags = tags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load RFID tags.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onSaveChanges() async {
    setState(() => _isLoading = true);
    try {
      final nfcService = ref.read(nfcServiceProvider);
      await nfcService.changeTeacherRfid(widget.teacher.teacherID, _selectedRfidUid);

      if (mounted) {
        Navigator.of(context).pop();
        (context as Element).findAncestorWidgetOfExactType<AdminFacultyScreen>()?._showSnackBar(
          context,
          'RFID successfully updated!',
        );
      }
    } catch (e) {
      if (mounted) {
         (context as Element).findAncestorWidgetOfExactType<AdminFacultyScreen>()?._showSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Teacher RFID'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.teacher.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Current RFID: ${widget.teacher.rfidUid ?? "None"}'),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else
            DropdownButtonFormField<String>(
              value: _selectedRfidUid,
              hint: const Text('Select new RFID tag'),
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Unassign RFID', style: TextStyle(fontStyle: FontStyle.italic)),
                ),
                ..._availableTags.map((tag) {
                  return DropdownMenuItem<String>(
                    value: tag.rfid_uid,
                    child: Text(tag.rfid_uid, style: const TextStyle(fontFamily: 'monospace')),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRfidUid = value;
                });
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _onSaveChanges,
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Changes'),
        ),
      ],
    );
  }
}