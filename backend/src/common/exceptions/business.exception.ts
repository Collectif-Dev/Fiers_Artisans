import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * Exception métier avec un code stable consommable par les clients.
 *
 * Exemples :
 *   throw new BusinessException('AUTH_INVALID_CREDENTIALS', 'Identifiants invalides.', HttpStatus.UNAUTHORIZED);
 *   throw new BusinessException('AUTH_OTP_REQUIRED', 'OTP_REQUIRED', HttpStatus.FORBIDDEN);
 */
export class BusinessException extends HttpException {
  readonly code: string;

  constructor(
    code: string,
    message: string,
    status: HttpStatus = HttpStatus.BAD_REQUEST,
  ) {
    super({ code, message }, status);
    this.code = code;
  }
}
