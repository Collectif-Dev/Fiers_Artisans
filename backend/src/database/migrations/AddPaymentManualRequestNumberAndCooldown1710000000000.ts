import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPaymentManualRequestNumberAndCooldown1710000000000 implements MigrationInterface {
  name = 'AddPaymentManualRequestNumberAndCooldown1710000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE payment_manual
      ADD COLUMN request_number INT NOT NULL DEFAULT 1
    `);

    await queryRunner.query(`
      ALTER TABLE payment_manual
      ADD COLUMN cooldown_until TIMESTAMP
    `);

    await queryRunner.query(`
      ALTER TABLE payment_manual
      ADD COLUMN cooldown_cycle INT NOT NULL DEFAULT 0
    `);

    await queryRunner.query(`
      WITH ranked_requests AS (
        SELECT
          id,
          ROW_NUMBER() OVER (
            PARTITION BY subscription_id
            ORDER BY created_at ASC, id ASC
          ) AS request_number
        FROM payment_manual
      )
      UPDATE payment_manual pm
      SET request_number = ranked_requests.request_number
      FROM ranked_requests
      WHERE pm.id = ranked_requests.id
    `);

    await queryRunner.query(`
      CREATE INDEX idx_payment_manual_cooldown_until
      ON payment_manual(cooldown_until)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_payment_manual_cooldown_until
    `);

    await queryRunner.query(`
      ALTER TABLE payment_manual
      DROP COLUMN IF EXISTS cooldown_cycle
    `);

    await queryRunner.query(`
      ALTER TABLE payment_manual
      DROP COLUMN IF EXISTS cooldown_until
    `);

    await queryRunner.query(`
      ALTER TABLE payment_manual
      DROP COLUMN IF EXISTS request_number
    `);
  }
}
