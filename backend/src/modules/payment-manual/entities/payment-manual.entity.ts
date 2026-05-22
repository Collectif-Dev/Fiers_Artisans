import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  OneToMany,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  Index,
} from 'typeorm';
import { Subscription } from '../../subscription/entities/subscription.entity';
import { PaymentProof } from './payment-proof.entity';

export enum PaymentProviderManual {
  WAVE = 'WAVE',
  ORANGE_MONEY = 'ORANGE_MONEY',
  MTN_MOMO = 'MTN_MOMO',
  MOOV_MONEY = 'MOOV_MONEY',
}

export enum PaymentManualStatus {
  PENDING = 'PENDING',
  PENDING_ADMIN = 'PENDING_ADMIN',
  COMPLETED = 'COMPLETED',
  REJECTED = 'REJECTED',
  EXPIRED = 'EXPIRED',
}

@Index('IDX_PAYMENT_MANUAL_SUB_CREATED', ['subscription_id', 'created_at'])
@Index('IDX_PAYMENT_MANUAL_SUB_REQUEST', ['subscription_id', 'request_number'])
@Index('IDX_PAYMENT_MANUAL_STATUS_EXPIRES', ['status', 'expires_at_admin'])
@Entity('payment_manual')
export class PaymentManual {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Subscription, (subscription) => subscription.payment_manuals)
  @JoinColumn({ name: 'subscription_id' })
  subscription: Subscription;

  @Column()
  subscription_id: string;

  @Column({ unique: true })
  transaction_id: string;

  @Column({ type: 'int' })
  amount_fcfa: number;

  @Column({
    type: 'enum',
    enum: PaymentProviderManual,
    enumName: 'payment_provider_manual',
  })
  provider: PaymentProviderManual;

  @Column({
    type: 'enum',
    enum: PaymentManualStatus,
    enumName: 'payment_manual_status',
    default: PaymentManualStatus.PENDING,
  })
  status: PaymentManualStatus;

  @Column({ type: 'varchar', nullable: true })
  sender_number: string | null;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;

  @Column({ type: 'timestamp', nullable: true })
  expires_at_admin: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  validated_at: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  rejected_at: Date | null;

  @Column({ type: 'text', nullable: true })
  rejection_reason: string | null;

  @Column({ type: 'int', default: 1 })
  request_number: number;

  @Column({ default: false })
  refund_required: boolean;

  @Column({ type: 'timestamp', nullable: true })
  refund_done_at: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  cooldown_until: Date | null;

  @Column({ type: 'int', default: 0 })
  cooldown_cycle: number;

  @Column({ type: 'int', default: 0 })
  attempted_refund_count: number;

  @Column({ type: 'jsonb', default: () => "'[]'::jsonb" })
  timeline: Record<string, unknown>[];

  @DeleteDateColumn({ nullable: true })
  deleted_at: Date | null;

  @OneToMany(() => PaymentProof, (proof) => proof.payment_manual)
  proofs: PaymentProof[];
}
