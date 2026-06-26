import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentIndex = 0;

  final _slides = const [
    _OnboardingSlide(
      image: 'assets/onb1.png',
      title: 'Smart Availability Checking',
      body: 'Connect smarter, check availability and request meetings without knocking.',
    ),
    _OnboardingSlide(
      image: 'assets/onb2.png',
      title: 'Manage Your Schedule',
      body: 'Set when you\'re available, manage student requests, and avoid interruptions.',
    ),
    _OnboardingSlide(
      image: 'assets/onb3.png',
      title: 'Knock Digitally',
      body: 'Skip the knocking, skip the hassle, knock through your phone instead.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final slideHeight = h * 0.46;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and title at top
                  Column(
                    children: [
                      Image.asset(
                        'assets/logo_badge.png',
                        width: 100,
                        height: 100,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                  color: Color(0x1A000000),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.school,
                              size: 50,
                              color: Color(0xFFF4C21A),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'KnockSense',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),

                  // PageView for slides
                  SizedBox(
                    height: slideHeight,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemCount: _slides.length,
                      itemBuilder: (_, i) {
                        final slide = _slides[i];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Card with image
                            Container(
                              width: 340,
                              height: 210,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                    color: Color(0x14000000),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Image.asset(
                                slide.image,
                                width: 318,
                                height: 191,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.image_not_supported,
                                        size: 60,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Image not found',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Text content
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                children: [
                                  Text(
                                    slide.title,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    slide.body,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Dots indicator
                  _DotsIndicator(
                    count: _slides.length,
                    currentIndex: _currentIndex,
                  ),
                  
                  const SizedBox(height: 18),

                  // Next/Finish button
                  Center(
                    child: SizedBox(
                      width: 120,
                      height: 45,
                      child: FilledButton(
                        onPressed: () {
                          if (_currentIndex < _slides.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOut,
                            );
                          } else {
                            // Finish onboarding and go back
                            Navigator.of(context).pop();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF4C21A),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_currentIndex < _slides.length - 1 ? 'Next' : 'Start'),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Back button
                  Center(
                    child: IconButton(
                      onPressed: _currentIndex == 0
                          ? null
                          : () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOut,
                              ),
                      icon: const Icon(Icons.chevron_left_rounded),
                      style: IconButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFEDEDED),
                        fixedSize: const Size(50, 50),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final String image;
  final String title;
  final String body;

  const _OnboardingSlide({
    required this.image,
    required this.title,
    required this.body,
  });
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;

  const _DotsIndicator({
    required this.count,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final isActive = i == currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            height: 6,
            width: isActive ? 26 : 6,
            decoration: BoxDecoration(
              color: isActive ? Colors.black87 : Colors.black26,
              borderRadius: BorderRadius.circular(6),
            ),
          );
        }),
      ),
    );
  }
}