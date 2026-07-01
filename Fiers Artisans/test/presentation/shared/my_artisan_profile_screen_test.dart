import 'package:easy_localization/easy_localization.dart';
import 'package:fiers_artisans/config/theme.dart';
import 'package:fiers_artisans/data/models/artisan_model.dart';
import 'package:fiers_artisans/presentation/shared/my_artisan_profile_screen.dart';
import 'package:fiers_artisans/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InlineAssetLoader extends AssetLoader {
  const _InlineAssetLoader(this.translations);

  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return translations;
  }
}

void main() {
  testWidgets('renders artisan profile screen without layout exceptions', (
    tester,
  ) async {
    final artisan = ArtisanModel(
      id: 'artisan-profile-id',
      userId: 'artisan-user-id',
      firstName: 'Awa',
      lastName: 'Konan',
      phone: '0701020304',
      email: 'awa@example.com',
      profession: 'Electricienne',
      businessName: 'Awa Services',
      description: 'Interventions domestiques et professionnelles.',
      address: 'Rue des Jardins',
      whatsappNumber: '0701020304',
      experienceYears: 7,
      city: 'Abidjan',
      commune: 'Cocody',
      latitude: 5.348,
      longitude: -3.986,
      averageRating: 4.8,
      totalReviews: 24,
      isVerified: true,
      isAvailable: true,
      hasActiveSubscription: true,
      categoryName: 'BTP',
      subcategoryName: 'Electricite',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          artisanOwnProfileProvider.overrideWith((ref) async => artisan),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('fr')],
          path: 'unused',
          fallbackLocale: const Locale('fr'),
          startLocale: const Locale('fr'),
          assetLoader: const _InlineAssetLoader({
            'artisan': {
              'verified': 'Vérifié',
              'available': 'Disponible',
              'experience': '{years} ans d\'expérience',
            },
            'profile': {
              'fields': {
                'experience': 'Expérience',
                'rating': 'Note',
                'reviews_count': 'Nombre d\'avis',
                'subscription': 'Abonnement',
                'full_name': 'Identité',
                'phone': 'Telephone',
                'email': 'Email',
                'business_name': 'Structure',
                'trade': 'Métier',
                'category': 'Catégorie',
                'whatsapp': 'WhatsApp',
                'city': 'Ville',
                'commune': 'Commune',
                'address': 'Adresse',
                'latitude': 'Latitude GPS',
                'longitude': 'Longitude GPS',
              },
              'common': {
                'not_provided': 'Non renseigné',
                'unknown': 'Inconnue',
              },
              'artisan': {
                'metrics_title': 'Vue d\'ensemble',
                'metrics_subtitle': 'Repères métier utiles au profil public',
                'identity_title': 'Identité et contact',
                'identity_subtitle': 'Informations de base de l\'artisan',
                'trade_title': 'Métier et présence',
                'trade_subtitle': 'Spécialité, catégorie et canal WhatsApp',
                'location_title': 'Coordonnées professionnelles',
                'location_subtitle':
                    'Données GPS, zone déclarée et cohérence de visibilité',
                'location_missing':
                    'Les coordonnées GPS ne sont pas encore synchronisées.',
                'location_ok':
                    'Coordonnées GPS disponibles. Dernière mise à jour: {date}.',
                'location_warning':
                    'La visibilité publique dépend d\'une localisation GPS valide et d\'un profil rendu disponible.',
                'professional_info_title': 'Informations professionnelles',
                'professional_info_subtitle':
                    'Présentation, disponibilité et état d\'abonnement',
                'visible_now': 'Profil actuellement visible',
                'not_visible_now': 'Profil non visible pour l\'instant',
                'subscription_active': 'Abonnement actif',
                'subscription_inactive': 'Abonnement inactif',
                'card_title': 'Carte professionnelle',
                'card_subtitle':
                    'Carte visuelle animée, pensée pour le partage en image',
                'share_card': 'Partager l\'image',
                'share_caption': 'Carte professionnelle de {name} • {trade}',
                'share_error':
                    'Impossible de générer ou partager la carte professionnelle.',
                'card_experience': '{years} ans d\'expérience',
                'card_verified':
                    'Profil vérifié dans l\'écosystème Fiers Artisans.',
                'card_pending': 'Profil non encore marqué comme vérifié.',
              },
            },
          }),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: AppTheme.light(),
              home: const MyArtisanProfileScreen(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Awa Konan'), findsWidgets);
    expect(find.text('Carte professionnelle'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
