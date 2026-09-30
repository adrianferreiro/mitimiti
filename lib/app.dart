import 'package:flutter/material.dart';

import 'data/auth_repository.dart';
import 'data/groups_repository.dart';
import 'ui/auth/login_screen.dart';
import 'ui/groups/groups_screen.dart';

class MitimitiApp extends StatelessWidget {
  const MitimitiApp({super.key, required this.auth, required this.groups});

  final AuthRepository auth;
  final GroupsRepository groups;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mitimiti',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      home: StreamBuilder<bool>(
        stream: auth.signedInChanges,
        initialData: auth.isSignedIn,
        builder: (context, snapshot) => snapshot.data!
            ? GroupsScreen(auth: auth, groups: groups)
            : LoginScreen(auth: auth),
      ),
    );
  }
}
