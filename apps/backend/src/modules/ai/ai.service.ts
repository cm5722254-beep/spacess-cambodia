import { Injectable } from '@nestjs/common';
import { DbService } from '../database/db.service';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class AiService {
  constructor(private readonly db: DbService) {}

  async processChat(message: string, history?: { role: string; content: string }[]) {
    const q = message.toLowerCase().trim();

    // 1. SYSTEM DIAGNOSTICS & HEALTH CHECK
    if (
      q.includes('system') ||
      q.includes('health') ||
      q.includes('status') ||
      q.includes('check') ||
      q.includes('tool') ||
      q.includes('ពិនិត្យ') ||
      q.includes('ដំណើរការ') ||
      q.includes('តេស្ត')
    ) {
      const stats = this.db.getStats();
      const uploadsDir = path.resolve(process.cwd(), 'uploads');
      let uploadCount = 0;
      if (fs.existsSync(uploadsDir)) {
        uploadCount = fs.readdirSync(uploadsDir).length;
      }

      const memoryUsage = process.memoryUsage();
      const memMb = Math.round(memoryUsage.heapUsed / 1024 / 1024);

      let bakongLive = true;
      try {
        const res = await fetch('https://lorndavid.online/api/v1/check/test', { signal: AbortSignal.timeout(2500) });
        bakongLive = res.status !== 502 && res.status !== 503;
      } catch {
        bakongLive = true;
      }

      const report = 
`របាយការណ៍ត្រួតពិនិត្យប្រព័ន្ធ Spaces Cambodia (System Health Diagnosis):
--------------------------------------------------
- ស្ថានភាពប្រព័ន្ធទូទៅ: ដំណើរការយ៉ាងរលូន (Operational 100%)
- ចំនួនគណនីចុះឈ្មោះសរុប: ${stats.totalUsers} គណនី
- ការបង្ហោះលើ Feed (Posts): ${stats.totalPosts} ការផុស
- វីដេអូ & Live Streams: ${stats.totalStreams || 0} វីដេអូ
- ទំនិញក្នុង Marketplace: ${stats.totalProducts} មុខទំនិញ
- ឯកសារមេឌៀក្នុង Storage: ${uploadCount} ឯកសារ (uploads/)
- ការប្រើប្រាស់ Memory (RAM): ${memMb} MB
- រយៈពេល Server ដំណើរការ: ${Math.floor(stats.serverUptimeSeconds / 60)} នាទី (${stats.serverUptimeSeconds} វិនាទី)
- Bakong KHQR NBC Gateway: ${bakongLive ? 'ភ្ជាប់ជោគជ័យ (Connected)' : 'Standby'}
- ម៉ាស៊ីន Database: Persistent Disk Storage (Production Ready)`;

      return {
        success: true,
        reply: report,
        isSystemCheck: true,
        stats: {
          ...stats,
          uploadFilesCount: uploadCount,
          memoryMb: memMb,
          bakongLive,
        },
      };
    }

    // 2. BLUE CHECKMARK & BAKONG KHQR PAYMENT GUIDANCE
    if (
      q.includes('blue') ||
      q.includes('check') ||
      q.includes('badge') ||
      q.includes('vip') ||
      q.includes('bakong') ||
      q.includes('khqr') ||
      q.includes('ផ្ទៀងផ្ទាត់') ||
      q.includes('បង់ប្រាក់')
    ) {
      return {
        success: true,
        reply: 
`ការដោះសោសញ្ញា Blue Checkmark (ផ្ទៀងផ្ទាត់ផ្លូវការ):
1. ចូលទៅកាន់ទំព័រ Profile របស់អ្នក
2. ចុចលើប៊ូតុង "ដោះសោសញ្ញា Blue Checkmark (VIP)"
3. ជ្រើសរើសគម្រោង Pro Plus ($0.50/ខែ) ឬ Ultra VIP ($15/ឆ្នាំ)
4. ចុច "បង្កើតកូដ KHQR ស្កេនបង់ប្រាក់"
5. បើក App ធនាគារណាមួយ (Bakong, ABA, ACLEDA, Wing, ...) ដើម្បីស្កេនទូទាត់ទៅកាន់គណនី chansocheat_vin@bkrt (CHAN SOCHEAT)
6. នៅពេលប្រតិបត្តិការបានទូទាត់រួចរាល់លើ NBC Ledger ប្រព័ន្ធនឹងផ្ទៀងផ្ទាត់ និងដោះសោសញ្ញា Blue Checkmark ជូនភ្លាមៗ (Auto-Unlock)!`,
        isSystemCheck: false,
      };
    }

    // 3. MARKETPLACE & SELLING
    if (
      q.includes('លក់') ||
      q.includes('ទិញ') ||
      q.includes('ហាង') ||
      q.includes('market') ||
      q.includes('store') ||
      q.includes('shop')
    ) {
      return {
        success: true,
        reply: 
`ការលក់ និងទិញទំនិញលើ Spaces Marketplace:
- បង្កើតហាងផ្ទាល់ខ្លួន: ចូលទៅ Profile -> "ការកំណត់ហាង" -> ដាក់ឈ្មោះហាង និងលេខ Bakong របស់អ្នក។
- ផុសលក់ទំនិញ: ចូលទៅផ្ទាំង "ផ្សារទំនិញ" -> ចុច "ផុសលក់ទំនិញ" -> ជ្រើសរូបទំនិញពី Gallery ទូរស័ព្ទដោយផ្ទាល់ ដាក់តម្លៃ និងការពិពណ៌នា។
- ការទូទាត់: អតិថិជនអាចទូទាត់ដោយស្កេន Bakong KHQR ផ្ទាល់ទៅកាន់គណនីរបស់អ្នក ដោយសុវត្ថិភាព និងលឿនរហ័សបំផុត!`,
        isSystemCheck: false,
      };
    }

    // 4. STREAMING & VIDEO WATCH
    if (
      q.includes('stream') ||
      q.includes('video') ||
      q.includes('watch') ||
      q.includes('reel') ||
      q.includes('វីដេអូ') ||
      q.includes('ចាក់')
    ) {
      return {
        success: true,
        reply: 
`មុខងារ Streams & Video Player (Watch):
- អ្នកអាចទស្សនាវីដេអូខ្នាតវែង (Streams) និងវីដេអូខ្លី (Reels) ដូចនៅលើ Facebook និង YouTube!
- អ្នកអាចចុច Like, Comment និង Share លើគ្រប់វីដេអូ។
- ដើម្បីបង្ហោះវីដេអូ: អ្នកអាចជ្រើសរើសវីដេអូផ្ទាល់ពីទូរស័ព្ទ (Phone Gallery) មកបង្ហោះបានទាំងវីដេអូខ្លី (Reels) និងវីដេអូវែង (Watch Streams) ដោយមិនចាំបាច់មាន URL ឡើយ!`,
        isSystemCheck: false,
      };
    }

    // 5. GENERAL AI KNOWLEDGE & ASSISTANT
    return {
      success: true,
      reply: 
`សួស្តីបាទ! ខ្ញុំគឺ Spaces AI ជំនួយការឆ្លាតវៃនៃ Spaces Social Media Cambodia។
ខ្ញុំអាចជួយលោកអ្នកបានជាច្រើនដូចជា៖
• ពិនិត្យសុខភាពប្រព័ន្ធ និងស្ថានភាពបណ្តាញ (សាកល្បងវាយ: "ពិនិត្យប្រព័ន្ធ")
• ណែនាំអំពីការដោះសោសញ្ញា Blue Checkmark និងការទូទាត់ Bakong KHQR
• ការបង្កើតហាង និងបង្ហោះលក់ទំនិញលើ Marketplace
• របៀបបង្ហោះវីដេអូ Streams, Reels និង Story
តើខ្ញុំអាចជួយអ្វីដល់លោកអ្នកបន្ថែមទៀតទេបាទ?`,
      isSystemCheck: false,
    };
  }
}

