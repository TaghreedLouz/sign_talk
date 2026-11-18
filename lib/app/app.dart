import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../features/camera/camera_screen.dart';
import '../features/text_to_sign/text_to_sign_screen.dart';

class SignTalkApp extends StatelessWidget {
  const SignTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SignTalkTwoScreens(),
    );
  }
}

class SignTalkTwoScreens extends StatefulWidget {
  const SignTalkTwoScreens({super.key});

  @override
  State<SignTalkTwoScreens> createState() => _SignTalkTwoScreensState();
}

class _SignTalkTwoScreensState extends State<SignTalkTwoScreens> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _selectedIndex == 0
            ? const TextToSignScreen()
            : const CameraScreen(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sign_language_outlined),
            selectedIcon: Icon(Icons.sign_language),
            label: 'Text to Sign',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Sign to Text',
          ),
        ],
      ),
    );
  }
}
