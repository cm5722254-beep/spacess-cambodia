import { Injectable, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { getR2Config, getR2Object, putR2Object, R2Config } from './r2-client.util';

export { R2Config };

export interface StoredMediaResult {
  url: string;
  filename: string;
  storage: 'r2' | 'local';
  key?: string;
}

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly uploadDir = process.env.UPLOAD_DIR
    ? path.resolve(process.env.UPLOAD_DIR)
    : path.join(__dirname, '..', '..', '..', 'uploads');

  constructor() {
    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  async saveNamedLocalFile(filename: string, buffer: Buffer): Promise<string> {
    const safeName = path.basename(filename);
    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
    const targetPath = path.join(this.uploadDir, safeName);
    await fs.promises.writeFile(targetPath, buffer);
    return `/uploads/${safeName}`;
  }

  getR2Config(): R2Config | null {
    return getR2Config();
  }

  async saveBuffer(
    buffer: Buffer,
    ext: string = 'bin',
    contentType: string = 'application/octet-stream',
    filenamePrefix: string = 'media',
  ): Promise<StoredMediaResult> {
    const safePrefix = (filenamePrefix || 'media').replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 32) || 'media';
    const safeExt = (ext || 'bin').replace(/[^a-zA-Z0-9]/g, '').toLowerCase() || 'bin';
    const filename = `${safePrefix}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}.${safeExt}`;
    const r2Key = `media/${filename}`;

    const r2 = this.getR2Config();
    if (r2) {
      try {
        const res = await putR2Object(r2Key, buffer, contentType);
        if (res.ok) {
          const publicUrl =
            res.publicUrl || `/api/v1/storage/object?key=${encodeURIComponent(r2Key)}`;
          return { url: publicUrl, filename, storage: 'r2', key: r2Key };
        }
        this.logger.warn(
          `R2 upload returned ${res.status ?? 'error'}: ${(res.errorText || '').slice(0, 200)}`,
        );
      } catch (err: any) {
        this.logger.warn(`R2 upload failed, falling back to local disk: ${err?.message || err}`);
      }
    }

    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
    const filePath = path.join(this.uploadDir, filename);
    await fs.promises.writeFile(filePath, buffer);
    return { url: `/uploads/${filename}`, filename, storage: 'local' };
  }

  async fetchR2Object(objectKey: string, rangeHeader?: string): Promise<Response | null> {
    return getR2Object(objectKey, rangeHeader);
  }

  private resolveMimeAndExt(mime: string): { ext: string; contentType: string } {
    const m = mime.toLowerCase();
    if (m.includes('png')) return { ext: 'png', contentType: 'image/png' };
    if (m.includes('gif')) return { ext: 'gif', contentType: 'image/gif' };
    if (m.includes('webp')) return { ext: 'webp', contentType: 'image/webp' };
    if (m.includes('svg')) return { ext: 'svg', contentType: 'image/svg+xml' };
    if (m.includes('audio/mp4') || m.includes('m4a') || m.includes('aac')) {
      return { ext: 'm4a', contentType: 'audio/mp4' };
    }
    if (m.includes('audio/ogg') || m.includes('ogg')) return { ext: 'ogg', contentType: 'audio/ogg' };
    if (m.includes('audio/mpeg') || m.includes('mp3')) return { ext: 'mp3', contentType: 'audio/mpeg' };
    if (m.includes('audio/wav') || m.includes('wav')) return { ext: 'wav', contentType: 'audio/wav' };
    if (m.includes('audio/webm')) return { ext: 'webm', contentType: 'audio/webm' };
    if (m.includes('video/webm') || m.includes('webm')) return { ext: 'webm', contentType: 'video/webm' };
    if (m.includes('video/mp4') || m.includes('mp4')) return { ext: 'mp4', contentType: 'video/mp4' };
    if (m.includes('quicktime') || m.includes('mov')) return { ext: 'mov', contentType: 'video/quicktime' };
    return { ext: 'jpg', contentType: 'image/jpeg' };
  }

  async saveBase64(dataUriOrBase64: string, filenamePrefix: string = 'media'): Promise<StoredMediaResult> {
    const matches = dataUriOrBase64.match(/^data:([^;]+);base64,(.+)$/);
    const mime = matches ? matches[1] : 'image/jpeg';
    const base64Data = matches ? matches[2] : dataUriOrBase64;
    const { ext, contentType } = this.resolveMimeAndExt(mime);
    const buffer = Buffer.from(base64Data, 'base64');
    return this.saveBuffer(buffer, ext, contentType, filenamePrefix);
  }
}
