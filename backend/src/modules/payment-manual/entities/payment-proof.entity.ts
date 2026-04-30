import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  DeleteDateColumn,
  Index,
} from 'typeorm';
import { PaymentManual } from './payment-manual.entity';

@Index('IDX_PAYMENT_PROOF_PAYMENT_SUBMITTED', ['payment_manual_id', 'submitted_at'])
@Entity('payment_proof')
export class PaymentProof {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => PaymentManual, (payment) => payment.proofs)
  @JoinColumn({ name: 'payment_manual_id' })
  payment_manual: PaymentManual;

  @Column()
  payment_manual_id: string;

  @Column({ type: 'text' })
  image_url: string;

  @Column({ unique: true })
  image_hash_sha256: string;

  @CreateDateColumn()
  submitted_at: Date;

  @Column({ type: 'timestamp', nullable: true })
  declared_payment_time: Date | null;

  @Column({ type: 'int', default: 1 })
  upload_attempt_number: number;

  @Column({ type: 'varchar', nullable: true })
  file_type: string | null;

  @Column({ type: 'int', nullable: true })
  file_size_kb: number | null;

  @Column({ type: 'varchar', nullable: true })
  file_resolution: string | null;

  @Column({ default: false })
  has_exif: boolean;

  @Column({ type: 'timestamp', nullable: true })
  exif_capture_date: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  exif_modified_date: Date | null;

  @Column({ type: 'varchar', nullable: true })
  exif_device: string | null;

  @Column({ type: 'varchar', nullable: true })
  exif_software: string | null;

  @Column({ type: 'float', default: 0 })
  ai_suspicion_score: number;

  @Column({ default: false })
  is_suspected_fraud: boolean;

  @Column({ default: false })
  deletion_requested: boolean;

  @DeleteDateColumn({ nullable: true })
  deleted_at: Date | null;
}
