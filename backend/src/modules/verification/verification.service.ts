import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Subject, Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import {
  VerificationDocument,
  DocumentType,
  DocumentStatus,
} from './entities/verification-document.entity';
import {
  VerificationDocumentPage,
  PageRole,
} from './entities/verification-document-page.entity';
import { User, VerificationStatus } from '../users/entities/user.entity';
import { SubmitDocumentDto } from './dto/submit-document.dto';
import { ReviewDocumentDto } from './dto/review-document.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { AdminRealtimeService } from '../../common/realtime/admin-realtime.service';
import { ChatGateway } from '../chat/chat.gateway';

const IDENTITY_TYPES = [DocumentType.CNI, DocumentType.PASSPORT];
const DIPLOMA_TYPES = [
  DocumentType.DIPLOME,
  DocumentType.CERTIFICAT,
  DocumentType.ATTESTATION,
];

@Injectable()
export class VerificationService {
  constructor(
    @InjectRepository(VerificationDocument)
    private readonly docRepository: Repository<VerificationDocument>,
    @InjectRepository(VerificationDocumentPage)
    private readonly pageRepository: Repository<VerificationDocumentPage>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly notificationsService: NotificationsService,
    private readonly adminRealtimeService: AdminRealtimeService,
    private readonly chatGateway: ChatGateway,
  ) {}

  /** Emits on new submissions and reviews — admin SSE subscribes to this. */
  private readonly _docEvents$ = new Subject<{ type: string; documentId: string }>();

  /** SSE stream for admin: emits MessageEvents on document changes. */
  get docEvents$(): Observable<MessageEvent> {
    return this._docEvents$.pipe(
      map(
        (payload) =>
          ({ data: payload }) as MessageEvent,
      ),
    );
  }

  private getFamilyTypes(docType: DocumentType): DocumentType[] {
    if (IDENTITY_TYPES.includes(docType)) return IDENTITY_TYPES;
    if (DIPLOMA_TYPES.includes(docType)) return DIPLOMA_TYPES;
    return [docType];
  }

  /**
   * Prevents duplicate active submissions within the same document family.
   * Identity family: CNI, PASSPORT
   * Diploma family: DIPLOME, CERTIFICAT, ATTESTATION
   */
  private async guardDuplicatePending(
    userId: string,
    docType: DocumentType,
  ): Promise<void> {
    const familyTypes = this.getFamilyTypes(docType);
    const existing = await this.docRepository.findOne({
      where: {
        user_id: userId,
        document_type: In(familyTypes),
        status: DocumentStatus.PENDING,
      },
    });
    if (existing) {
      const label = IDENTITY_TYPES.includes(docType)
        ? "d'identité"
        : 'de diplôme/certificat';
      throw new ConflictException(
        `Vous avez déjà un dossier ${label} en attente de validation. Veuillez patienter.`,
      );
    }
  }

