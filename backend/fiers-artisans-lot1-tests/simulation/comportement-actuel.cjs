'use strict';
// Reproduction ISOLEE de la méthode getArtisanPublicProfile du commit b55fccba.
// N'est NI l'application NestJS NI un test du serveur HTTP réel.
class NotFoundException extends Error { constructor(message){ super(message); this.status=404; }}
class ExtraitUsersService {
  constructor(artisanProfileRepository, analyticsService) {
    this.artisanProfileRepository = artisanProfileRepository;
    this.analyticsService = analyticsService;
  }
  async attachLocationSnapshot(profile) { return { ...profile, latitude: 5.35, longitude: -3.98 }; }
  async getArtisanPublicProfile(artisanId) {
    // Corps fidèle à users.service.ts lignes 175-200, sans types TS.
    let profile = await this.artisanProfileRepository.findOne({
      where: { id: artisanId, is_subscription_active: true },
      relations: ['category', 'subcategory', 'user'],
    });
    if (!profile) {
      profile = await this.artisanProfileRepository.findOne({
        where: { user: { id: artisanId }, is_subscription_active: true },
        relations: ['category', 'subcategory', 'user'],
      });
    }
    if (!profile) throw new NotFoundException('Artisan non trouvé ou non actif.');
    this.analyticsService.logActivity({
      actorId: 'anonymous', action: 'PROFILE_VIEW', targetId: profile.id,
    }).catch(() => {});
    return this.attachLocationSnapshot(profile);
  }
}
function enveloppeHttpSimulation(resultat) {
  // Reproduction de l'enveloppe JSON du TransformInterceptor.
  return JSON.parse(JSON.stringify({statusCode:200,data:resultat,timestamp:'2026-11-02T00:00:00.000Z'}));
}
module.exports = { ExtraitUsersService, NotFoundException, enveloppeHttpSimulation };
