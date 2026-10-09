import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
// GlobalMaterialLocalizations vem do material_ui; oculta o duplicado do sdk
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/visit.dart';
import 'models/place.dart';
import 'models/place_visit.dart';
import 'models/reservation.dart';
import 'providers/visit_provider.dart';
import 'providers/place_provider.dart';
import 'services/auth_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/session_selector_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/counter_screen.dart';
import 'screens/place_reservation_screen.dart';
import 'theme/jalapao_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize Hive
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(VisitAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PlaceAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(PlaceVisitAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ReservationAdapter());

  final visitsBox = await Hive.openBox<Visit>('visits');
  final placesBox = await Hive.openBox<Place>('places');
  final placeVisitsBox = await Hive.openBox<PlaceVisit>('place_visits');
  final reservationsBox = await Hive.openBox<Reservation>('reservations');
  final configBox = await Hive.openBox('config');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => VisitProvider(visitsBox, configBox),
        ),
        ChangeNotifierProvider(
          create:
              (_) => PlaceProvider(
                placesBox,
                placeVisitsBox,
                reservationsBox,
                configBox,
              ),
        ),
        ChangeNotifierProvider(create: (_) => AuthService(configBox)),
      ],
      child: const JalapaoApp(),
    ),
  );
}

class JalapaoApp extends StatelessWidget {
  const JalapaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jalapão Monitor 2.1-beta',
      debugShowCheckedModeBanner: false,
      theme: JalapaoTheme.themeData,
      // Força pt_BR: 24h em TimeOfDay.format, seletor de data/hora em português
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
      home: const HomeRouter(),
    );
  }
}

/// Roteador principal. Reage a mudanças em VisitProvider e PlaceProvider.
/// Fluxo: onboarding → seleção de sessão → tela por tipo de local.
class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  static const _reservationTypes = {
    'restaurante',
    'pousada',
    'fazenda',
    'chacaras',
  };

  @override
  Widget build(BuildContext context) {
    final visitProvider = context.watch<VisitProvider>();
    final placeProvider = context.watch<PlaceProvider>();

    // Passo 1: tablet ainda não configurado → onboarding
    if (!visitProvider.isConfigured) {
      return const OnboardingScreen();
    }

    // Passo 2: sessão não selecionada → seleção de local
    final sessionPlaceId = placeProvider.activeSessionPlaceId;
    if (sessionPlaceId == null) {
      // Tablet fervedouro dedicado: sem places ativos no Hub → DashboardScreen
      if (placeProvider.approvedPlaces.isEmpty) {
        return const DashboardScreen();
      }
      return const SessionSelectorScreen();
    }

    // Passo 3: valida que o local ainda existe e está ativo
    final place = placeProvider.getPlace(sessionPlaceId);
    if (place == null || place.status != 'active') {
      // Local foi desativado/removido → volta para seleção
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => placeProvider.clearActiveSession(),
      );
      return const SessionSelectorScreen();
    }

    // Passo 4: roteia por tipo
    if (place.type == 'fervedouro') {
      return const DashboardScreen();
    }
    if (_reservationTypes.contains(place.type)) {
      return const PlaceReservationScreen();
    }
    // cachoeira, atrativo_cultural, camping, loja
    return const CounterScreen();
  }
}