  async submitDocument(
    userId: string,
    dto: SubmitDocumentDto,
  ): Promise<VerificationDocument> {
    // Prevent duplicate PENDING submissions within the same family
    await this.guardDuplicatePending(userId, dto.document_type);

    const files = dto.files;
    const legacyFileUrl = dto.file_url;

    // Backwards-compatible: if old-style single file_url is sent without files[]
    if (!files?.length && legacyFileUrl) {
      const role = this.getDefaultRole(dto.document_type);
      const objectKey = this.extractObjectKey(legacyFileUrl);
      const doc = this.docRepository.create({
        user_id: userId,
        document_type: dto.document_type,
        file_url: legacyFileUrl,
        object_key: objectKey,
      });
      const saved = await this.docRepository.save(doc);
      const page = this.pageRepository.create({
        document_id: saved.id,
        file_url: legacyFileUrl,
        object_key: objectKey,
        page_role: role,
        page_order: 0,
      });
      await this.pageRepository.save(page);
      this._docEvents$.next({ type: 'DOCUMENT_SUBMITTED', documentId: saved.id });
      this.adminRealtimeService.emit('VERIFICATION_SUBMITTED', {
        documentId: saved.id,
        userId,
        documentType: dto.document_type,
      });
      this.chatGateway
        .emitUserSyncEvent(userId, 'verificationStatusUpdated', {
          documentId: saved.id,
          documentType: dto.document_type,
          status: DocumentStatus.PENDING,
          updatedAt: new Date().toISOString(),
        })
        .catch(() => {});
      return this.docRepository.findOne({
        where: { id: saved.id },
        relations: ['pages'],
      }) as Promise<VerificationDocument>;
    }

    if (!files?.length) {
      throw new BadRequestException(
        'Au moins un fichier est requis.',
      );
    }

    // Business validation per document type
    this.validateFiles(dto.document_type, files);

    const firstKey =
      files[0].object_key || this.extractObjectKey(files[0].file_url);

    const doc = this.docRepository.create({
      user_id: userId,
      document_type: dto.document_type,
      file_url: files[0].file_url,
      object_key: firstKey,
    });
    const saved = await this.docRepository.save(doc);

    const pages = files.map((f, idx) =>
      this.pageRepository.create({
        document_id: saved.id,
        file_url: f.file_url,
        object_key: f.object_key || this.extractObjectKey(f.file_url),
        page_role: f.page_role,
        page_order: f.page_order ?? idx,
      }),
    );
    await this.pageRepository.save(pages);

    this._docEvents$.next({ type: 'DOCUMENT_SUBMITTED', documentId: saved.id });
    this.adminRealtimeService.emit('VERIFICATION_SUBMITTED', {
      documentId: saved.id,
      userId,
      documentType: dto.document_type,
    });
    this.chatGateway
      .emitUserSyncEvent(userId, 'verificationStatusUpdated', {
        documentId: saved.id,
        documentType: dto.document_type,
        status: DocumentStatus.PENDING,
        updatedAt: new Date().toISOString(),
      })
      .catch(() => {});

    return this.docRepository.findOne({
      where: { id: saved.id },
      relations: ['pages'],
    }) as Promise<VerificationDocument>;
  }

  /**
   * Extract MinIO objectKey from a signed URL.
   * URL format: http://host:port/bucket/objectKey?params
   */
  private extractObjectKey(fileUrl: string): string | undefined {
    try {
      const url = new URL(fileUrl);
      // pathname = /documents/uuid.ext or /bucket/key
      const parts = url.pathname.split('/').filter(Boolean);
      // parts = ['documents', 'uuid.ext']
      if (parts.length >= 2) {
        return parts.slice(1).join('/');
      }
      return undefined;
    } catch {
      return undefined;
    }
  }

  private validateFiles(
    docType: DocumentType,
    files: { file_url: string; page_role: PageRole }[],
  ): void {
    const roles = files.map((f) => f.page_role);

    switch (docType) {
      case DocumentType.CNI: {
        const hasFront = roles.includes(PageRole.FRONT);
        const hasBack = roles.includes(PageRole.BACK);
        if (!hasFront || !hasBack) {
          throw new BadRequestException(
            'La CNI nécessite obligatoirement un recto (FRONT) et un verso (BACK).',
          );
        }
        break;
      }
      case DocumentType.PASSPORT: {
        const hasMain = roles.includes(PageRole.MAIN);
        if (!hasMain) {
          throw new BadRequestException(
            'Le passeport nécessite au moins une page principale (MAIN).',
          );
        }
        break;
      }
      case DocumentType.DIPLOME:
      case DocumentType.CERTIFICAT:
      case DocumentType.ATTESTATION: {
        const hasMain = roles.includes(PageRole.MAIN);
        if (!hasMain) {
          throw new BadRequestException(
            'Ce document nécessite au moins une page principale (MAIN).',
          );
        }
        break;
      }
    }
  }

  private getDefaultRole(docType: DocumentType): PageRole {
    switch (docType) {
      case DocumentType.CNI:
        return PageRole.FRONT;
      case DocumentType.PASSPORT:
      case DocumentType.DIPLOME:
      case DocumentType.CERTIFICAT:
      case DocumentType.ATTESTATION:
        return PageRole.MAIN;
    }
  }

  async getVerificationStatus(userId: string) {
    const documents = await this.docRepository.find({
      where: { user_id: userId },
      relations: ['pages'],
      order: { submitted_at: 'DESC' },
    });
    const user = await this.userRepository.findOne({ where: { id: userId } });
    return {
      verification_status: user!.verification_status,
      documents,
    };
  }

  async getPendingDocuments() {
    return this.docRepository.find({
      where: { status: DocumentStatus.PENDING },
      relations: ['user', 'pages'],
      order: { submitted_at: 'ASC' },
    });
  }

  async countPendingDocuments(): Promise<number> {
    return this.docRepository.count({
      where: { status: DocumentStatus.PENDING },
    });
  }

