import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/auth_repository.dart';
import 'data/group_data_repository.dart';
import 'data/groups_repository.dart';
import 'data/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  final client = Supabase.instance.client;
  runApp(
    MitimitiApp(
      auth: AuthRepository(client.auth),
      groups: GroupsRepository(client),
      groupData: GroupDataRepository(client),
      profile: ProfileRepository(client),
    ),
  );
}
