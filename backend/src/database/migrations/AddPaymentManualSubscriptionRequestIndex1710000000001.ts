import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPaymentManualSubscriptionRequestIndex1710000000001
  implements MigrationInterface
{
  name = 'AddPaymentManualSubscriptionRequestIndex1710000000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_payment_manual_sub_request
      ON payment_manual(subscription_id, request_number)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS idx_payment_manual_sub_request
    `);
  }
}
