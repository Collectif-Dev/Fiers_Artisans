import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  OneToOne,
  JoinColumn,
  ManyToOne,
  OneToMany,
  OneToMany as OneToManyReviews,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';
import { User } from './user.entity';
import { Category } from '../../categories/entities/category.entity';
import { Subcategory } from '../../categories/entities/subcategory.entity';
import { Subscription } from '../../subscription/entities/subscription.entity';
import { Review } from '../../reviews/entities/review.entity';

@Index('IDX_ARTISAN_SEARCH_FILTERS', [
  'is_subscription_active',
  'is_available',
  'category_id',
  'subcategory_id',
])
@Index('IDX_ARTISAN_SEARCH_RATING', ['rating_avg'])
@Entity('artisan_profiles')
export class ArtisanProfile {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @OneToOne(() => User, (user) => user.artisan_profile)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column()
  user_id: string;

  @Column()
  first_name: string;

  @Column()
  last_name: string;

  @Column({ nullable: true })
  business_name: string;

  @Column({ type: 'text', nullable: true })
  bio: string;

  @ManyToOne(() => Category, { eager: true })
  @JoinColumn({ name: 'category_id' })
  category: Category;

  @Column({ nullable: true })
  @Index()
  category_id: string;

  @ManyToOne(() => Subcategory, { eager: true, nullable: true })
  @JoinColumn({ name: 'subcategory_id' })
  subcategory: Subcategory;

  @Column({ nullable: true })
  @Index()
  subcategory_id: string;

  @Column({ nullable: true })
  city: string;

  @Column({ nullable: true })
  commune: string;

  @Column({ nullable: true })
  address: string;

  @Column({ type: 'float', default: 0 })
  rating_avg: number;

  @Column({ type: 'int', default: 0 })
  total_reviews: number;

  @Column({ type: 'int', default: 0 })
  years_experience: number;

  @Column({ default: true })
  is_available: boolean;

  @Column({ default: false })
  @Index()
  is_subscription_active: boolean;

  @Column({ nullable: true })
  whatsapp_number: string;

  @Column({ type: 'jsonb', nullable: true })
  working_hours: Record<string, any>;

  @Column({ nullable: true })
  last_active_at: Date;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;

  @OneToOne(() => Subscription, (sub) => sub.artisan_profile, {
    nullable: true,
  })
  subscription: Subscription;

  @OneToMany(() => Review, (review) => review.artisan)
  reviews: Review[];
}
