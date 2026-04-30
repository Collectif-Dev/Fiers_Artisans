import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class ReopenProofDto {
  @IsOptional()
  @IsString()
  @MinLength(5)
  @MaxLength(500)
  reason?: string;
}
