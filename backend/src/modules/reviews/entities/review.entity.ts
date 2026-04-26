import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  Index,
  Unique,
} from 'typeorm';
import { ArtisanProfile } from '../../users/entities/artisan-profile.entity';
import { ClientProfile } from '../../users/entities/client-profile.entity';

@Entity('reviews')
@Unique(['client_id', 'artisan_id'])
export class Review {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => ClientProfile, (client) => client.reviews)
  @JoinColumn({ name: 'client_id' })
  client: ClientProfile;

  @Column()
  @Index()
  client_id: string;

  @ManyToOne(() => ArtisanProfile, (artisan) => artisan.reviews)
  @JoinColumn({ name: 'artisan_id' })
  artisan: ArtisanProfile;

  @Column()
  @Index()
  artisan_id: string;

  @Column({ type: 'int' })
  rating: number;

  @Column({ type: 'text', nullable: true })
  comment: string;

  @Column({ type: 'text', nullable: true })
  artisan_reply: string | null;

  @Column({ type: 'timestamp', nullable: true })
  artisan_reply_at: Date | null;

  @CreateDateColumn()
  created_at: Date;
}
