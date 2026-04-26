import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  Unique,
  Index,
} from 'typeorm';
import { ClientProfile } from './client-profile.entity';
import { ArtisanProfile } from './artisan-profile.entity';

@Entity('favorite_artisans')
@Unique('UQ_favorite_client_artisan', ['client_profile_id', 'artisan_profile_id'])
export class FavoriteArtisan {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  @Index('IDX_favorite_client_profile')
  client_profile_id!: string;

  @Column()
  @Index('IDX_favorite_artisan_profile')
  artisan_profile_id!: string;

  @ManyToOne(() => ClientProfile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'client_profile_id' })
  client_profile!: ClientProfile;

  @ManyToOne(() => ArtisanProfile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'artisan_profile_id' })
  artisan_profile!: ArtisanProfile;

  @CreateDateColumn()
  created_at!: Date;
}
