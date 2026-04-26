import {
  Injectable,
  CanActivate,
  ExecutionContext,
  HttpStatus,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../../modules/users/entities/user.entity';
import { BusinessException } from '../exceptions/business.exception';

@Injectable()
export class PhoneVerifiedGuard implements CanActivate {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const userId = request.user?.id;
    if (!userId) {
      throw new BusinessException('AUTH_OTP_REQUIRED', 'Vérification du téléphone requise.', HttpStatus.FORBIDDEN);
    }

    const user = await this.userRepository.findOne({
      where: { id: userId },
      select: ['id', 'is_phone_verified'],
    });

    if (!user || !user.is_phone_verified) {
      throw new BusinessException('AUTH_OTP_REQUIRED', 'Vérification du téléphone requise.', HttpStatus.FORBIDDEN);
    }

    return true;
  }
}
