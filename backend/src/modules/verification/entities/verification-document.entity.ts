import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  OneToMany,
  JoinColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { VerificationDocumentPage } from './verification-document-page.entity';

export enum DocumentType {
  CNI = 'CNI',
  PASSPORT = 'PASSPORT',
  DIPLOME = 'DIPLOME',
  CERTIFICAT = 'CERTIFICAT',
  ATTESTATION = 'ATTESTATION',
}

export enum DocumentStatus {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
}

@Index('IDX_VERIFICATION_STATUS_SUBMITTED_AT', ['status', 'submitted_at'])
@Index('IDX_VERIFICATION_USER_STATUS', ['user_id', 'status'])
@Entity('verification_documents')
export class VerificationDocument {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => User, (user) => user.verification_documents)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column()
  user_id: string;

  @Column({ type: 'enum', enum: DocumentType })
  document_type: DocumentType;

  @Column({ nullable: true })
  file_url: string;

  @Column({ nullable: true })
  object_key: string;

  @OneToMany(() => VerificationDocumentPage, (page) => page.document, {
    cascade: true,
    eager: true,
  })
  pages: VerificationDocumentPage[];

  @Column({
    type: 'enum',
    enum: DocumentStatus,
    default: DocumentStatus.PENDING,
  })
  status: DocumentStatus;

  @Column({ nullable: true })
  rejection_reason: string;

  @Column({ nullable: true })
  reviewed_by: string;

  @CreateDateColumn()
  submitted_at: Date;

  @Column({ nullable: true })
  reviewed_at: Date;
}
