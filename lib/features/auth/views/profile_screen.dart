import 'package:flutter/material.dart';

import 'account_screen.dart';

@Deprecated('Use AccountScreen for the account/profile flow.')
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AccountScreen();
  }
}
