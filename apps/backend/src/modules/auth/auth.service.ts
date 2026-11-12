import { Injectable, BadRequestException, UnauthorizedException } from '@nestjs/common';
import { DbService, UserEntity } from '../database/db.service';

@Injectable()
export class AuthService {
  constructor(private readonly db: DbService) { }

  register(dto: {
    phone: string;
    name: string;
    username: string;
    password: string;
    email?: string;
  }) {
    const cleanPhone = dto.phone.replace(/[^0-9]/g, '');
    if (cleanPhone.length < 8) {
      throw new BadRequestException('លេខទូរស័ព្ទត្រូវមានយ៉ាងតិច ៨ ខ្ទង់');
    }

    const existingPhone = this.db.findUserByPhone(cleanPhone);
    if (existingPhone) {
      throw new BadRequestException('លេខទូរស័ព្ទនេះត្រូវបានចុះឈ្មោះរួចហើយ');
    }

    const username = (dto.username || `user_${cleanPhone.slice(-4)}`).replace(/^@+/, '').trim();
    const existingUsername = this.db.findUserByUsername(username);
    if (existingUsername) {
      throw new BadRequestException('ឈ្មោះគណនី (username) នេះមានអ្នកប្រើរួចហើយ');
    }

    if (!dto.password || dto.password.length < 6) {
      throw new BadRequestException('ពាក្យសម្ងាត់ត្រូវមានយ៉ាងតិច ៦ តួអក្សរ');
    }

    const newUser = this.db.createUser({
      phone: cleanPhone,
      name: (dto.name || 'User').trim(),
      username: username,
      password: dto.password,
      email: dto.email?.trim() || undefined,
    });

    const token = Buffer.from(
      JSON.stringify({ userId: newUser.id, username: newUser.username, role: newUser.role, time: Date.now() }),
    ).toString('base64');

    return {
      success: true,
      token,
      user: this.toSafeUser(newUser),
    };
  }

  login(dto: { phone: string; password: string }) {
    const cleanPhone = dto.phone.replace(/[^0-9]/g, '');
    const user = this.db.findUserByPhone(cleanPhone);

    if (!user) {
      throw new UnauthorizedException('លេខទូរស័ព្ទ ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវទេ');
    }

    if (!this.db.verifyPassword(user, dto.password)) {
      throw new UnauthorizedException('លេខទូរស័ព្ទ ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវទេ');
    }

    if (user.isBanned) {
      throw new UnauthorizedException('គណនីរបស់អ្នកត្រូវបានផ្អាកដំណើរការដោយ Admin');
    }

    const token = Buffer.from(
      JSON.stringify({ userId: user.id, username: user.username, role: user.role, time: Date.now() }),
    ).toString('base64');

    return {
      success: true,
      token,
      user: this.toSafeUser(user),
    };
  }

  updateProfile(
    userId: string,
    updates: { name?: string; bio?: string; location?: string; avatar?: string; email?: string },
  ) {
    const existing = this.db.findUserById(userId);
    if (!existing) {
      throw new BadRequestException('រកមិនឃើញគណនីនេះទេ');
    }

    const payload: Partial<UserEntity> = {};
    if (updates.bio !== undefined) payload.bio = updates.bio.trim();
    if (updates.location !== undefined) payload.location = updates.location.trim();
    if (updates.avatar !== undefined) payload.avatar = updates.avatar.trim();

    if (updates.email !== undefined) {
      const cleanEmail = updates.email.trim().toLowerCase();
      if (cleanEmail.length > 0) {
        if (!cleanEmail.includes('@') || !cleanEmail.includes('.')) {
          throw new BadRequestException('ទម្រង់អ៊ីមែលមិនត្រឹមត្រូវទេ (Invalid email address)');
        }
        const existingEmailUser = this.db.findUserByEmail(cleanEmail);
        if (existingEmailUser && existingEmailUser.id !== userId) {
          throw new BadRequestException('អ៊ីមែលនេះមានអ្នកប្រើប្រាស់រួចហើយ (Email already in use)');
        }
        payload.email = cleanEmail;
      } else {
        payload.email = undefined;
      }
    }

    if (updates.name && updates.name.trim() !== existing.name) {
      if (existing.lastNameChangeAt) {
        const lastChange = new Date(existing.lastNameChangeAt).getTime();
        const diffMs = Date.now() - lastChange;
        const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
        if (diffMs < sevenDaysMs) {
          const daysLeft = Math.ceil((sevenDaysMs - diffMs) / (24 * 60 * 60 * 1000));
          throw new BadRequestException(`លោកអ្នកអាចប្តូរឈ្មោះម្តងទៀតបាននៅ ${daysLeft} ថ្ងៃទៀត (អនុញ្ញាតប្តូរឈ្មោះ ៧ ថ្ងៃម្តង)`);
        }
      }
      payload.name = updates.name.trim();
      payload.lastNameChangeAt = new Date().toISOString();
    }

    const user = this.db.updateUser(userId, payload);
    if (!user) {
      throw new BadRequestException('រកមិនឃើញគណនីនេះទេ');
    }
    const safeUser = this.toSafeUser(user);
    return {
      success: true,
      user: safeUser,
      data: safeUser,
    };
  }

