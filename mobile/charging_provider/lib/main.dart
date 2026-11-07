import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/amplify_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Amplify.addPlugin(AmplifyAuthCognito());

  await Amplify.configure(amplifyConfig);

  runApp(
    const ProviderScope(
      child: ChargingProviderApp(),
    ),
  );
}