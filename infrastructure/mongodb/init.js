// ══════════════════════════════════════════════════════════════════════
// Fiers Artisans — MongoDB Init Script
// Index et configuration initiale des collections
// ══════════════════════════════════════════════════════════════════════

const db = db.getSiblingDB('fiers_artisans');

// ── Collection : messages ─────────────────────────────────────────────
db.createCollection('messages');
db.messages.createIndex({ conversationId: 1, sentAt: -1 });
db.messages.createIndex({ senderId: 1 });

// ── Collection : conversations ────────────────────────────────────────
db.createCollection('conversations');
db.conversations.createIndex({ participants: 1 });
db.conversations.createIndex({ updatedAt: -1 });

// ── Collection : portfolio_items ──────────────────────────────────────
db.createCollection('portfolio_items');
db.portfolio_items.createIndex({ artisanProfileId: 1, createdAt: -1 });
db.portfolio_items.createIndex({ tags: 1 });

// ── Collection : notifications ────────────────────────────────────────
db.createCollection('notifications');
db.notifications.createIndex({ userId: 1, createdAt: -1 });
db.notifications.createIndex({ userId: 1, isRead: 1 });
// TTL : suppression automatique après 30 jours
db.notifications.createIndex({ expireAt: 1 }, { expireAfterSeconds: 0 });

// ── Collection : activity_logs ────────────────────────────────────────
db.createCollection('activity_logs');
db.activity_logs.createIndex({ actorId: 1, timestamp: -1 });
db.activity_logs.createIndex({ action: 1, timestamp: -1 });
// TTL : suppression automatique après 90 jours
db.activity_logs.createIndex({ timestamp: 1 }, { expireAfterSeconds: 7776000 });

print('✅ MongoDB initialized: collections + indexes created');
