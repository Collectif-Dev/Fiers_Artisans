import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';
import { Subscription } from './subscription.entity';

export enum PaymentProvider {
  WAVE = 'WAVE',
}

export enum PaymentStatus {
  PENDING = 'PENDING',
  SUCCESS = 'SUCCESS',
  FAILED = 'FAILED',
}

@Index('IDX_PAYMENTS_STATUS_PAID_AT', ['status', 'paid_at'])
@Index('IDX_PAYMENTS_SUB_STATUS_CREATED', ['subscription_id', 'status', 'created_at'])
@Entity('payments')
export class Payment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Subscription, (sub) => sub.payments)
  @JoinColumn({ name: 'subscription_id' })
  subscription: Subscription;

  @Column()
  subscription_id: string;

  @Column({ type: 'int' })
  amount_fcfa: number;

  @Column({ type: 'enum', enum: PaymentProvider, default: PaymentProvider.WAVE })
  provider: PaymentProvider;

  @Column({ type: 'enum', enum: PaymentStatus, default: PaymentStatus.PENDING })
  status: PaymentStatus;

  @Column({ nullable: true, unique: true })
  wave_transaction_id: string;

  @Column({ nullable: true })
  wave_checkout_id: string;

  @Column({ nullable: true })
  paid_at: Date;

  @CreateDateColumn()
  created_at: Date;
}
