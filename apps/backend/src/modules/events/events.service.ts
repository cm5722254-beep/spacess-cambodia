import { Injectable } from '@nestjs/common';
import { Response } from 'express';

export interface RealtimeEventPayload {
  type: 'CHAT_MESSAGE' | 'NOTIFICATION' | 'ORDER_UPDATE' | 'LIVE_UPDATE' | 'SYSTEM';
  title?: string;
  body?: string;
  data?: Record<string, any>;
  timestamp?: string;
}

@Injectable()
export class EventsService {
  private clients = new Map<string, Set<Response>>();

  registerClient(userId: string, res: Response): () => void {
    const cleanId = (userId || '').trim();
    if (!cleanId) return () => {};

    let set = this.clients.get(cleanId);
    if (!set) {
      set = new Set<Response>();
      this.clients.set(cleanId, set);
    }
    set.add(res);

    const heartbeat = setInterval(() => {
      try {
        res.write(`: ping ${Date.now()}\n\n`);
      } catch (_) {
        clearInterval(heartbeat);
      }
    }, 20000);

    return () => {
      clearInterval(heartbeat);
      const current = this.clients.get(cleanId);
      if (current) {
        current.delete(res);
        if (current.size === 0) {
          this.clients.delete(cleanId);
        }
      }
    };
  }

  emitToUser(userId: string, payload: RealtimeEventPayload): void {
    const cleanId = (userId || '').trim();
    if (!cleanId) return;
    const set = this.clients.get(cleanId);
    if (!set || set.size === 0) return;

    const serialized = JSON.stringify({
      ...payload,
      timestamp: payload.timestamp || new Date().toISOString(),
    });

    for (const res of Array.from(set)) {
      try {
        res.write(`data: ${serialized}\n\n`);
      } catch (_) {
        set.delete(res);
      }
    }
  }

  emitToUsers(userIds: string[], payload: RealtimeEventPayload): void {
    const seen = new Set<string>();
    for (const uid of userIds) {
      if (uid && !seen.has(uid)) {
        seen.add(uid);
        this.emitToUser(uid, payload);
      }
    }
  }
}

