import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

// Khmer / English translations for common system error codes
const ERROR_TRANSLATIONS: Record<string, { km: string; en: string }> = {
  INTERNAL_SERVER_ERROR: {
    km: 'មានបញ្ហាបច្ចេកទេសក្នុងម៉ាស៊ីនបម្រើ។ សូមព្យាយាមម្តងទៀត។',
    en: 'Internal server error occurred. Please try again.',
  },
  BAD_REQUEST: {
    km: 'ទិន្នន័យផ្ញើមកមិនត្រឹមត្រូវតាមទម្រង់កំណត់។',
    en: 'Bad request. Please check submitted parameters.',
  },
  UNAUTHORIZED: {
    km: 'អ្នកមិនមានការអនុញ្ញាតដើម្បីចូលប្រើប្រាស់មុខងារនេះទេ។',
    en: 'Unauthorized. Authentication token missing or expired.',
  },
  FORBIDDEN: {
    km: 'អ្នកគ្មានសិទ្ធិគ្រប់គ្រាន់ដើម្បីធ្វើសកម្មភាពនេះឡើយ។',
    en: 'Forbidden resource.',
  },
  NOT_FOUND: {
    km: 'រកមិនឃើញទិន្នន័យ ឬធនធានដែលអ្នកស្វែងរកឡើយ។',
    en: 'Requested resource not found.',
  },
};

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const exceptionResponse =
      exception instanceof HttpException ? exception.getResponse() : null;

    let errorCode = 'INTERNAL_SERVER_ERROR';
    let message = 'An unexpected error occurred';
    let details: any = null;

    if (typeof exceptionResponse === 'string') {
      message = exceptionResponse;
    } else if (
      typeof exceptionResponse === 'object' &&
      exceptionResponse !== null
    ) {
      const respObj = exceptionResponse as Record<string, any>;
      errorCode = respObj.code || (status === 404 ? 'NOT_FOUND' : status === 401 ? 'UNAUTHORIZED' : status === 403 ? 'FORBIDDEN' : 'BAD_REQUEST');
      message = Array.isArray(respObj.message)
        ? respObj.message.join(', ')
        : respObj.message || message;
      details = respObj.details || (Array.isArray(respObj.message) ? respObj.message : null);
    }

    if (status >= 500) {
      this.logger.error(
        `[${request.method}] ${request.url} - Status ${status} - Error: ${
          exception instanceof Error ? exception.stack : JSON.stringify(exception)
        }`,
      );
    }

    // Language detection from Accept-Language header
    const acceptLang = request.headers['accept-language'] || 'km';
    const lang = acceptLang.includes('en') ? 'en' : 'km';
    const localizedMessage =
      ERROR_TRANSLATIONS[errorCode]?.[lang] || message;

    response.status(status).json({
      success: false,
      message,
      error: {
        code: errorCode,
        message,
        localizedMessage,
        details,
        path: request.url,
        timestamp: new Date().toISOString(),
      },
    });
  }
}

