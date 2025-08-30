import 'package:flutter_riverpod/flutter_riverpod.dart';

// Basic providers for UI state management
final isLoadingProvider = StateProvider<bool>((ref) => false);
final errorMessageProvider = StateProvider<String?>((ref) => null);
