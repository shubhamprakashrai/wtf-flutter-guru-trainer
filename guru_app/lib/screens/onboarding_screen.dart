import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  final _nameController = TextEditingController(text: 'DK');
  bool _trainerSelected = true;
  bool _creating = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _finish() async {
    if (_nameController.text.trim().isEmpty || !_trainerSelected) return;
    setState(() => _creating = true);
    await context.read<AuthCubit>().createMember(name: _nameController.text.trim(), trainerId: SeedData.trainerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Slide(
                    icon: Icons.fitness_center,
                    title: 'Train with your coach, anywhere',
                    body: 'Chat, schedule and video-call your assigned trainer - all in one place.',
                  ),
                  _Slide(
                    icon: Icons.calendar_month,
                    title: 'Book calls in a tap',
                    body: 'Pick a slot, get approved, join the live session right from your chat.',
                  ),
                  _ProfileSetup(
                    nameController: _nameController,
                    trainerSelected: _trainerSelected,
                    onTrainerToggle: (v) => setState(() => _trainerSelected = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      3,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _page ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page ? const Color(0xFF1769E0) : Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _creating
                        ? null
                        : _page < 2
                            ? _next
                            : _finish,
                    child: _creating
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_page < 2 ? 'Next' : 'Get Started'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Slide({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(color: const Color(0xFF1769E0).withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, size: 56, color: const Color(0xFF1769E0)),
          ),
          const SizedBox(height: 32),
          Text(title, style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(body, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ProfileSetup extends StatelessWidget {
  final TextEditingController nameController;
  final bool trainerSelected;
  final ValueChanged<bool> onTrainerToggle;

  const _ProfileSetup({required this.nameController, required this.trainerSelected, required this.onTrainerToggle});

  @override
  Widget build(BuildContext context) {
    // Sits inside a fixed-height PageView page - when the keyboard opens,
    // the Scaffold shrinks and a plain centered Column would overflow.
    // A scroll view lets the content ride up above the keyboard instead.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Create your profile', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('This is how your trainer will see you.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          const Text('Name', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: nameController, decoration: const InputDecoration(hintText: 'Your name')),
          const SizedBox(height: 24),
          const Text('Your trainer', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => onTrainerToggle(true),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: trainerSelected ? const Color(0xFF1769E0) : Theme.of(context).colorScheme.outlineVariant,
                  width: trainerSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  UserAvatar(url: SeedData.trainer.avatarUrl, fallbackInitial: 'A'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(SeedData.trainer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Lead Trainer', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (trainerSelected) const Icon(Icons.check_circle, color: Color(0xFF1769E0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
