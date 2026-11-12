import { Controller, Post, Get, Patch, Delete, Body, Param, Query, Headers } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AuthService } from './auth.service';

@ApiTags('Authentication & Admin')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @ApiOperation({ summary: 'Register with phone number, password, name, and username' })
  register(
    @Body()
    body: {
      phone: string;
      name: string;
      username: string;
      password: string;
      email?: string;
    },
  ) {
    return this.authService.register(body);
  }

  @Post('login')
  @ApiOperation({ summary: 'Login with phone number and password' })
  login(
    @Body()
    body: {
      phone: string;
      password: string;
    },
  ) {
    return this.authService.login(body);
  }

  @Post('google')
  @ApiOperation({ summary: 'Sign in or register with Google OAuth / Gmail profile' })
  googleLogin(
    @Body()
    body: {
      idToken?: string;
      email?: string;
      name?: string;
      avatar?: string;
      googleId?: string;
    },
  ) {
    return this.authService.googleLogin(body);
  }

  private extractUserId(authHeader?: string, bodyUserId?: string): string {
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const decoded = JSON.parse(Buffer.from(authHeader.replace('Bearer ', ''), 'base64').toString('utf8'));
        if (decoded && decoded.userId) return decoded.userId;
      } catch (e) {}
    }
    if (bodyUserId) return bodyUserId;
    return '';
  }

  @Patch('profile')
  @ApiOperation({ summary: 'Update user profile (name, bio, location, avatar, email)' })
  updateProfile(
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
      userId?: string;
      name?: string;
      bio?: string;
      location?: string;
      avatar?: string;
      email?: string;
    },
  ) {
    const userId = this.extractUserId(authHeader, body.userId);
    return this.authService.updateProfile(userId, body);
  }

  @Patch('store')
  @ApiOperation({ summary: 'Update user store settings and decoration' })
  updateStore(
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
      userId?: string;
      storeName?: string;
      storePhone?: string;
      storeDescription?: string;
      storeBannerUrl?: string;
      storeThemeColor?: string;
      storeTagline?: string;
      bakongAccountId?: string;
    },
  ) {
    const userId = this.extractUserId(authHeader, body.userId);
    return this.authService.updateStore(userId, body);
  }

  @Post('change-password')
  @ApiOperation({ summary: 'Change user password with old password verification' })
  changePassword(
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
      userId?: string;
      oldPassword: string;
      newPassword: string;
    },
  ) {
    const userId = this.extractUserId(authHeader, body.userId);
    return this.authService.changePassword(userId, body);
  }

  @Patch('banner')
  @ApiOperation({ summary: 'Update user profile cover banner' })
  updateBanner(
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
      userId?: string;
      bannerUrl: string;
    },
  ) {
    const userId = this.extractUserId(authHeader, body.userId);
    return this.authService.updateBanner(userId, body.bannerUrl);
  }

  @Patch('2fa')
  @ApiOperation({ summary: 'Toggle 2-Factor Authentication' })
  toggleTwoFactor(
    @Body()
    body: {
      userId: string;
    },
  ) {
    return this.authService.toggleTwoFactor(body.userId);
  }

  @Post('subscribe')
  @ApiOperation({ summary: 'Subscribe to Pro Plus or Ultra tier' })
  subscribeTier(
    @Body()
    body: {
      userId: string;
      tier: 'PRO_PLUS' | 'ULTRA';
      durationMonths?: number;
    },
  ) {
    return this.authService.subscribeTier(body.userId, body.tier, body.durationMonths || 1);
  }

  @Post('vip/checkout')
  @ApiOperation({ summary: 'Generate Bakong KHQR for VIP Subscription & Blue Checkmark' })
  checkoutVip(
    @Body()
    body: {
      userId: string;
      tier: 'PRO_PLUS' | 'ULTRA';
      durationMonths?: number;
      amount?: number;
      currency?: string;
    },
  ) {
    return this.authService.checkoutVip(body);
  }

  @Get('vip/status/:md5')
  @ApiOperation({ summary: 'Check VIP Bakong Payment Status by MD5 and unlock badge' })
  checkVipStatus(@Param('md5') md5: string) {
    return this.authService.checkVipStatus(md5);
  }

  @Get('users/:username')
  @ApiOperation({ summary: 'Get user profile with followers count' })
  getUserProfile(
    @Param('username') username: string,
    @Query('currentUserId') currentUserId?: string,
  ) {
    return this.authService.getUserProfile(username, currentUserId);
  }

  @Post('users/:username/follow')
  @ApiOperation({ summary: 'Toggle follow user' })
  toggleFollow(
    @Param('username') username: string,
    @Body() body: { followerId: string },
  ) {
    return this.authService.toggleFollow(body.followerId, username);
  }

  @Get('search')
  @ApiOperation({ summary: 'Search users by name, username, or phone' })
  searchUsers(
    @Query('q') query: string = '',
    @Query('currentUserId') currentUserId?: string,
  ) {
    return this.authService.searchUsers(query, currentUserId);
  }

  @Post('fcm-token')
  @ApiOperation({ summary: 'Register Firebase Cloud Messaging (FCM) device token' })
  saveFcmToken(
    @Headers('authorization') authHeader: string,
    @Body() body: { userId?: string; fcmToken: string },
  ) {
    const userId = this.extractUserId(authHeader, body.userId);
    return this.authService.saveFcmToken(userId, body.fcmToken);
  }

  @Get('admin/users')
  @ApiOperation({ summary: 'Admin: Get all registered users' })
  getUsers() {
    return this.authService.getAllUsers();
  }

  @Patch('admin/users/:id/ban')
  @ApiOperation({ summary: 'Admin: Ban or unban a user' })
  toggleBan(@Param('id') userId: string) {
    return this.authService.toggleBan(userId);
  }

  @Post('admin/users/batch-delete')
  @ApiOperation({ summary: 'Admin: Delete multiple selected user accounts' })
  deleteUsersBatch(@Body() body: { userIds: string[] }) {
    return this.authService.deleteUsersBatchByAdmin(body.userIds);
  }

  @Delete('admin/users/:id')
  @ApiOperation({ summary: 'Admin: Delete a user account and associated data' })
  deleteUser(@Param('id') userId: string) {
    return this.authService.deleteUserByAdmin(userId);
  }

  @Post('admin/users/:id/clear-content')
  @ApiOperation({ summary: 'Admin: Clear all posts, videos, stories, and comments for a user without modifying name' })
  clearUserContent(@Param('id') userId: string) {
    return this.authService.clearUserContentByAdmin(userId);
  }

  @Get('admin/stats')
  @ApiOperation({ summary: 'Admin: Get system and platform analytics' })
  getStats() {
    return this.authService.getAdminStats();
  }

  @Get('admin/reports')
  @ApiOperation({ summary: 'Admin: List all submitted user/post reports' })
  getReports() {
    return this.authService.getReportsByAdmin();
  }

  @Post('admin/reports/:id/resolve')
  @ApiOperation({ summary: 'Admin: Resolve or dismiss a report' })
  resolveReport(
    @Param('id') reportId: string,
    @Body() body: { action: 'DISMISS' | 'DELETE_POST' | 'BAN_USER' },
  ) {
    return this.authService.resolveReportByAdmin(reportId, body.action || 'DISMISS');
  }
}
