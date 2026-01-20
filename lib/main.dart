import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'blocs/blocs.dart';
import 'services/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ru', null);

  final authService = AuthService();
  final databaseService = DatabaseService();
  final gmailService = GmailService();
  final emailParserService = EmailParserService();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>.value(value: authService),
        RepositoryProvider<DatabaseService>.value(value: databaseService),
        RepositoryProvider<GmailService>.value(value: gmailService),
        RepositoryProvider<EmailParserService>.value(value: emailParserService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(authService: authService)
              ..add(const AuthCheckRequested()),
          ),
          BlocProvider<SubscriptionBloc>(
            create: (context) => SubscriptionBloc(
              databaseService: databaseService,
              gmailService: gmailService,
              emailParserService: emailParserService,
              authService: authService,
            ),
          ),
        ],
        child: const App(),
      ),
    ),
  );
}
