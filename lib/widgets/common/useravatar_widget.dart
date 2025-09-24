import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:knocksense/provider/auth_provider.dart';

class UserAvatar extends ConsumerWidget {
  final double radius;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  
  // New parameters for custom usage
  final String? photoUrl;
  final String? displayName;
  final Color? backgroundColor;
  final Color? textColor;
  final bool useCurrentUser; // When false, use provided photoUrl and displayName

  const UserAvatar({
    Key? key,
    this.radius = 20,
    this.showBorder = true,
    this.borderColor,
    this.borderWidth = 2,
    this.onTap,
    this.photoUrl,
    this.displayName,
    this.backgroundColor,
    this.textColor,
    this.useCurrentUser = true,
  }) : super(key: key);

  // Named constructor for custom user (not current user)
  const UserAvatar.custom({
    Key? key,
    required this.photoUrl,
    required this.displayName,
    this.radius = 20,
    this.showBorder = true,
    this.borderColor,
    this.borderWidth = 2,
    this.backgroundColor,
    this.textColor,
    this.onTap,
  }) : useCurrentUser = false, super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!useCurrentUser) {
      // Use provided photoUrl and displayName
      return _buildAvatarWidget(
        context, 
        photoUrl: photoUrl,
        name: displayName ?? 'Unknown',
      );
    }

    final userStream = ref.watch(currentUserProvider);

    return userStream.when(
      data: (user) {
        if (user == null) {
          return _buildDefaultAvatar(context);
        }

        return _buildAvatarWidget(
          context,
          photoUrl: user.photoUrl,
          name: user.displayName,
        );
      },
      loading: () => _buildLoadingAvatar(context),
      error: (_, __) => _buildDefaultAvatar(context),
    );
  }

  Widget _buildAvatarWidget(BuildContext context, {String? photoUrl, required String name}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: showBorder
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor ?? Theme.of(context).primaryColor,
                  width: borderWidth,
                ),
              )
            : null,
        child: photoUrl != null && photoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl,
                imageBuilder: (context, imageProvider) => CircleAvatar(
                  radius: radius,
                  backgroundImage: imageProvider,
                ),
                placeholder: (context, url) => CircleAvatar(
                  radius: radius,
                  backgroundColor: backgroundColor ?? Theme.of(context).primaryColor.withOpacity(0.1),
                  child: SizedBox(
                    width: radius * 0.8,
                    height: radius * 0.8,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => _buildInitialsAvatar(context, name),
              )
            : _buildInitialsAvatar(context, name),
      ),
    );
  }

  Widget _buildInitialsAvatar(BuildContext context, String name) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor.withOpacity(0.1),
      child: Text(
        getInitials(name),
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: textColor ?? Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildLoadingAvatar(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Theme.of(context).primaryColor.withOpacity(0.1),
      ),
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor.withOpacity(0.1),
      child: Icon(
        Icons.person,
        size: radius * 1.2,
        color: textColor ?? Theme.of(context).primaryColor,
      ),
    );
  }

  String getInitials(String name) {
    final cleanedName = name.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

    if (cleanedName.isEmpty) {
      return '';
    }

    if (cleanedName.contains(',')) {
      final parts = cleanedName.split(',').map((part) => part.trim()).toList();
      if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
    }

    final matches = RegExp(r'\b\w').allMatches(cleanedName);
    final initials = matches.map((m) => m.group(0)!).toList();

    if (initials.isEmpty) {
      return '';
    } else if (initials.length == 1) {
      return initials.first.toUpperCase();
    } else {
      return '${initials.first}${initials.last}'.toUpperCase();
    }
  }
}