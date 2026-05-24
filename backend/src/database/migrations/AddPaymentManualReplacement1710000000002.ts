import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPaymentManualReplacement1710000000002
  implements MigrationInterface
{
  name = 'AddPaymentManualReplacement1710000000002';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE payment_manual
      ADD COLUMN replaced_by_transaction_id VARCHAR NULL
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_payment_manual_replaced_by
      ON payment_manual(replaced_by_transaction_id)
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_manual_one_pending_per_subscription
      ON payment_manual(subscription_id)
      WHERE status = 'PENDING' AND deleted_at IS NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_payment_manual_one_pending_per_subscription
    `);

    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_payment_manual_replaced_by
    `);

    await queryRunner.query(`
      ALTER TABLE payment_manual
      DROP COLUMN IF EXISTS replaced_by_transaction_id
    `);
  }
}
