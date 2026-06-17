import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePaymentManual1699999999999 implements MigrationInterface {
  name = 'CreatePaymentManual1699999999999';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE payment_provider_manual AS ENUM (
        'WAVE',
        'ORANGE_MONEY',
        'MTN_MOMO',
        'MOOV_MONEY'
      )
    `);

    await queryRunner.query(`
      CREATE TYPE payment_manual_status AS ENUM (
        'PENDING',
        'PENDING_ADMIN',
        'COMPLETED',
        'REJECTED',
        'EXPIRED'
      )
    `);

    await queryRunner.query(`
      CREATE TABLE payment_manual (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
        transaction_id VARCHAR(64) NOT NULL UNIQUE,
        amount_fcfa INT NOT NULL CHECK (amount_fcfa > 0),
        provider payment_provider_manual NOT NULL,
        status payment_manual_status NOT NULL DEFAULT 'PENDING',
        sender_number VARCHAR(20),
        created_at TIMESTAMP NOT NULL DEFAULT now(),
        updated_at TIMESTAMP NOT NULL DEFAULT now(),
        expires_at_admin TIMESTAMP,
        validated_at TIMESTAMP,
        rejected_at TIMESTAMP,
        rejection_reason TEXT,
        refund_required BOOLEAN NOT NULL DEFAULT false,
        refund_done_at TIMESTAMP,
        attempted_refund_count INT NOT NULL DEFAULT 0,
        timeline JSONB NOT NULL DEFAULT '[]'::jsonb,
        deleted_at TIMESTAMP,
        CONSTRAINT chk_payment_manual_sender_number
          CHECK (sender_number IS NULL OR sender_number ~ '^[0-9]{8,14}$')
      )
    `);

    await queryRunner.query(`
      CREATE TABLE payment_proof (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        payment_manual_id UUID NOT NULL REFERENCES payment_manual(id) ON DELETE CASCADE,
        image_url TEXT NOT NULL,
        image_hash_sha256 VARCHAR(64) NOT NULL UNIQUE,
        submitted_at TIMESTAMP NOT NULL DEFAULT now(),
        declared_payment_time TIMESTAMP,
        upload_attempt_number INT NOT NULL DEFAULT 1,
        file_type VARCHAR(32),
        file_size_kb INT,
        file_resolution VARCHAR(32),
        has_exif BOOLEAN NOT NULL DEFAULT false,
        exif_capture_date TIMESTAMP,
        exif_modified_date TIMESTAMP,
        exif_device VARCHAR(255),
        exif_software VARCHAR(255),
        ai_suspicion_score NUMERIC(4,3) NOT NULL DEFAULT 0,
        is_suspected_fraud BOOLEAN NOT NULL DEFAULT false,
        deletion_requested BOOLEAN NOT NULL DEFAULT false,
        deleted_at TIMESTAMP,
        CONSTRAINT chk_payment_proof_upload_attempt CHECK (upload_attempt_number BETWEEN 1 AND 3),
        CONSTRAINT chk_payment_proof_hash_len CHECK (char_length(image_hash_sha256) = 64)
      )
    `);

    await queryRunner.query(`
      CREATE INDEX idx_payment_manual_sub_created ON payment_manual(subscription_id, created_at DESC)
    `);
    await queryRunner.query(`
      CREATE INDEX idx_payment_manual_status_expires ON payment_manual(status, expires_at_admin)
    `);
    await queryRunner.query(`
      CREATE INDEX idx_payment_manual_refund_required ON payment_manual(refund_required)
    `);

    await queryRunner.query(`
      CREATE INDEX idx_payment_proof_payment_submitted ON payment_proof(payment_manual_id, submitted_at DESC)
    `);
    await queryRunner.query(`
      CREATE INDEX idx_payment_proof_suspected_fraud ON payment_proof(is_suspected_fraud)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS idx_payment_proof_suspected_fraud`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS idx_payment_proof_payment_submitted`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS idx_payment_manual_refund_required`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS idx_payment_manual_status_expires`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS idx_payment_manual_sub_created`,
    );

    await queryRunner.query(`DROP TABLE IF EXISTS payment_proof`);
    await queryRunner.query(`DROP TABLE IF EXISTS payment_manual`);

    await queryRunner.query(`DROP TYPE IF EXISTS payment_manual_status`);
    await queryRunner.query(`DROP TYPE IF EXISTS payment_provider_manual`);
  }
}
