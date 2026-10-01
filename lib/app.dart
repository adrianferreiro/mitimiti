import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/auth_repository.dart';
import 'data/group_data_repository.dart';
import 'data/groups_repository.dart';
import 'data/profile_repository.dart';
import 'data/push_notifications.dart';
import 'ui/auth/login_screen.dart';
import 'ui/groups/groups_screen.dart';
import 'ui/theme.dart';

class MitimitiApp extends StatelessWidget {
  const MitimitiApp({
    super.key,
    required this.auth,
    required this.groups,
    required this.groupData,
    required this.profile,
    required this.push,
  });

  final AuthRepository auth;
  final GroupsRepository groups;
  final GroupDataRepository groupData;
  final ProfileRepository profile;
  final PushNotifications push;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mitimiti',
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildAppTheme(),
      home: StreamBuilder<bool>(
        stream: auth.signedInChanges,
        initialData: auth.isSignedIn,
        builder: (context, snapshot) => snapshot.data!
            ? GroupsScreen(
                auth: auth,
                groups: groups,
                groupData: groupData,
                profile: profile,
                push: push,
              )
            : LoginScreen(auth: auth),
      ),
    );
  }
}
