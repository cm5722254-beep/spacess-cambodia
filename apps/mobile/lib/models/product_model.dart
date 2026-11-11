class ProductModel {
  final String id;
  final String title;
  final double priceUsd;
  final int priceKhr;
  final String category;
  final String condition;
  final String imageUrl;
  final String location;
  final String description;
  final String sellerId;
  final String sellerName;
  final String sellerPhone;
  final String sellerAvatar;
  final String? sellerStoreName;
  final String? sellerStoreDescription;
  final String? sellerStoreBannerUrl;
  final String? sellerStoreThemeColor;
  final String? sellerStoreTagline;
  final String? sellerBakongId;
  final String? createdAt;

  ProductModel({
    required this.id,
    required this.title,
    required this.priceUsd,
    required this.priceKhr,
    required this.category,
    required this.condition,
    required this.imageUrl,
    required this.location,
    required this.description,
    required this.sellerId,
    required this.sellerName,
    required this.sellerPhone,
    required this.sellerAvatar,
    this.sellerStoreName,
    this.sellerStoreDescription,
    this.sellerStoreBannerUrl,
    this.sellerStoreThemeColor,
    this.sellerStoreTagline,
    this.sellerBakongId,
    this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      priceUsd: (json['priceUsd'] is num) ? (json['priceUsd'] as num).toDouble() : 0.0,
      priceKhr: (json['priceKhr'] is num) ? (json['priceKhr'] as num).toInt() : 0,
      category: json['category']?.toString() ?? 'Electronics',
      condition: json['condition']?.toString() ?? 'ថ្មី',
      imageUrl: json['imageUrl']?.toString() ??
          'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&w=800&q=80',
      location: json['location']?.toString() ?? 'ភ្នំពេញ (Phnom Penh)',
      description: json['description']?.toString() ?? '',
      sellerId: json['sellerId']?.toString() ?? '',
      sellerName: json['sellerName']?.toString() ?? 'អ្នកលក់',
      sellerPhone: json['sellerPhone']?.toString() ?? '012 345 678',
      sellerAvatar: (json['sellerAvatar'] != null && json['sellerAvatar'].toString().isNotEmpty)
          ? json['sellerAvatar'].toString()
          : '/default_avatar.svg',
      sellerStoreName: json['sellerStoreName']?.toString(),
      sellerStoreDescription: json['sellerStoreDescription']?.toString(),
      sellerStoreBannerUrl: json['sellerStoreBannerUrl']?.toString(),
      sellerStoreThemeColor: json['sellerStoreThemeColor']?.toString(),
      sellerStoreTagline: json['sellerStoreTagline']?.toString(),
      sellerBakongId: json['sellerBakongId']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

