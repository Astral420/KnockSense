import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/provider/auth_provider.dart';

class UserAvatar extends ConsumerWidget {
  final double radius;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;

  const UserAvatar({
    Key? key,
    this.radius = 20,
    this.showBorder = true,
    this.borderColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the stream provider to get real-time updates
    final userStream = ref.watch(currentUserProvider);

    return userStream.when(
      data: (user) {
        if (user == null) {
          return _buildDefaultAvatar(context);
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: showBorder
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: borderColor ?? Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  )
                : null,
            child: CircleAvatar(
              radius: radius,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? Text(
                      getInitials(user.displayName),
                      style: TextStyle(
                        fontSize: radius * 0.8,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
      loading: () => _buildLoadingAvatar(context),
      error: (_, __) => _buildDefaultAvatar(context),
    );
  }

  Widget _buildLoadingAvatar(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Icon(
        Icons.person,
        size: radius * 1.2,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  String getInitials(String name) {
  // 1. Preprocess the name to remove roles like (Student) or (Faculty)
  final cleanedName = name.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

  // Return empty string if the name is empty after cleaning
  if (cleanedName.isEmpty) {
    return '';
  }

  // 2. Handle "LastName, FirstName" format
  if (cleanedName.contains(',')) {
    final parts = cleanedName.split(',').map((part) => part.trim()).toList();
    if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      // Combines the first letter of the last name and the first name
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
  }

  // 3. Handle "FirstName MiddleName LastName" format using regex
  // This regex finds the first letter of each word (\b for word boundary, \w for a word character)
  final matches = RegExp(r'\b\w').allMatches(cleanedName);
  final initials = matches.map((m) => m.group(0)!).toList();

  if (initials.isEmpty) {
    return '';
  } else if (initials.length == 1) {
    // For single-word names
    return initials.first.toUpperCase();
  } else {
    // For multi-word names, combines the first and last initial found
    return '${initials.first}${initials.last}'.toUpperCase();
  }
}
}