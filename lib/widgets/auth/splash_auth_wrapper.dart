import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/screens/auth/onboarding_screen.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:knocksense/widgets/navigation/student_nav_wrapper.dart';
import 'package:knocksense/widgets/navigation/teacher_navigation_wrapper.dart';
import 'package:knocksense/widgets/navigation/admin_nav_wrapper.dart';

enum SheetMode { onboarding, login }
enum AuthPane { microsoft, admin }

class SplashAuthWrapper extends ConsumerStatefulWidget {
  const SplashAuthWrapper({super.key});

  @override
  ConsumerState<SplashAuthWrapper> createState() => _SplashAuthWrapperState();
}

class _SplashAuthWrapperState extends ConsumerState<SplashAuthWrapper> 
    with TickerProviderStateMixin {
  // ---- Splash sequence state ----
  bool _teaser = true;
  bool _sheetVisible = false;
  double _sheetSize = _minSize;
  bool _splashComplete = false;
  bool _isAuthenticating = false;

  int _phase = 0; // 0..4
  late final AnimationController _titleCtrl;
  Timer? _sequenceTimer;

  // ---- Bottom sheet state ----
  final _sheetCtrl = DraggableScrollableController();
  SheetMode _mode = SheetMode.login; // Start with login directly
  AuthPane _authPane = AuthPane.microsoft;

  // ---- Account removal handling ----
  bool _handlingAccountRemoval = false;
  bool _accountRemovalNoticePending = false;

  // Sheet sizes: collapsed peek + expanded panel
  static const double _minSize = 0.10;
  static const double _maxSize = 0.45;

  // Slower timings & distinct sizes per frame
  static const _phaseDurations = <Duration>[
    Duration(milliseconds: 800),
    Duration(milliseconds: 600),
    Duration(milliseconds: 300),
    Duration(milliseconds: 1100), // title fade-in
    Duration(milliseconds: 1200),
  ];
  static const _sizes = <double>[116, 204, 204, 204, 204];

  // Track previous auth state to detect logout
  User? _previousUser;

  @override
  void initState() {
    super.initState();
    _titleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final frames = const [
        'assets/logo_stage1.png',
        'assets/logo_stage2.png',
        'assets/logo_stage3.png',
        'assets/logo_badge.png',
      ];
      for (final p in frames) {
        await precacheImage(AssetImage(p), context);
      }
      // tiny safety buffer
      await Future.delayed(const Duration(milliseconds: 80));
      _runSplashSequence();
    });
  }

  void _runSplashSequence() {
    int i = 0;
    void step() {
      if (!mounted) return;
      setState(() => _phase = i.clamp(0, 4));
      if (i == 3) _titleCtrl.forward();

      if (i++ < _phaseDurations.length - 1) {
        _sequenceTimer = Timer(_phaseDurations[i], step);
      } else {
        // ✅ Splash done → check auth state
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          setState(() {
            _splashComplete = true;
          });
        });
      }
    }
    _sequenceTimer = Timer(_phaseDurations.first, step);
  }

  // CRITICAL FIX: Reset authentication state when user logs out
  void _resetAuthState() {
    if (mounted) {
      setState(() {
        _isAuthenticating = false;
        _sheetVisible = false;
        _teaser = true;
        _sheetSize = _minSize;
        _authPane = AuthPane.microsoft;
        _handlingAccountRemoval = false;
      });
      
      // Reset the sheet controller if needed
      if (_sheetCtrl.isAttached) {
        _sheetCtrl.jumpTo(_minSize);
      }
    }
  }

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    _titleCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  Future<void> _goOnboarding() async {
    setState(() => _sheetSize = _maxSize);
    await Future.delayed(const Duration(milliseconds: 120));

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );

    // Back from onboarding → show the real login sheet
    setState(() {
      _teaser = false;
      _sheetSize = _minSize;
    });
  }

  Widget _buildAuthenticatedView(UserModel userModel) {
    // Navigate to the correct dashboard based on role
    switch (userModel.role) {
      case UserRole.admin || UserRole.super_admin:
        return const AdminNavWrapper();
      case UserRole.teacher:
        return const MainNavigationTeacher();
      case UserRole.student:
        return const MainNavigationStudent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final t = Theme.of(context).textTheme;
    
    // CRITICAL FIX: Detect logout and reset state
    authState.whenData((currentUser) {
      if (_previousUser != null && currentUser == null) {
        // User just logged out
        _resetAuthState();
      }
      _previousUser = currentUser;
    });
    
    // Check if splash is complete and user is authenticated
    if (_splashComplete) {
      return authState.when(
        data: (user) {
          if (user != null) {
            // User is authenticated, get their details
            final userDetails = ref.watch(currentUserProvider);
            
            return userDetails.when(
              data: (userModel) {
                if (userModel == null) {
                  Future.microtask(() async {
                    if (!_handlingAccountRemoval) {
                      _handlingAccountRemoval = true;
                      _accountRemovalNoticePending = true;
                      final authService = ref.read(authServiceProvider);
                      await authService.signOut();
                      if (mounted) {
                        setState(() {});
                      }
                    }
                  });

                  return _buildLoginScreen(
                    showError: false,
                    showAccountRemoved: true,
                  );
                }
                // Return the appropriate dashboard
                return _buildAuthenticatedView(userModel);
              },
              loading: () => const Scaffold(
                body: LoadingWidget(message: 'Loading user profile...'),
              ),
              error: (err, stack) {
                // On error, sign out and return to login
                Future.microtask(() async {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                });
                
                // Show login screen with error
                return _buildLoginScreen(showError: true);
              },
            );
          } else {
            // No authenticated user, show login screen
            return _buildLoginScreen();
          }
        },
        loading: () => const Scaffold(
          body: LoadingWidget(message: 'Checking authentication...'),
        ),
        error: (err, stack) => _buildLoginScreen(showError: true),
      );
    }

    // Show splash screen while loading
    return _buildSplashScreen();
  }

  Widget _buildLoginScreen({bool showError = false, bool showAccountRemoved = false}) {
    if (!_splashComplete) {
      // If splash not complete, continue showing it
      return _buildSplashScreen();
    }

    // Show the login screen after splash completes
    Future.microtask(() {
      if (mounted && !_sheetVisible) {
        setState(() {
          _sheetVisible = true;
        });
      }
    });

    if (_accountRemovalNoticePending) {
      Future.microtask(() {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account is no longer available. Please contact the administrator.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() {
          _accountRemovalNoticePending = false;
        });
      });
    }

    return _buildSplashScreen();
  }

  Widget _buildSplashScreen() {
    final images = [
      'assets/logo_stage1.png',
      'assets/logo_stage2.png',
      'assets/logo_stage3.png',
      'assets/logo_badge.png',
      'assets/logo_badge.png',
    ];

    final bool lockCenter = _teaser || !_sheetVisible;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Centered splash visuals
            AnimatedAlign(
              alignment: lockCenter
                  ? Alignment.center
                  : (_sheetSize > 0.35 ? Alignment.topCenter : Alignment.center),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: Padding(
                padding: EdgeInsets.only(
                  top: (!lockCenter && _sheetSize > 0.35) ? 28 : 0,
                ),
                child: _ScaledSplash(
                  scale: lockCenter
                      ? 1.0
                      : (() {
                          final k = ((_sheetSize - _minSize) / (_maxSize - _minSize))
                              .clamp(0.0, 1.0);
                          return 1.0 - 0.12 * k;
                        })(),
                  phase: _phase,
                  sizes: _sizes,
                  images: images,
                  titleOpacity: _titleCtrl,
                  textTheme: Theme.of(context).textTheme,
                ),
              ),
            ),

            // Pull-up bottom sheet
            if (_sheetVisible && _splashComplete)
              Align(
                alignment: Alignment.bottomCenter,
                child: _teaser
                    ? _TeaserSheet(
                        onTrigger: _goOnboarding,
                      )
                    : NotificationListener<DraggableScrollableNotification>(
                        onNotification: (n) {
                          setState(() => _sheetSize = n.extent);
                          return false;
                        },
                        child: _PullUpSheet(
                          controller: _sheetCtrl,
                          minSize: _minSize,
                          maxSize: _maxSize,
                          childBuilder: (context, scrollController) {
                            return _LoginPane(
                              ref: ref,
                              pane: _authPane,
                              onPaneChange: (p) => setState(() => _authPane = p),
                              isLoading: _isAuthenticating,
                              onLoadingChange: (loading) => 
                                setState(() => _isAuthenticating = loading),
                            );
                          },
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

// Keep all the helper widgets the same
class _ScaledSplash extends StatelessWidget {
  final double scale;
  final int phase;
  final List<double> sizes;
  final List<String> images;
  final Animation<double> titleOpacity;
  final TextTheme textTheme;

  const _ScaledSplash({
    required this.scale,
    required this.phase,
    required this.sizes,
    required this.images,
    required this.titleOpacity,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      scale: scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Container(
              key: ValueKey(phase),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 18,
                    offset: Offset(0, 10),
                    color: Color(0x1A000000),
                  )
                ],
              ),
              child: Image.asset(
                images[phase],
                width: sizes[phase],
                height: sizes[phase],
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: titleOpacity,
            child: Column(
              children: [
                Text('KnockSense', 
                  style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'Where Availability Meets Simplicity.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.black54, 
                    fontWeight: FontWeight.w400
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeaserSheet extends StatefulWidget {
  final VoidCallback onTrigger;
  final ValueChanged<double>? onProgress;
  const _TeaserSheet({required this.onTrigger, this.onProgress});

  @override
  State<_TeaserSheet> createState() => _TeaserSheetState();
}

class _TeaserSheetState extends State<_TeaserSheet> {
  double _pull = 0;
  static const double _peekHeight = 90;
  static const double _stretch = 28;

  void _reportProgress() {
    final p = (_pull.abs() / _stretch).clamp(0.0, 1.0);
    widget.onProgress?.call(p);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (d.primaryDelta == null) return;
        final next = (_pull + (-d.primaryDelta!)).clamp(0.0, _stretch);
        setState(() => _pull = next);
        _reportProgress();
      },
      onVerticalDragEnd: (d) {
        final v = d.velocity.pixelsPerSecond.dy;
        final trigger = _pull >= (_stretch * 0.6) || v < -500;
        if (trigger) {
          widget.onTrigger();
        } else {
          setState(() => _pull = 0);
          _reportProgress();
        }
      },
      onTap: widget.onTrigger,
      child: Container(
        height: _peekHeight + _pull,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(blurRadius: 24, offset: Offset(0, -8), color: Color(0x1F000000)),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 90,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _PullUpSheet extends StatelessWidget {
  final DraggableScrollableController controller;
  final double minSize;
  final double maxSize;
  final Widget Function(BuildContext, ScrollController) childBuilder;

  const _PullUpSheet({
    required this.controller,
    required this.minSize,
    required this.maxSize,
    required this.childBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: minSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                offset: Offset(0, -8),
                color: Color(0x1F000000),
              )
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 90,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (context) => childBuilder(context, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoginPane extends StatefulWidget {
  final WidgetRef ref;
  final AuthPane pane;
  final ValueChanged<AuthPane> onPaneChange;
  final bool isLoading;
  final ValueChanged<bool> onLoadingChange;

  const _LoginPane({
    required this.ref,
    required this.pane,
    required this.onPaneChange,
    required this.isLoading,
    required this.onLoadingChange,
  });

  @override
  State<_LoginPane> createState() => _LoginPaneState();
}

class _LoginPaneState extends State<_LoginPane> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithMicrosoft() async {
    widget.onLoadingChange(true);

    try {
      final authService = widget.ref.read(authServiceProvider);
      final user = await authService.signInWithMicrosoft();

      if (user == null && mounted) {
        // CRITICAL FIX: Reset loading state if sign-in was cancelled
        widget.onLoadingChange(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in cancelled')),
        );
      }
      // Note: Don't set loading to false on success - the auth state change will rebuild the widget
    } catch (e) {
      if (mounted) {
        widget.onLoadingChange(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
      }
    }
  }

  Future<void> _signInWithEmailPassword() async {
    if (_formKey.currentState?.validate() != true) return;

    widget.onLoadingChange(true);

    try {
      final authService = widget.ref.read(authServiceProvider);
      final user = await authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user == null && mounted) {
        widget.onLoadingChange(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid admin credentials')),
        );
      }
      // Note: Don't set loading to false on success - the auth state change will rebuild the widget
    } catch (e) {
      if (mounted) {
        widget.onLoadingChange(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Admin sign in failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          Text('Login', style: t.titleLarge),
          Text('Welcome Back!',
              style: t.bodyMedium?.copyWith(color: Colors.black54)),
          const SizedBox(height: 10),

          if (widget.pane == AuthPane.microsoft)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.isLoading ? null : _signInWithMicrosoft,
                    icon: SvgPicture.asset(
                     'assets/icons/microsoft_logo.svg',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.business, size: 20);
                      },
                    ),
                    label: widget.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Sign in with Microsoft'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFFF4C21A),
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => widget.onPaneChange(AuthPane.admin),
                  child: const Text('Admin Login'),
                ),
              ],
            ),

          if (widget.pane == AuthPane.admin)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Admin Email',
                      prefixIcon: const Icon(Icons.mail_outline),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(_obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Password required' : null,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          widget.isLoading ? null : _signInWithEmailPassword,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFF4C21A),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: widget.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text('Sign in as Admin'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => widget.onPaneChange(AuthPane.microsoft),
                    child: const Text('Back to Microsoft Login'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}