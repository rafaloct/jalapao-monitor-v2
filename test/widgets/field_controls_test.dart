import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jalapao_monitor/models/place.dart';
import 'package:jalapao_monitor/models/reservation.dart';
import 'package:jalapao_monitor/providers/place_provider.dart';
import 'package:jalapao_monitor/screens/place_reservation_screen.dart';
import 'package:jalapao_monitor/services/auth_service.dart';
import 'package:jalapao_monitor/theme/jalapao_theme.dart';
import 'package:jalapao_monitor/widgets/pax_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

double _linear(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _linear(color.r) +
    0.7152 * _linear(color.g) +
    0.0722 * _linear(color.b);

double _contrast(Color foreground, Color background) {
  final first = _luminance(foreground);
  final second = _luminance(background);
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

Color _visibleTextColor(WidgetTester tester, Finder textFinder) {
  return tester.renderObject<RenderParagraph>(textFinder).text.style!.color!;
}

Finder _chip(String value) => find.ancestor(
  of: find.text(value),
  matching: find.byWidgetPredicate((widget) => widget is InkWell),
);

Color _chipFill(WidgetTester tester, Finder chip, Color surface) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(of: chip, matching: find.byType(AnimatedContainer)),
  );
  final fill = (container.decoration! as BoxDecoration).color!;
  return Color.alphaBlend(fill, surface);
}

class _PlaceProviderStub extends ChangeNotifier implements PlaceProvider {
  _PlaceProviderStub(this.place);

  final Place place;

  @override
  List<Place> get approvedPlaces => [place];

  @override
  String? get activeSessionPlaceId => place.id;

  @override
  Place? getPlace(String placeId) => placeId == place.id ? place : null;

  @override
  List<Reservation> reservationsByPlace(String placeId, DateTime date) => [];

  @override
  List<Reservation> onSiteByPlace(String placeId) => [];

  @override
  List<Reservation> staleCheckIns(String placeId, {int maxHours = 4}) => [];

  @override
  int getReservationOccupancy(String placeId) => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthServiceStub extends ChangeNotifier implements AuthService {
  @override
  bool get isLoggedIn => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('PaxSelector renders readable chips with 48dp tap targets', (
    tester,
  ) async {
    var selected = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: JalapaoTheme.fieldHighContrast,
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => PaxSelector(
                selectedCount: selected,
                maxPax: 30,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      ),
    );

    final surface = Theme.of(tester.element(find.byType(PaxSelector)))
        .scaffoldBackgroundColor;
    for (final value in ['1', '2', '4', '10']) {
      final chip = _chip(value);
      expect(chip, findsOneWidget);
      final size = tester.getSize(chip);
      expect(size.width, greaterThanOrEqualTo(48), reason: 'chip $value width');
      expect(
        size.height,
        greaterThanOrEqualTo(48),
        reason: 'chip $value height',
      );

      final label = find.descendant(of: chip, matching: find.byType(Text));
      final foreground = _visibleTextColor(tester, label);
      final background = _chipFill(tester, chip, surface);
      expect(
        _contrast(foreground, background),
        greaterThanOrEqualTo(4.5),
        reason: 'chip $value text against its composited fill',
      );
    }

    await tester.tap(_chip('2'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(selected, 2);
    final selectedChip = _chip('2');
    final selectedLabel = find.descendant(
      of: selectedChip,
      matching: find.byType(Text),
    );
    expect(
      _contrast(
        _visibleTextColor(tester, selectedLabel),
        _chipFill(tester, selectedChip, surface),
      ),
      greaterThanOrEqualTo(4.5),
      reason: 'selected chip text after a real tap',
    );
  });

  testWidgets('Quick Entry CTA keeps a 48dp target and readable label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final place = Place(
      id: 'synthetic-place',
      name: 'Local sintético',
      type: 'fervedouro',
      latitude: 0,
      longitude: 0,
      capacityTotal: 30,
      ownerName: '',
      contactPhone: '',
      status: 'active',
    );
    final places = _PlaceProviderStub(place);
    final auth = _AuthServiceStub();
    addTearDown(places.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaceProvider>.value(value: places),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: MaterialApp(
          theme: JalapaoTheme.fieldHighContrast,
          home: const PlaceReservationScreen(),
        ),
      ),
    );
    // The first frame selects the place; the next settles the enabled button.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final quickEntry = find.ancestor(
      of: find.text('ENTRADA RÁPIDA'),
      matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
    );
    expect(quickEntry, findsOneWidget);
    expect(tester.widget<ElevatedButton>(quickEntry).onPressed, isNotNull);
    final size = tester.getSize(quickEntry);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    final material = tester.widget<Material>(
      find.descendant(
        of: quickEntry,
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.type == MaterialType.button,
        ),
      ),
    );
    final fill = material.color!;
    final label = _visibleTextColor(tester, find.text('ENTRADA RÁPIDA'));
    expect(fill, JalapaoTheme.secondaryDeep);
    expect(label, JalapaoTheme.onPrimary);
    expect(_contrast(label, fill), greaterThanOrEqualTo(4.5));

    await tester.tap(quickEntry);
    await tester.pump();
    expect(find.text('REGISTRAR ENTRADA'), findsOneWidget);
    final register = find.ancestor(
      of: find.text('REGISTRAR ENTRADA'),
      matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
    );
    expect(tester.getSize(register).height, greaterThanOrEqualTo(48));
  });
}
