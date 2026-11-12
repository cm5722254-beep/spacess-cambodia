import * as crypto from 'crypto';

export interface R2Config {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucketName: string;
  publicUrl: string;
}

/** Read Cloudflare R2 configuration from environment variables, or null if incomplete. */
export function getR2Config(): R2Config | null {
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

export function sha256Hex(data: Buffer | string): string {
  return crypto.createHash('sha256').update(data).digest('hex');
}

function hmac(key: Buffer | string, data: string): Buffer {
  return crypto.createHmac('sha256', key).update(data, 'utf8').digest();
}

/** Sign an S3-compatible request for Cloudflare R2 using AWS Signature Version 4. */
export function signR2Request(
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
    sha256Hex(canonicalRequest),
  ].join('\n');

  const kDate = hmac(`AWS4${cfg.secretAccessKey}`, dateStamp);
  const kRegion = hmac(kDate, region);
  const kService = hmac(kRegion, service);
  const kSigning = hmac(kService, 'aws4_request');
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

export async function putR2Object(
  objectKey: string,
  buffer: Buffer,
  contentType: string = 'application/octet-stream',
): Promise<{ ok: boolean; status?: number; errorText?: string; publicUrl?: string }> {
  const cfg = getR2Config();
  if (!cfg) return { ok: false, errorText: 'R2 not configured' };

  const payloadHash = sha256Hex(buffer);
  const { endpointUrl, headers } = signR2Request(cfg, 'PUT', objectKey, payloadHash, {
    'content-type': contentType,
  });

  const response = await fetch(endpointUrl, {
    method: 'PUT',
    headers,
    body: new Uint8Array(buffer),
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => '');
    return { ok: false, status: response.status, errorText };
  }

  const cleanKey = objectKey.replace(/^\/+/, '');
  const publicUrl = cfg.publicUrl ? `${cfg.publicUrl}/${cleanKey}` : undefined;
  return { ok: true, status: response.status, publicUrl };
}

export async function getR2Object(
  objectKey: string,
  rangeHeader?: string,
): Promise<Response | null> {
  const cfg = getR2Config();
  if (!cfg || !objectKey) return null;

  const emptyHash = sha256Hex('');
  const extra: Record<string, string> = {};
  if (rangeHeader) {
    extra.range = rangeHeader;
  }
  const { endpointUrl, headers } = signR2Request(cfg, 'GET', objectKey, emptyHash, extra);
  return fetch(endpointUrl, { method: 'GET', headers });
}
