import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  OneToMany,
} from 'typeorm';
import { Subcategory } from './subcategory.entity';

@Entity('categories')
export class Category {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ nullable: true })
  icon_url: string;

  @Column({ unique: true })
  slug: string;

  @Column({ default: true })
  is_active: boolean;

  @Column({ type: 'int', default: 0 })
  display_order: number;

  @OneToMany(() => Subcategory, (sub) => sub.category)
  subcategories: Subcategory[];
}
