import 'package:fiers_artisans_app/data/models/portfolio_model.dart';
import 'package:fiers_artisans_app/presentation/common/portfolio_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildHarness(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('renders without overflow in narrow constraints', (tester) async {
    final item = PortfolioModel(
      id: 'p1',
      artisanId: 'a1',
      title: 'Realisation ultra detaillee avec un titre volontairement long',
      description:
          'Description longue pour valider la stabilite du layout en petite largeur.',
      imageUrls: const [],
      price: 125000,
    );

    await tester.pumpWidget(
      _buildHarness(
        const SizedBox(width: 220, height: 260, child: SizedBox.shrink()),
      ),
    );

    await tester.pumpWidget(
      _buildHarness(
        SizedBox(width: 220, height: 260, child: PortfolioItemCard(item: item)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PortfolioItemCard), findsOneWidget);
    expect(find.textContaining('125'), findsOneWidget);
  });

  testWidgets('keeps swipe navigation on mobile without arrows', (
    tester,
  ) async {
    final item = PortfolioModel(
      id: 'p2',
      artisanId: 'a1',
      title: 'Cuisine moderne',
      imageUrls: const [
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
      ],
    );

    await tester.pumpWidget(
      _buildHarness(
        SizedBox(width: 260, height: 300, child: PortfolioItemCard(item: item)),
      ),
    );
    await tester.pump();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-220, 0));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('shows arrows and supports click navigation on desktop', (
    tester,
  ) async {

    final item = PortfolioModel(
      id: 'p3',
      artisanId: 'a1',
      title: 'Cuisine moderne',
      imageUrls: const [
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
      ],
    );

    await tester.pumpWidget(
      _buildHarness(
        SizedBox(width: 260, height: 300, child: PortfolioItemCard(item: item)),
      ),
    );
    await tester.pump();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
  }, variant: TargetPlatformVariant.desktop());
}
