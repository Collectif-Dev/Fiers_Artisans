'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { ExtraitUsersService, enveloppeHttpSimulation } = require('./comportement-actuel.cjs');
const idProfil = '11111111-1111-4111-8111-111111111111';
const idUtilisateur = '22222222-2222-4222-8222-222222222222';
const fauxProfil = ({ actif=true, abonnement=true }={}) => ({
  id:idProfil, user_id:idUtilisateur, first_name:'Awa', last_name:'Konan',
  is_subscription_active:abonnement, is_available:true,
  user: {id:idUtilisateur,is_active:actif,verification_status:'PENDING',
    pin_hash:'FAUX_HASH_DE_TEST', password_hash:'FAUX_HASH_TEST', fcm_token:'FAUX_FCM_TOKEN_TEST'}
});
function harnais(opts={}) {
  const profil=fauxProfil(opts);
  const repo={findOne:async ({where}) => {
    if(where.id!==undefined && where.id!==profil.id) return null;
    if(where.user?.id!==undefined && where.user.id!==profil.user.id) return null;
    if(where.is_subscription_active!==undefined && where.is_subscription_active!==profil.is_subscription_active) return null;
    if(where.user?.is_active!==undefined && where.user.is_active!==profil.user.is_active) return null;
    return structuredClone(profil);
  }};
  return new ExtraitUsersService(repo,{ logActivity:async()=>{} });
}
test('BASELINE : accepte l ID du profil', async()=>{
  const res=await harnais().getArtisanPublicProfile(idProfil);
  assert.equal(res.id,idProfil);
});
test('BASELINE : accepte l ID utilisateur (Flutter)',async()=>{
  const res=await harnais().getArtisanPublicProfile(idUtilisateur);
  assert.equal(res.user.id,idUtilisateur);
});
test('BASELINE : refuse un profil absent',async()=>{
  await assert.rejects(()=>harnais().getArtisanPublicProfile('id-inconnu'),{status:404});
});
test('CIBLE S01 : le JSON public n expose aucun secret (rouge attendu)',async()=>{
  const payload=enveloppeHttpSimulation(await harnais().getArtisanPublicProfile(idUtilisateur));
  for(const cle of ['pin_hash','password_hash','fcm_token']) {
    assert.equal(Object.hasOwn(payload.data.user,cle),false,`${cle} divulgué dans la réponse simulée`);
  }
});
test('CIBLE S02 : compte désactivé interdit en public (rouge attendu)',async()=>{
  await assert.rejects(()=>harnais({actif:false}).getArtisanPublicProfile(idUtilisateur),{status:404});
});
test('CIBLE V01 : profil accessible sans abonnement (rouge attendu)',async()=>{
  const res=await harnais({abonnement:false}).getArtisanPublicProfile(idUtilisateur);
  assert.equal(res.id,idProfil);
});
