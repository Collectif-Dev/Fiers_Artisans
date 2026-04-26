import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  OneToOne,
  JoinColumn,
  OneToMany,
  CreateDateColumn,
} from 'typeorm';
import { ArtisanProfile } from '../../users/entities/artisan-profile.entity';
import { Payment } from './payment.entity';

export enum SubscriptionPlan {
  MONTHLY = 'MONTHLY',
}

export enum SubscriptionStatus {
  ACTIVE = 'ACTIVE',
  EXPIRED = 'EXPIRED',
  CANCELLED = 'CANCELLED',
  PENDING = 'PENDING',
}

@Entity('subscriptions')
export class Subscription {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @OneToOne(() => ArtisanProfile, (ap) => ap.subscription)
  @JoinColumn({ name: 'artisan_profile_id' })
  artisan_profile: ArtisanProfile;

  @Column()
  artisan_profile_id: string;

  @Column({ type: 'enum', enum: SubscriptionPlan, default: SubscriptionPlan.MONTHLY })
  plan: SubscriptionPlan;

  @Column({ type: 'int', default: 5000 })
  amount_fcfa: number;

  @Column({ type: 'enum', enum: SubscriptionStatus, default: SubscriptionStatus.PENDING })
  status: SubscriptionStatus;

  @Column({ nullable: true })
  starts_at: Date;

  @Column({ nullable: true })
  expires_at: Date;

  @Column({ default: false })
  auto_renew: boolean;

  @CreateDateColumn()
  created_at: Date;

  @OneToMany(() => Payment, (payment) => payment.subscription)
  payments: Payment[];
}