  async getPendingDocumentsPaginated(page = 1, limit = 20) {
    const safePage = Number.isFinite(page) ? Math.max(1, Math.floor(page)) : 1;
    const safeLimit = Number.isFinite(limit)
      ? Math.min(100, Math.max(1, Math.floor(limit)))
      : 20;

    const [data, total] = await this.docRepository.findAndCount({
      where: { status: DocumentStatus.PENDING },
      relations: ['user', 'pages'],
      order: { submitted_at: 'ASC' },
      skip: (safePage - 1) * safeLimit,
      take: safeLimit,
    });

    return {
      data,
      total,
      page: safePage,
      limit: safeLimit,
    };
  }

  async reviewDocument(
    docId: string,
    adminId: string,
    dto: ReviewDocumentDto,
  ): Promise<VerificationDocument> {
    const doc = await this.docRepository.findOne({
      where: { id: docId },
      relations: ['user', 'pages'],
    });
    if (!doc) {
      throw new NotFoundException('Document non trouvé.');
    }
    if (doc.status !== DocumentStatus.PENDING) {
      throw new BadRequestException('Ce document a déjà été traité.');
    }

    // Block approval of incomplete CNI
    if (
      dto.status === DocumentStatus.APPROVED &&
      doc.document_type === DocumentType.CNI
    ) {
      const pageRoles = (doc.pages || []).map((p) => p.page_role);
      if (
        !pageRoles.includes(PageRole.FRONT) ||
        !pageRoles.includes(PageRole.BACK)
      ) {
        throw new BadRequestException(
          'Impossible d\'approuver une CNI incomplète (recto et verso requis).',
        );
      }
    }

    doc.status = dto.status;
    doc.reviewed_by = adminId;
    doc.reviewed_at = new Date();
    if (dto.status === DocumentStatus.REJECTED) {
      if (!dto.rejection_reason?.trim()) {
        throw new BadRequestException(
          'Le motif de rejet est obligatoire.',
        );
      }
      doc.rejection_reason = dto.rejection_reason.trim();
    }

    const saved = await this.docRepository.save(doc);

    if (dto.status === DocumentStatus.APPROVED) {
      await this.updateUserVerificationStatus(doc.user_id);
    }

    // Notify artisan via FCM (fire-and-forget)
    const notifType =
      dto.status === DocumentStatus.APPROVED
        ? 'DOCUMENT_APPROVED'
        : 'DOCUMENT_REJECTED';
    const notifTitle =
      dto.status === DocumentStatus.APPROVED
        ? 'Document approuvé'
        : 'Document rejeté';
    const notifBody =
      dto.status === DocumentStatus.APPROVED
        ? `Votre ${doc.document_type} a été approuvé.`
        : `Votre ${doc.document_type} a été rejeté.`;
    this.notificationsService
      .create({
        userId: doc.user_id,
        type: notifType,
        title: notifTitle,
        body: notifBody,
        data: { documentId: doc.id, documentType: doc.document_type },
      })
      .catch(() => {});

    this._docEvents$.next({ type: 'DOCUMENT_REVIEWED', documentId: doc.id });
    this.adminRealtimeService.emit('VERIFICATION_REVIEWED', {
      documentId: doc.id,
      userId: doc.user_id,
      status: dto.status,
      documentType: doc.document_type,
    });
    this.chatGateway
      .emitUserSyncEvent(doc.user_id, 'verificationStatusUpdated', {
        documentId: doc.id,
        documentType: doc.document_type,
        status: dto.status,
        updatedAt: new Date().toISOString(),
      })
      .catch(() => {});

    return saved;
  }

  private async updateUserVerificationStatus(userId: string): Promise<void> {
    const docs = await this.docRepository.find({
      where: { user_id: userId, status: DocumentStatus.APPROVED },
    });

    const hasCNI = docs.some(
      (d) => d.document_type === 'CNI' || d.document_type === 'PASSPORT',
    );
    const hasDiploma = docs.some(
      (d) =>
        d.document_type === 'DIPLOME' ||
        d.document_type === 'CERTIFICAT' ||
        d.document_type === 'ATTESTATION',
    );

    let newStatus = VerificationStatus.PENDING;
    if (hasCNI && hasDiploma) {
      newStatus = VerificationStatus.CERTIFIED;
    } else if (hasCNI) {
      newStatus = VerificationStatus.VERIFIED;
    }

    await this.userRepository.update(userId, {
      verification_status: newStatus,
    });
  }
}
