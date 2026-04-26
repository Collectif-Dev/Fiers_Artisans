import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { BusinessException } from '../exceptions/business.exception';

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status: number;
    let message: string | string[];
    let error: string;
    let code: string | undefined;
    let details: unknown | undefined;

    if (exception instanceof BusinessException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse() as any;
      message = exceptionResponse.message || exception.message;
      code = exception.code;
      error = HttpStatus[status] || 'UNKNOWN_ERROR';
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();
      if (typeof exceptionResponse === 'string') {
        message = exceptionResponse;
      } else {
        const resp = exceptionResponse as any;
        message = resp.message || exception.message;
        // Propagate validation details from class-validator pipes
        if (Array.isArray(resp.message) && resp.message.length > 1) {
          details = resp.message;
        }
      }
      error = HttpStatus[status] || 'UNKNOWN_ERROR';
    } else {
      status = HttpStatus.INTERNAL_SERVER_ERROR;
      message = 'Une erreur interne est survenue.';
      error = 'INTERNAL_SERVER_ERROR';
      code = 'INTERNAL_ERROR';
      this.logger.error(
        `Unhandled exception: ${exception}`,
        exception instanceof Error ? exception.stack : undefined,
      );
    }

    const body: Record<string, unknown> = {
      statusCode: status,
      error,
      message: Array.isArray(message) ? message : [message],
      timestamp: new Date().toISOString(),
      path: request.url,
    };

    if (code) {
      body.code = code;
    }
    if (details) {
      body.details = details;
    }

    response.status(status).json(body);
  }
}