  async googleLogin(dto: { idToken?: string; email?: string; name?: string; avatar?: string; googleId?: string }) {
    let email = dto.email;
    let name = dto.name;
    let avatar = dto.avatar;
    let googleId = dto.googleId;

    if (dto.idToken) {
      try {
        const verifyRes = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${dto.idToken}`);
        if (verifyRes.ok) {
          const payload = await verifyRes.json();
          if (payload.email) {
            email = payload.email;
            name = name || payload.name;
            avatar = avatar || payload.picture;
            googleId = googleId || payload.sub;
          }
        }
      } catch (err) {
        console.error('Error verifying Google idToken:', err);
      }
    }

    if (!email || !email.includes('@')) {
      throw new BadRequestException('អ៊ីមែលមិនត្រឹមត្រូវទេ');
    }

    const cleanEmail = email.trim().toLowerCase();
    let user = this.db.findUserByEmail(cleanEmail);

    if (!user) {
      const emailPrefix = cleanEmail.split('@')[0];
      const displayName = (name || emailPrefix).trim();
      let username = emailPrefix.toLowerCase().replace(/[^a-z0-9_]/g, '');
      if (username.length < 3) username = `user_${Date.now().toString().slice(-4)}`;

      let finalUsername = username;
      let counter = 1;
      while (this.db.findUserByUsername(finalUsername)) {
        finalUsername = `${username}_${counter++}`;
      }

      user = this.db.createUser({
        phone: `099${Date.now().toString().slice(-6)}`,
        name: displayName,
        username: finalUsername,
        password: `google_${Date.now()}_${Math.random().toString(36).substring(2)}`,
        email: cleanEmail,
      });

      if (avatar) {
        this.db.updateUser(user.id, { avatar });
      }
    } else {
      const updates: any = {};
      if (avatar && (!user.avatar || user.avatar.includes('unsplash.com'))) {
        updates.avatar = avatar;
      }
      if (name && (!user.name || user.name === 'អ្នកប្រើប្រាស់')) {
        updates.name = name;
      }
      if (Object.keys(updates).length > 0) {
        user = this.db.updateUser(user.id, updates) || user;
      }
    }

    const token = Buffer.from(
      JSON.stringify({ userId: user.id, username: user.username, role: user.role, time: Date.now() }),
    ).toString('base64');

    const safeUser = this.toSafeUser(user);
    return {
      success: true,
      token,
      user: safeUser,
      data: {
        success: true,
        token,
        user: safeUser,
      },
    };
  }

  updateStore(
    userId: string,
    data: {
      storeName?: string;
      storePhone?: string;
      storeDescription?: string;
      storeBannerUrl?: string;
      storeThemeColor?: string;
      storeTagline?: string;
      bakongAccountId?: string;
    },
  ) {
    const user = this.db.updateUserStore(userId, data);
    if (!user) {
      throw new BadRequestException('រកមិនឃើញគណនីនេះទេ');
    }
    const safeUser = this.toSafeUser(user);
    return {
      success: true,
      user: safeUser,
      data: safeUser,
    };
  }

  changePassword(userId: string, dto: { oldPassword: string; newPassword: string }) {
    const success = this.db.changePassword(userId, dto.oldPassword, dto.newPassword);
    if (!success) {
      throw new BadRequestException('លេខសម្ងាត់ចាស់មិនត្រឹមត្រូវទេ');
    }
    return { success: true, message: 'លេខសម្ងាត់ត្រូវបានផ្លាស់ប្តូរដោយជោគជ័យ' };
  }

  updateBanner(userId: string, bannerUrl: string) {
    const user = this.db.updateBanner(userId, bannerUrl);
    if (!user) {
      throw new BadRequestException('រកមិនឃើញគណនីនេះទេ');
    }
    const safeUser = this.toSafeUser(user);
    return {
      success: true,
      user: safeUser,
      data: safeUser,
    };
  }

  toggleTwoFactor(userId: string) {
    const enabled = this.db.toggleTwoFactor(userId);
    return { success: true, twoFactorEnabled: enabled };
  }

  subscribeTier(userId: string, tier: 'PRO_PLUS' | 'ULTRA', durationMonths: number = 1) {
    const user = this.db.subscribeTier(userId, tier, durationMonths);
    if (!user) {
      throw new BadRequestException('រកមិនឃើញគណនីនេះទេ');
    }
    return { success: true, user: this.toSafeUser(user) };
  }

  async checkoutVip(dto: {
    userId: string;
    tier: 'PRO_PLUS' | 'ULTRA';
    durationMonths?: number;
    amount?: number;
    currency?: string;
  }) {
    const user = this.db.findUserById(dto.userId);
    if (!user) {
      throw new BadRequestException('រកមិនឃើញគណនីនេះទេ');
    }

    const durationMonths = dto.durationMonths || (dto.tier === 'ULTRA' ? 12 : 1);
    let amount = dto.amount;
    if (!amount || amount <= 0) {
      if (dto.tier === 'PRO_PLUS') {
        amount = durationMonths === 2 ? 3.0 : 0.5;
      } else {
        amount = 15.0;
      }
    }

    const currency = dto.currency || 'USD';
    const billNumber = `VIP-${Date.now()}`;
    const accountId = 'chansocheat_vin@bkrt';
    const merchantName = 'CHAN SOCHEAT';

    try {
      const response = await fetch(`https://lorndavid.online/api/v1/khqr/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          accountId,
          merchantName,
          merchantCity: 'Phnom Penh',
          amount: parseFloat(amount.toString()),
          currency,
          storeLabel: 'Spaces VIP Blue Checkmark',
          terminalLabel: 'SPACES_VIP',
          billNumber,
        }),
      });

      const data = await response.json();
      if (!response.ok || !data.qrString || !data.md5) {
        throw new BadRequestException(data.message || 'បរាជ័យក្នុងការបង្កើត KHQR VIP Gateway');
      }

      this.db.createOrder({
        billNumber,
        productId: `vip-${dto.tier.toLowerCase()}-${durationMonths}m`,
        productTitle: `Spaces VIP Verified Blue Badge (${dto.tier} ${durationMonths} Months)`,
        amount: parseFloat(amount.toString()),
        currency,
        buyerId: user.id,
        buyerName: user.name,
        sellerId: 'admin-1',
        sellerName: 'CHAN SOCHEAT',
        sellerStoreName: 'Spaces Platform VIP',
        sellerBakongId: accountId,
        md5: data.md5,
        qrString: data.qrString,
        qrImage: data.qrImage,
        deeplink: data.deeplink,
      });

      return {
        success: true,
        billNumber,
        md5: data.md5,
        qrString: data.qrString,
        qrImage: data.qrImage,
        deeplink: data.deeplink,
        amount: parseFloat(amount.toString()),
        currency,
        tier: dto.tier,
        durationMonths,
      };
    } catch (err: any) {
      console.error('[AuthService VIP KHQR Error]', err);
      throw new BadRequestException(`KHQR Gateway Error: ${err.message || 'Cannot generate payment'}`);
    }
  }

  async checkVipStatus(md5: string) {
    const order = this.db.getOrderByMd5(md5);
    if (!order) {
      throw new BadRequestException('រកមិនឃើញប្រតិបត្តិការនេះទេ (Order not found)');
    }

    if (order.status === 'PAID') {
      const user = this.db.findUserById(order.buyerId);
      return {
        success: true,
        paid: true,
        status: 'PAID',
        user: user ? this.toSafeUser(user) : null,
      };
    }

    try {
      const response = await fetch(`https://lorndavid.online/api/v1/check/${md5}`);
      const result = await response.json();

      if (result.responseCode === 0) {
        this.db.updateOrderStatus(md5, 'PAID', result.data);
        let tier: 'PRO_PLUS' | 'ULTRA' = 'PRO_PLUS';
        if (order.productId.includes('ultra')) tier = 'ULTRA';
        let months = 1;
        const mMatch = order.productId.match(/-(\d+)m/);
        if (mMatch) months = parseInt(mMatch[1], 10);

        const updatedUser = this.db.subscribeTier(order.buyerId, tier, months);

        return {
          success: true,
          paid: true,
          status: 'PAID',
          transactionData: result.data,
          user: updatedUser ? this.toSafeUser(updatedUser) : null,
        };
      }

      return {
        success: true,
        paid: false,
        status: 'PENDING',
        message: result.responseMessage || 'កំពុងរង់ចាំការទូទាត់ប្រាក់...',
      };
    } catch (err: any) {
      console.error('[Check VIP Status Error]', err);
      return {
        success: false,
        paid: false,
        status: 'ERROR',
        message: err.message || 'Error checking payment status',
      };
    }
  }

  getUserProfile(usernameOrId: string, currentUserId?: string) {
    let user = this.db.findUserByUsername(usernameOrId);
    if (!user) {
      user = this.db.findUserById(usernameOrId);
    }
    if (!user) {
      return null;
    }
    const counts = this.db.getFollowCounts(user.id);
    const isFollowing = currentUserId ? this.db.isFollowing(currentUserId, user.id) : false;
    const isSelf = currentUserId && currentUserId === user.id;
    const base = isSelf
      ? this.toSafeUser(user)
      : {
        id: user.id,
        name: user.name,
        username: user.username,
        bio: user.bio || '',
        location: user.location || 'Phnom Penh, Cambodia',
        avatar: user.avatar,
        bannerUrl: user.bannerUrl || '',
        storeName: user.storeName || '',
        storeDescription: user.storeDescription || '',
        storeBannerUrl: user.storeBannerUrl || '',
        storeThemeColor: user.storeThemeColor || '#0A84FF',
        storeTagline: user.storeTagline || '',
        subscriptionTier: user.subscriptionTier || 'FREE',
        role: user.role,
        isVerified: user.isVerified,
        createdAt: user.createdAt,
      };
    return {
      ...base,
      followerCount: counts.followersCount,
      followingCount: counts.followingCount,
      isFollowing,
    };
  }

  toggleFollow(followerId: string, usernameOrId: string) {
    let target = this.db.findUserByUsername(usernameOrId);
    if (!target) {
      target = this.db.findUserById(usernameOrId);
    }
    if (!target) {
      throw new BadRequestException('រកមិនឃើញអ្នកប្រើប្រាស់នេះទេ');
    }
    const isFollowing = this.db.toggleFollow(followerId, target.id);
    return { success: true, isFollowing };
  }

  getAllUsers() {
    return this.db.getAllUsers();
  }

  searchUsers(query: string, currentUserId?: string) {
    return this.db.searchUsers(query, currentUserId);
  }

  saveFcmToken(userId: string, fcmToken: string) {
    const ok = this.db.saveUserFcmToken(userId, fcmToken);
    return { success: ok };
  }

  toggleBan(userId: string) {
    const isBanned = this.db.toggleBanUser(userId);
    return { success: true, isBanned };
  }

  deleteUserByAdmin(userId: string) {
    const user = this.db.findUserById(userId);
    if (!user) {
      throw new BadRequestException('រកមិនឃើញគណនីនេះទេ (User not found)');
    }
    if (user.role === 'ADMIN') {
      throw new BadRequestException('មិនអាចលុបគណនី Admin បានទេ (Protected Admin Account)');
    }
    const deleted = this.db.deleteUser(userId);
    return { success: deleted, userId };
  }

  deleteUsersBatchByAdmin(userIds: string[]) {
    const deletedCount = this.db.deleteUsersBatch(userIds || []);
    return { success: true, deletedCount };
  }

  clearUserContentByAdmin(userId: string) {
    const user = this.db.findUserById(userId);
    if (!user) {
      throw new BadRequestException('រកមិនឃើញគណនីនេះទេ');
    }
    const summary = this.db.clearUserContent(userId);
    return {
      success: true,
      userId,
      userName: user.name,
      ...summary,
    };
  }

  getAdminStats() {
    return this.db.getStats();
  }

  getReportsByAdmin() {
    return this.db.getReports();
  }

  resolveReportByAdmin(reportId: string, action: 'DISMISS' | 'DELETE_POST' | 'BAN_USER') {
    return this.db.resolveReport(reportId, action);
  }

  private toSafeUser(user: UserEntity) {
    return {
      id: user.id,
      phone: user.phone,
      name: user.name,
      username: user.username,
      email: user.email,
      bio: user.bio || '',
      location: user.location || 'Phnom Penh, Cambodia',
      avatar: user.avatar,
      storeName: user.storeName || '',
      storePhone: user.storePhone || '',
      storeDescription: user.storeDescription || '',
      storeBannerUrl: user.storeBannerUrl || '',
      storeThemeColor: user.storeThemeColor || '#0A84FF',
      storeTagline: user.storeTagline || '',
      bakongAccountId: user.bakongAccountId || '',
      bannerUrl: user.bannerUrl || '',
      twoFactorEnabled: user.twoFactorEnabled || false,
      subscriptionTier: user.subscriptionTier || 'FREE',
      subscriptionExpiresAt: user.subscriptionExpiresAt,
      role: user.role,
      isVerified: user.isVerified,
      createdAt: user.createdAt,
    };
  }
}
