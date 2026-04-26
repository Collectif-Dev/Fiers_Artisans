import { IsEnum, IsNotEmpty, IsOptional, IsString, ValidateIf } from 'class-validator';
import { DocumentStatus } from '../entities/verification-document.entity';

export class ReviewDocumentDto {
  @IsEnum([DocumentStatus.APPROVED, DocumentStatus.REJECTED])
  status: DocumentStatus;

  @ValidateIf((o) => o.status === DocumentStatus.REJECTED)
  @IsNotEmpty({ message: 'Le motif de rejet est obligatoire.' })
  @IsString()
  rejection_reason?: string;
}
