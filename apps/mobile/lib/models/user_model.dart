class UserModel {
  final String id;
  final String phone;
  final String name;
  final String username;
  final String? email;
  final String avatar;
  final String? bannerUrl;
  final String? bio;
  final String? location;
  final String? storeName;
  final String? storePhone;
  final String? storeDescription;
  final String? storeBannerUrl;
  final String? storeThemeColor;
  final String? storeTagline;
  final String? bakongAccountId;
  final bool twoFactorEnabled;
  final String subscriptionTier; // 'FREE', 'PRO_PLUS', 'ULTRA'
  final String? subscriptionExpiresAt;
  final String role;
  final bool isVerified;
  final bool isBanned;
  final String? createdAt;

  UserModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.username,
    this.email,
    required this.avatar,
    this.bannerUrl,
    this.bio,
    this.location,
    this.storeName,
    this.storePhone,
    this.storeDescription,
    this.storeBannerUrl,
    this.storeThemeColor,
    this.storeTagline,
    this.bakongAccountId,
    this.twoFactorEnabled = false,
    this.subscriptionTier = 'FREE',
    this.subscriptionExpiresAt,
    required this.role,
    this.isVerified = false,
    this.isBanned = false,
    this.createdAt,
  });

  bool get isAdmin => role == 'ADMIN';
  bool get isProPlus => subscriptionTier == 'PRO_PLUS';
  bool get isUltra => subscriptionTier == 'ULTRA';
  bool get isVip => isProPlus || isUltra;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      avatar: json['avatar'] ?? '/default_avatar.svg',
      bannerUrl: json['bannerUrl'],
      bio: json['bio'],
      location: json['location'],
      storeName: json['storeName'],
      storePhone: json['storePhone'],
      storeDescription: json['storeDescription'],
      storeBannerUrl: json['storeBannerUrl'],
      storeThemeColor: json['storeThemeColor'],
      storeTagline: json['storeTagline'],
      bakongAccountId: json['bakongAccountId'] ?? '',
      twoFactorEnabled: json['twoFactorEnabled'] ?? false,
      subscriptionTier: json['subscriptionTier'] ?? 'FREE',
      subscriptionExpiresAt: json['subscriptionExpiresAt'],
      role: json['role'] ?? 'USER',
      isVerified: json['isVerified'] == true,
      isBanned: json['isBanned'] ?? false,
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'username': username,
        'email': email,
        'avatar': avatar,
        'bannerUrl': bannerUrl,
        'bio': bio,
        'location': location,
        'storeName': storeName,
        'storePhone': storePhone,
        'storeDescription': storeDescription,
        'storeBannerUrl': storeBannerUrl,
        'storeThemeColor': storeThemeColor,
        'storeTagline': storeTagline,
        'bakongAccountId': bakongAccountId,
        'twoFactorEnabled': twoFactorEnabled,
        'subscriptionTier': subscriptionTier,
        'subscriptionExpiresAt': subscriptionExpiresAt,
        'role': role,
        'isVerified': isVerified,
        'isBanned': isBanned,
        'createdAt': createdAt,
      };
}

class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final int totalSpaces;
  final int totalPosts;
  final int totalReactions;
  final int serverUptimeSeconds;
  final String systemVersion;

  AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalSpaces,
    required this.totalPosts,
    required this.totalReactions,
    required this.serverUptimeSeconds,
    required this.systemVersion,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['totalUsers'] ?? 0,
      activeUsers: json['activeUsers'] ?? 0,
      totalSpaces: json['totalSpaces'] ?? 0,
      totalPosts: json['totalPosts'] ?? 0,
      totalReactions: json['totalReactions'] ?? 0,
      serverUptimeSeconds: json['serverUptimeSeconds'] ?? 0,
      systemVersion: json['systemVersion'] ?? 'Spaces Cambodia 1.0.0',
    );
  }
}

class PublicUserModel {
  final String id;
  final String name;
  final String username;
  final String avatar;
  final String bio;
  final String location;
  final bool isVerified;
  final int followerCount;
  bool isFollowing;
  String friendStatus; // 'NONE', 'PENDING_SENT', 'PENDING_RECEIVED', 'ACCEPTED'
  String? friendRequestId;

  PublicUserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.avatar,
    this.bio = '',
    this.location = 'Cambodia',
    this.isVerified = false,
    this.followerCount = 0,
    this.isFollowing = false,
    this.friendStatus = 'NONE',
    this.friendRequestId,
  });

  factory PublicUserModel.fromJson(Map<String, dynamic> json) {
    return PublicUserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Spaces User',
      username: json['username'] ?? '',
      avatar: json['avatar'] ?? '/default_avatar.svg',
      bio: json['bio'] ?? '',
      location: json['location'] ?? 'Cambodia',
      isVerified: json['isVerified'] == true,
      followerCount: json['followerCount'] ?? 0,
      isFollowing: json['isFollowing'] == true,
      friendStatus: json['friendStatus'] ?? 'NONE',
      friendRequestId: json['friendRequestId'] ?? json['requestId'],
    );
  }
}


