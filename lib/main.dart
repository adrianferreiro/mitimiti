import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/auth_repository.dart';
import 'data/group_data_repository.dart';
import 'data/groups_repository.dart';
import 'data/profile_repository.dart';
import 'data/push_notifications.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final client = Supabase.instance.client;
  final push = PushNotifications(client, FirebaseMessaging.instance);
  final auth = AuthRepository(client.auth, beforeSignOut: push.unregister);
  // Registrar el dispositivo al iniciar con sesión y en cada inicio de sesión.
  auth.signedInChanges.distinct().where((signedIn) => signedIn).listen((_) {
    push.register();
  });
  runApp(
    MitimitiApp(
      auth: auth,
      groups: GroupsRepository(client),
      groupData: GroupDataRepository(client),
      profile: ProfileRepository(client),
      push: push,
    ),
  );
}
