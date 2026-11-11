import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  NotFoundException,
  Post,
  Query,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { StorageService } from './storage.service';

interface UploadedBinaryFile {
  buffer: Buffer;
  mimetype?: string;
  originalname?: string;
  size?: number;
}

@Controller('storage')
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  @Get('status')
  getStorageStatus() {
    const r2 = this.storageService.getR2Config();
    return {
      provider: r2 ? 'cloudflare_r2' : 'local_disk',
      bucket: r2?.bucketName || 'local_uploads',
      publicUrlConfigured: Boolean(r2?.publicUrl),
    };
  }

  @Post('upload')
  async uploadMedia(
    @Body()
    body: {
      data?: string;
      file?: string;
      base64Data?: string;
      filename?: string;
      prefix?: string;
    },
  ) {
    const rawData = body.base64Data || body.data || body.file;
    if (!rawData) {
      throw new BadRequestException('No file data provided');
    }
    const result = await this.storageService.saveBase64(rawData, body.prefix || 'media');
    return {
      success: true,
      url: result.url,
      filename: result.filename,
      storage: result.storage,
    };
  }

  @Post('upload-file')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 250 * 1024 * 1024 },
    }),
  )
  async uploadBinaryFile(
    @UploadedFile() file: UploadedBinaryFile,
    @Body() body: { prefix?: string; filename?: string; mimeType?: string },
  ) {
    if (!file || !file.buffer || file.buffer.length === 0) {
      throw new BadRequestException('No multipart file provided');
    }

    const mime = (file.mimetype || body.mimeType || 'application/octet-stream').toLowerCase();
    const origName = file.originalname || body.filename || 'upload.bin';
    const extFromName = origName.includes('.') ? origName.split('.').pop() || '' : '';
    let ext = extFromName;
    if (!ext) {
      if (mime.includes('mp4')) ext = 'mp4';
      else if (mime.includes('webm')) ext = 'webm';
      else if (mime.includes('quicktime')) ext = 'mov';
      else if (mime.includes('png')) ext = 'png';
      else if (mime.includes('webp')) ext = 'webp';
      else if (mime.includes('gif')) ext = 'gif';
      else if (mime.includes('audio/m4a') || mime.includes('audio/mp4')) ext = 'm4a';
      else if (mime.includes('ogg')) ext = 'ogg';
      else ext = 'jpg';
    }

    const result = await this.storageService.saveBuffer(
      file.buffer,
      ext,
      mime,
      body.prefix || 'media',
    );
    return {
      success: true,
      url: result.url,
      filename: result.filename,
      storage: result.storage,
      bytes: file.buffer.length,
    };
  }

  @Get('object')
  async proxyR2Object(
    @Query('key') key: string,
    @Headers('range') range: string | undefined,
    @Res() res: Response,
  ) {
    if (!key || key.includes('..')) {
      throw new BadRequestException('Invalid storage key');
    }
    const r2Res = await this.storageService.fetchR2Object(key, range);
    if (!r2Res || !r2Res.ok) {
      throw new NotFoundException('Object not found in R2 storage');
    }

    res.status(r2Res.status);
    const copyHeaders = ['content-type', 'content-length', 'content-range', 'accept-ranges', 'etag'];
    for (const headerName of copyHeaders) {
      const value = r2Res.headers.get(headerName);
      if (value) res.setHeader(headerName, value);
    }
    res.setHeader('cache-control', 'public, max-age=31536000');

    const arrayBuf = await r2Res.arrayBuffer();
    res.send(Buffer.from(arrayBuf));
  }
}
