import { IsOptional, IsString, MaxLength } from 'class-validator';

export class ValidateProofDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
