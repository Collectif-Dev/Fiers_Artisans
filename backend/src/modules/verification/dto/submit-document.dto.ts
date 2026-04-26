import {
  IsEnum,
  IsString,
  IsOptional,
  IsArray,
  ValidateNested,
  ArrayMinSize,
  IsInt,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { DocumentType } from '../entities/verification-document.entity';
import { PageRole } from '../entities/verification-document-page.entity';

export class DocumentFileDto {
  @IsString()
  file_url: string;

  @IsOptional()
  @IsString()
  object_key?: string;

  @IsEnum(PageRole)
  page_role: PageRole;

  @IsOptional()
  @IsInt()
  @Min(0)
  page_order?: number;
}

export class SubmitDocumentDto {
  @IsEnum(DocumentType)
  document_type: DocumentType;

  @IsOptional()
  @IsString()
  file_url?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => DocumentFileDto)
  @ArrayMinSize(1)
  files?: DocumentFileDto[];
}
