import { Injectable, BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';
import { DbService, ProductEntity, OrderEntity } from '../database/db.service';

export interface ProductItem extends ProductEntity {
  sellerName: string;
  sellerPhone: string;
  sellerAvatar: string;
}

@Injectable()
export class MarketplaceService {
  private readonly GATEWAY_URL = 'https://lorndavid.online';

  constructor(private readonly db: DbService) {}

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
  async checkout(dto: { productId: string; buyerId?: string; currency?: string }) {
    const products = this.db.getProducts();
    const product = products.find((p) => p.id === dto.productId);
    if (!product) {
      throw new NotFoundException('រកមិនឃើញទំនិញនេះទេ (Product not found)');
    }

    const seller = this.db.findUserById(product.sellerId);
    const buyerId = dto.buyerId || 'guest';
    const buyer = this.db.findUserById(buyerId);

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
    const amount = product.priceUsd;
    const currency = dto.currency || 'USD';

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
        amount,
        currency,
        buyerId,
        buyerName: buyer?.name || 'Guest Buyer',
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
        // Payment verified & settled on NBC ledger!
        const updated = this.db.updateOrderStatus(md5, 'PAID', status.data);
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
}
