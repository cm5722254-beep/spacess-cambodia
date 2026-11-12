import { Injectable, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

export interface R2Config {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucketName: string;
  publicUrl: string;
}

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
    const accountId = (process.env.R2_ACCOUNT_ID || '').trim();
    const accessKeyId = (process.env.R2_ACCESS_KEY_ID || '').trim();
    const secretAccessKey = (process.env.R2_SECRET_ACCESS_KEY || '').trim();
    const bucketName = (process.env.R2_BUCKET_NAME || '').trim();
    const publicUrl = (process.env.R2_PUBLIC_URL || '').trim().replace(/\/+$/, '');

    if (
      !accountId ||
      !accessKeyId ||
      !secretAccessKey ||
      !bucketName ||
      accountId.startsWith('YOUR_') ||
      accessKeyId.startsWith('YOUR_') ||
      secretAccessKey.startsWith('YOUR_')
    ) {
      return null;
    }

    return { accountId, accessKeyId, secretAccessKey, bucketName, publicUrl };
  }

  private sha256Hex(data: Buffer | string): string {
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  private hmac(key: Buffer | string, data: string): Buffer {
    return crypto.createHmac('sha256', key).update(data, 'utf8').digest();
  }

  private signR2Request(
    cfg: R2Config,
    method: 'PUT' | 'GET' | 'DELETE',
    objectKey: string,
    payloadHash: string,
    extraHeaders: Record<string, string> = {},
  ): { endpointUrl: string; headers: Record<string, string> } {
    const host = `${cfg.accountId}.r2.cloudflarestorage.com`;
    const cleanKey = objectKey.replace(/^\/+/, '');
    const canonicalUri = `/${cfg.bucketName}/${cleanKey}`;
    const endpointUrl = `https://${host}${canonicalUri}`;

    const now = new Date();
    const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, '');
    const dateStamp = amzDate.slice(0, 8);
    const region = 'auto';
    const service = 's3';

    const headerMap: Record<string, string> = {
      host,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
    };

    for (const [k, v] of Object.entries(extraHeaders)) {
      if (v) {
        headerMap[k.toLowerCase()] = v.trim();
      }
    }

    const sortedKeys = Object.keys(headerMap).sort();
    const canonicalHeaders = sortedKeys.map((k) => `${k}:${headerMap[k]}\n`).join('');
    const signedHeaders = sortedKeys.join(';');

    const canonicalRequest = [
      method,
      canonicalUri,
      '',
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
    const stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      this.sha256Hex(canonicalRequest),
    ].join('\n');

    const kDate = this.hmac(`AWS4${cfg.secretAccessKey}`, dateStamp);
    const kRegion = this.hmac(kDate, region);
    const kService = this.hmac(kRegion, service);
    const kSigning = this.hmac(kService, 'aws4_request');
    const signature = crypto
      .createHmac('sha256', kSigning)
      .update(stringToSign, 'utf8')
      .digest('hex');

    const authorization = `AWS4-HMAC-SHA256 Credential=${cfg.accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

    const requestHeaders: Record<string, string> = {
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      Authorization: authorization,
    };
    for (const [k, v] of Object.entries(extraHeaders)) {
      if (v) requestHeaders[k] = v;
    }

    return { endpointUrl, headers: requestHeaders };
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
        const payloadHash = this.sha256Hex(buffer);
        const { endpointUrl, headers } = this.signR2Request(r2, 'PUT', r2Key, payloadHash, {
          'content-type': contentType,
        });
        const response = await fetch(endpointUrl, {
          method: 'PUT',
          headers,
          body: new Uint8Array(buffer),
        });
        if (response.ok) {
          const publicUrl = r2.publicUrl
            ? `${r2.publicUrl}/${r2Key}`
            : `/api/v1/storage/object?key=${encodeURIComponent(r2Key)}`;
          return { url: publicUrl, filename, storage: 'r2', key: r2Key };
        }
        const errBody = await response.text().catch(() => '');
        this.logger.warn(`R2 upload returned ${response.status}: ${errBody.slice(0, 200)}`);
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
    const r2 = this.getR2Config();
    if (!r2 || !objectKey) return null;
    const emptyHash = this.sha256Hex('');
    const extra: Record<string, string> = {};
    if (rangeHeader) {
      extra.range = rangeHeader;
    }
    const { endpointUrl, headers } = this.signR2Request(r2, 'GET', objectKey, emptyHash, extra);
    return fetch(endpointUrl, { method: 'GET', headers });
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
