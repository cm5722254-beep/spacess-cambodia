import { Controller, Get, Post, Delete, Body, Param, Query } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { MarketplaceService } from './marketplace.service';

@ApiTags('Marketplace & E-Commerce')
@Controller('marketplace')
export class MarketplaceController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get('categories')
  @ApiOperation({ summary: 'Get all marketplace product categories' })
  getCategories() {
    return this.marketplaceService.getCategories();
  }

  @Get('products')
  @ApiOperation({ summary: 'Get marketplace products with optional filtering' })
  getProducts(
    @Query('category') category?: string,
    @Query('q') query?: string,
    @Query('city') city?: string,
  ) {
    return this.marketplaceService.getProducts(category, query, city);
  }

  @Post('products')
  @ApiOperation({ summary: 'Create a new marketplace product listing' })
  createProduct(
    @Body()
    body: {
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
    },
  ) {
    return this.marketplaceService.createProduct(body);
  }

  @Delete('products/:id')
  @ApiOperation({ summary: 'Delete a product listing' })
  deleteProduct(
    @Param('id') productId: string,
    @Query('userId') userId: string = '',
  ) {
    const success = this.marketplaceService.deleteProduct(productId, userId);
    return { success };
  }

  @Post('checkout')
  @ApiOperation({ summary: 'Initiate Bakong KHQR checkout for product' })
  checkout(
    @Body()
    body: {
      productId: string;
      buyerId?: string;
      currency?: string;
    },
  ) {
    return this.marketplaceService.checkout(body);
  }

  @Get('orders/:md5/status')
  @ApiOperation({ summary: 'Check Bakong KHQR transaction settlement status' })
  checkPaymentStatus(@Param('md5') md5: string) {
    return this.marketplaceService.checkPaymentStatus(md5);
  }

  @Get('orders/user/:userId')
  @ApiOperation({ summary: 'Get purchases and sales orders for user' })
  getUserOrders(@Param('userId') userId: string) {
    return this.marketplaceService.getUserOrders(userId);
  }
}
