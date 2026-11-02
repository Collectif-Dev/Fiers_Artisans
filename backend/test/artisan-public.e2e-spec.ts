/**
 * LOT 1 — Tests de sécurité et de compatibilité du profil public.
 * Fichier à copier dans backend/test/ sur une copie locale du dépôt.
 * IMPORTANT : tests de cible intentionnellement ROUGES avant correction.
 * Aucune base réelle, aucun fournisseur externe, aucune donnée personnelle réelle.
 */
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import request from 'supertest';
import { UsersService } from '../src/modules/users/users.service';
import { PublicArtisanController } from '../src/modules/users/users.controller';
import { User } from '../src/modules/users/entities/user.entity';
import { ArtisanProfile } from '../src/modules/users/entities/artisan-profile.entity';
import { ClientProfile } from '../src/modules/users/entities/client-profile.entity';
import { FavoriteArtisan } from '../src/modules/users/entities/favorite-artisan.entity';
import { Subcategory } from '../src/modules/categories/entities/subcategory.entity';
import { AnalyticsService } from '../src/modules/analytics/analytics.service';
import { ChatGateway } from '../src/modules/chat/chat.gateway';
import { MapVisibilityGateway } from '../src/modules/users/map-visibility.gateway';
import { AdminRealtimeService } from '../src/common/realtime/admin-realtime.service';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { GlobalExceptionFilter } from '../src/common/filters/global-exception.filter';

const ID_PROFIL = '11111111-1111-4111-8111-111111111111';
const ID_UTILISATEUR = '22222222-2222-4222-8222-222222222222';
const ID_ABSENT = '33333333-3333-4333-8333-333333333333';

function profilFictif(options: { compteActif?: boolean; abonnement?: boolean } = {}) {
  return {
    id: ID_PROFIL,
    user_id: ID_UTILISATEUR,
    first_name: 'Awa',
    last_name: 'Konan',
    category_id: '44444444-4444-4444-8444-444444444444',
    subcategory_id: '55555555-5555-4555-8555-555555555555',
    is_available: true,
    is_subscription_active: options.abonnement ?? true,
    user: {
      id: ID_UTILISATEUR,
      is_active: options.compteActif ?? true,
      is_phone_verified: true,
      verification_status: 'PENDING',
      phone_number: '0700000000',
      pin_hash: '$2b$12$FAUX_HASH_PIN_RESERVE_AUX_TESTS',
      password_hash: 'FAUX_HASH_MOT_DE_PASSE_RESERVE_AUX_TESTS',
      fcm_token: 'FAUX_JETON_NOTIFICATIONS_RESERVE_AUX_TESTS',
    },
  };
}

describe('Lot 1 — GET /api/v1/artisan/:id', () => {
  let app: INestApplication;
  let profil = profilFictif();
  const rechercheProfil = jest.fn();
  const journaliser = jest.fn().mockResolvedValue(undefined);

  beforeAll(async () => {
    const depotProfils = {
      findOne: rechercheProfil.mockImplementation(async ({ where }: any) => {
        if (where?.id !== undefined && where.id !== profil.id) return null;
        if (where?.user?.id !== undefined && where.user.id !== profil.user.id) return null;
        if (where?.is_subscription_active !== undefined &&
            where.is_subscription_active !== profil.is_subscription_active) return null;
        if (where?.user?.is_active !== undefined &&
            where.user.is_active !== profil.user.is_active) return null;
        return structuredClone(profil);
      }),
    };
    const depotUtilisateurs = {
      createQueryBuilder: () => {
        const requete: any = {};
        requete.select = () => requete;
        requete.addSelect = () => requete;
        requete.where = () => requete;
        requete.getRawOne = async () => ({
          latitude: '5.35', longitude: '-3.98', location_updated_at: null,
        });
        return requete;
      },
    };

    const module = await Test.createTestingModule({
      controllers: [PublicArtisanController],
      providers: [
        UsersService,
        { provide: getRepositoryToken(User), useValue: depotUtilisateurs },
        { provide: getRepositoryToken(ArtisanProfile), useValue: depotProfils },
        { provide: getRepositoryToken(ClientProfile), useValue: {} },
        { provide: getRepositoryToken(FavoriteArtisan), useValue: {} },
        { provide: getRepositoryToken(Subcategory), useValue: {} },
        { provide: AnalyticsService, useValue: { logActivity: journaliser } },
        { provide: ChatGateway, useValue: {} },
        { provide: MapVisibilityGateway, useValue: {} },
        { provide: AdminRealtimeService, useValue: {} },
      ],
    }).compile();

    app = module.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.useGlobalInterceptors(new TransformInterceptor());
    app.useGlobalFilters(new GlobalExceptionFilter());
    await app.init();
  });

  beforeEach(() => { profil = profilFictif(); rechercheProfil.mockClear(); });
  afterAll(async () => { await app.close(); });

  it('BASELINE : accepte un ID de profil (HTTP 200)', async () => {
    const r = await request(app.getHttpServer()).get(`/api/v1/artisan/${ID_PROFIL}`);
    expect(r.status).toBe(200);
    expect(r.body.data.id).toBe(ID_PROFIL);
  });

  it('BASELINE : accepte un ID utilisateur (contrat Flutter)', async () => {
    const r = await request(app.getHttpServer()).get(`/api/v1/artisan/${ID_UTILISATEUR}`);
    expect(r.status).toBe(200);
    expect(r.body.data.user_id).toBe(ID_UTILISATEUR);
  });

  it('BASELINE : refuse un ID syntaxiquement invalide (HTTP 400)', async () => {
    const r = await request(app.getHttpServer()).get('/api/v1/artisan/identifiant-invalide');
    expect(r.status).toBe(400);
  });

  it('BASELINE : retourne 404 pour un profil inexistant', async () => {
    const r = await request(app.getHttpServer()).get(`/api/v1/artisan/${ID_ABSENT}`);
    expect(r.status).toBe(404);
  });

  it('CIBLE S01 / SECURITE : ne divulgue jamais les secrets ou champs internes', async () => {
    const r = await request(app.getHttpServer()).get(`/api/v1/artisan/${ID_UTILISATEUR}`);
    expect(r.status).toBe(200);
    const corps = JSON.stringify(r.body);
    for (const nomInterdit of ['pin_hash', 'password_hash', 'fcm_token', 'refresh_token']) {
      expect(corps).not.toContain(`"${nomInterdit}"`);
    }
    expect(r.body.data.user.verification_status).toBe('PENDING');
  });

  it('CIBLE S02 / SECURITE : refuse un profil dont le compte est desactive', async () => {
    profil = profilFictif({ compteActif: false });
    const r = await request(app.getHttpServer()).get(`/api/v1/artisan/${ID_UTILISATEUR}`);
    expect(r.status).toBe(404);
  });

  it('CIBLE V01 / GRATUITE : le profil public fonctionne sans abonnement', async () => {
    profil = profilFictif({ abonnement: false });
    const r = await request(app.getHttpServer()).get(`/api/v1/artisan/${ID_UTILISATEUR}`);
    expect(r.status).toBe(200);
  });
});
