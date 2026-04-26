import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
} from 'typeorm';
import { VerificationDocument } from './verification-document.entity';

export enum PageRole {
  FRONT = 'FRONT',
  BACK = 'BACK',
  MAIN = 'MAIN',
  EXTRA = 'EXTRA',
}

@Entity('verification_document_pages')
export class VerificationDocumentPage {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => VerificationDocument, (doc) => doc.pages, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'document_id' })
  document: VerificationDocument;

  @Column()
  document_id: string;

  @Column()
  file_url: string;

  @Column({ nullable: true })
  object_key: string;

  @Column({ type: 'enum', enum: PageRole })
  page_role: PageRole;

  @Column({ type: 'int', default: 0 })
  page_order: number;

  @CreateDateColumn()
  created_at: Date;
}
