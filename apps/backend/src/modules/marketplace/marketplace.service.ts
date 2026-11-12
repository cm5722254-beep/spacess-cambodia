import { Injectable, BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';
import { DbService, ProductEntity, OrderEntity } from '../database/db.service';
import { EventsService } from '../events/events.service';

export interface ProductItem extends ProductEntity {
  sellerName: string;
  sellerPhone: string;
  sellerAvatar: string;
  sellerStoreDescription?: string;
  sellerStoreBannerUrl?: string;
  sellerStoreThemeColor?: string;
  sellerStoreTagline?: string;
}

@Injectable()
export class MarketplaceService {
  private readonly GATEWAY_URL = 'https://lorndavid.online';

  constructor(
    private readonly db: DbService,
    private readonly events: EventsService,
  ) {}

  getCategories() {
    return [
      { id: 'all', nameKh: 'ទាំងអស់', nameEn: 'All' },
      { id: 'Electronics', nameKh: 'អេឡិចត្រូនិក', nameEn: 'Electronics' },
      { id: 'Vehicles', nameKh: 'យានយន្ត', nameEn: 'Vehicles' },
      { id: 'Fashion', nameKh: 'សម្លៀកបំពាក់', nameEn: 'Fashion' },
      { id: 'Food', nameKh: 'ម្ហូប & កសិផល', nameEn: 'Food & Farm' },
    ];
  }

  getProducts(category?: string, query?: string, city?: string): ProductItem[] {
    const rawList = this.db.getProducts(category, query, city);
    return rawList.map((p) => {
      const seller = this.db.findUserById(p.sellerId);
      return {
        ...p,
        sellerName: seller?.storeName || seller?.name || 'អ្នកលក់ Spaces',
        sellerPhone: seller?.storePhone || seller?.phone || '012 345 678',
        sellerBakongId: (seller?.bakongAccountId && seller.bakongAccountId.trim())
          ? seller.bakongAccountId.trim()
          : (p.sellerBakongId || ''),
        sellerAvatar:
          seller?.avatar ||
          '/default_avatar.svg',
        sellerStoreDescription: seller?.storeDescription || '',
        sellerStoreBannerUrl: seller?.storeBannerUrl || '',
        sellerStoreThemeColor: seller?.storeThemeColor || '#0A84FF',
        sellerStoreTagline: seller?.storeTagline || '',
      };
    });
  }

  createProduct(dto: {
    title: string;
    priceUsd: number;
    category: string;
    imageUrl?: string;
    location?: string;
    description: string;
    sellerId: string;
    condition?: string;
    sellerBakongId?: string;
    sellerStoreName?: string;
  }): ProductItem {
    const existingSeller = this.db.findUserById(dto.sellerId);
    const effectiveBakong = (dto.sellerBakongId && dto.sellerBakongId.trim())
      ? dto.sellerBakongId.trim()
      : (existingSeller?.bakongAccountId && existingSeller.bakongAccountId.trim())
        ? existingSeller.bakongAccountId.trim()
        : '';

    if (!effectiveBakong) {
      throw new BadRequestException('សូមបញ្ចូល Bakong Account ID ផ្ទាល់ខ្លួនរបស់អ្នកជាមុនសិន (Please enter your own Bakong Account ID)');
    }

    const created = this.db.createProduct(dto);
    const seller = this.db.findUserById(created.sellerId);
    return {
      ...created,
      sellerName: seller?.storeName || seller?.name || 'អ្នកលក់ Spaces',
      sellerPhone: seller?.storePhone || seller?.phone || '012 345 678',
      sellerBakongId: seller?.bakongAccountId || created.sellerBakongId || effectiveBakong,
      sellerAvatar:
        seller?.avatar ||
        '/default_avatar.svg',
    };
  }

  deleteProduct(productId: string, userId: string): boolean {
    const products = this.db.getProducts();
    const prod = products.find((p) => p.id === productId);
    if (!prod) return false;
    const user = this.db.findUserById(userId);
    if (prod.sellerId !== userId && user?.role !== 'ADMIN') {
      throw new ForbiddenException('អ្នកគ្មានសិទ្ធិលុបទំនិញរបស់អ្នកដទៃទេ (Only product seller or admin can delete)');
    }
    return this.db.deleteProduct(productId, userId);
  }

  // --- BAKONG CHECKOUT & KHQR INTEGRATION ---
  async checkout(dto: {
    productId: string;
    buyerId?: string;
    currency?: string;
    quantity?: number;
    buyerPhone?: string;
    shippingAddress?: string;
    buyerNote?: string;
  }) {
    const products = this.db.getProducts();
    const product = products.find((p) => p.id === dto.productId);
    if (!product) {
      throw new NotFoundException('រកមិនឃើញទំនិញនេះទេ (Product not found)');
    }

    const seller = this.db.findUserById(product.sellerId);
    const buyerId = dto.buyerId || 'guest';
    const buyer = this.db.findUserById(buyerId);
    const qty = Math.max(1, Math.min(99, Number(dto.quantity) || 1));

    const sellerBakongId = (seller?.bakongAccountId && seller.bakongAccountId.trim())
      ? seller.bakongAccountId.trim()
      : (product.sellerBakongId && product.sellerBakongId.trim())
        ? product.sellerBakongId.trim()
        : '';

    if (!sellerBakongId) {
      throw new BadRequestException('អ្នកលក់មិនទាន់បានកំណត់គណនី Bakong ID នៅឡើយទេ (Seller Bakong ID missing)');
    }

    const merchantName = (seller?.storeName && seller.storeName.trim())
      ? seller.storeName.trim()
      : (product.sellerStoreName && product.sellerStoreName.trim())
        ? product.sellerStoreName.trim()
        : (seller?.name || 'Spaces Merchant');
    const billNumber = `INV-${Date.now()}`;
    const unitPrice = product.priceUsd;
    const amount = Number((unitPrice * qty).toFixed(2));
    const currency = dto.currency || 'USD';
    const buyerPhone = (dto.buyerPhone || buyer?.phone || '').trim();
    const shippingAddress = (dto.shippingAddress || buyer?.location || '').trim();
    const buyerNote = (dto.buyerNote || '').trim();

    try {
      const response = await fetch(`${this.GATEWAY_URL}/api/v1/khqr/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          accountId: sellerBakongId,
          merchantName: merchantName,
          merchantCity: 'Phnom Penh',
          amount: parseFloat(amount.toString()),
          currency: currency,
          storeLabel: 'Spaces Cambodia',
          billNumber: billNumber,
          terminalLabel: 'APP-01',
        }),
      });

      const khqr = await response.json();

      if (!khqr.md5 && !khqr.qrImage) {
        throw new Error(khqr.message || 'Error generating KHQR from Bakong Gateway');
      }

      const order = this.db.createOrder({
        billNumber,
        productId: product.id,
        productTitle: product.title,
        quantity: qty,
        unitPrice,
        amount,
        currency,
        buyerId,
        buyerName: buyer?.name || 'Guest Buyer',
        buyerPhone,
        shippingAddress,
        buyerNote,
        sellerId: product.sellerId,
        sellerName: seller?.name || 'Seller',
        sellerStoreName: merchantName,
        sellerBakongId,
        md5: khqr.md5,
        qrString: khqr.qrString,
        qrImage: khqr.qrImage,
        deeplink: khqr.deeplink,
      });

      return {
        success: true,
        orderId: order.id,
        billNumber,
        md5: khqr.md5,
        qrImage: khqr.qrImage,
        deeplink: khqr.deeplink,
        qrString: khqr.qrString,
        amount,
        quantity: qty,
        unitPrice,
        currency,
        merchantName,
        sellerBakongId,
      };
    } catch (err: any) {
      console.error('[MarketplaceService] Checkout KHQR error:', err);
      throw new BadRequestException(`Bakong KHQR Error: ${err.message}`);
    }
  }

  // --- BAKONG PAYMENT STATUS POLLING & NBC SETTLEMENT ---
  async checkPaymentStatus(md5: string) {
    const existingOrder = this.db.getOrderByMd5(md5);
    if (existingOrder && existingOrder.status === 'PAID') {
      return {
        success: true,
        paid: true,
        status: 'ALREADY_SETTLED',
        order: existingOrder,
      };
    }

    try {
      const response = await fetch(`${this.GATEWAY_URL}/api/v1/check/${md5}`);
      const status = await response.json();

      if (status.responseCode === 0) {
        const wasPaidBefore = existingOrder?.status === 'PAID';
        // Payment verified & settled on NBC ledger!
        const updated = this.db.updateOrderStatus(md5, 'PAID', status.data);
        if (updated && !wasPaidBefore) {
          const qtyLabel = updated.quantity && updated.quantity > 1 ? ` (${updated.quantity}x)` : '';
          const phonePart = updated.buyerPhone ? ` • 📞 ${updated.buyerPhone}` : '';
          const addrPart = updated.shippingAddress ? ` • 📍 ${updated.shippingAddress}` : '';
          const summaryBody = `${updated.productTitle}${qtyLabel} — \$${updated.amount} ${updated.currency}${phonePart}${addrPart}`;

          // 1) Persist seller bell notification
          this.db.createNotification({
            userId: updated.sellerId,
            actorId: updated.buyerId,
            type: 'ORDER_PAID',
            title: `បានបញ្ជាទិញ និងបង់លុយ KHQR ជោគជ័យ`,
            body: summaryBody,
            refId: updated.id,
          });

          // 2) Auto-send receipt message to Seller Chat Inbox
          if (updated.buyerId && updated.buyerId !== 'guest' && updated.buyerId !== updated.sellerId) {
            try {
              const chat = this.db.getOrCreateChat(updated.buyerId, updated.sellerId);
              const receiptText = [
                `🧾 វិក្កយបត្របញ្ជាទិញថ្មី (PAID KHQR)`,
                `• លេខបុង: ${updated.billNumber}`,
                `• ទំនិញ: ${updated.productTitle}${qtyLabel}`,
                `• ទឹកប្រាក់បានបង់: \$${updated.amount} ${updated.currency}`,
                `• អ្នកទិញ: ${updated.buyerName || 'Customer'}`,
                updated.buyerPhone ? `• ទូរស័ព្ទ: ${updated.buyerPhone}` : '',
                updated.shippingAddress ? `• ទីតាំងផ្ញើ: ${updated.shippingAddress}` : '',
                updated.buyerNote ? `• កំណត់ចំណាំ: ${updated.buyerNote}` : '',
              ]
                .filter(Boolean)
                .join('\n');
              const chatMsg = this.db.sendMessage(chat.id, updated.buyerId, receiptText, undefined, 'text');
              this.events.emitToUser(updated.sellerId, {
                type: 'CHAT_MESSAGE',
                title: `🧾 ការបញ្ជាទិញថ្មីពី ${updated.buyerName || 'Customer'}`,
                body: `${updated.productTitle}${qtyLabel} (\$${updated.amount})`,
                data: { chatId: chat.id, messageId: chatMsg.id },
              });
            } catch (e) {
              console.warn('[MarketplaceService] Auto receipt chat skipped:', e);
            }
          }

          // 3) Real-time SSE Order Update
          this.events.emitToUsers([updated.buyerId, updated.sellerId], {
            type: 'ORDER_UPDATE',
            title: 'ការទូទាត់ Bakong KHQR ជោគជ័យ',
            body: summaryBody,
            data: { orderId: updated.id, status: 'PAID' },
          });
        }
        return {
          success: true,
          paid: true,
          transaction: status.data,
          order: updated,
        };
      }

      return {
        success: true,
        paid: false,
        message: 'Waiting for payer transfer...',
      };
    } catch (err: any) {
      console.error('[MarketplaceService] Check status error:', err);
      return {
        success: false,
        paid: false,
        error: err.message,
      };
    }
  }

  getUserOrders(userId: string) {
    return this.db.getUserOrders(userId);
  }

  updateOrderFulfillment(
    orderId: string,
    actingUserId: string,
    fulfillmentStatus: 'PROCESSING' | 'CONFIRMED' | 'SHIPPING' | 'DELIVERED',
    trackingNote?: string,
  ) {
    const updated = this.db.updateOrderFulfillment(orderId, actingUserId, fulfillmentStatus, trackingNote);
    if (!updated) {
      throw new ForbiddenException('Not allowed to update this order or order not found');
    }
    const statusLabels: Record<string, string> = {
      PROCESSING: 'កំពុងរៀបចំទំនិញ',
      CONFIRMED: 'អ្នកលក់បានបញ្ជាក់ការកម្ម៉ង់',
      SHIPPING: 'កំពុងដឹកជញ្ជូនដល់លោកអ្នក',
      DELIVERED: 'ទំនិញត្រូវបានប្រគល់ជូនរួចរាល់',
    };
    const notifyTarget = actingUserId === updated.sellerId ? updated.buyerId : updated.sellerId;
    this.db.createNotification({
      userId: notifyTarget,
      actorId: actingUserId,
      type: 'ORDER_UPDATE',
      title: `ដំណើរការទំនិញ: ${statusLabels[fulfillmentStatus] || fulfillmentStatus}`,
      body: `${updated.productTitle}${updated.trackingNote ? ` • ${updated.trackingNote}` : ''}`,
      refId: updated.id,
    });
    this.events.emitToUsers([updated.buyerId, updated.sellerId], {
      type: 'ORDER_UPDATE',
      title: `បច្ចុប្បន្នភាពការដឹកជញ្ជូន: ${statusLabels[fulfillmentStatus] || fulfillmentStatus}`,
      body: `${updated.productTitle}${updated.trackingNote ? ` • ${updated.trackingNote}` : ''}`,
      data: {
        orderId: updated.id,
        fulfillmentStatus,
        trackingNote: updated.trackingNote || '',
      },
    });
    return { success: true, order: updated };
  }
}
