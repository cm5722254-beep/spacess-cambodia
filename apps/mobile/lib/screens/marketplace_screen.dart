import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/realtime_service.dart';
import '../services/theme_service.dart';
import '../utils/media_picker_helper.dart';
import '../widgets/bakong_payment_sheet.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/media_image_view.dart';
import 'chat_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final ApiService _api = ApiService();
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'labelKm': 'ទាំងអស់', 'labelEn': 'All', 'icon': CupertinoIcons.square_grid_2x2_fill},
    {'id': 'Electronics', 'labelKm': 'អេឡិចត្រូនិក', 'labelEn': 'Electronics', 'icon': CupertinoIcons.device_phone_portrait},
    {'id': 'Vehicles', 'labelKm': 'យានយន្ត', 'labelEn': 'Vehicles', 'icon': CupertinoIcons.car_detailed},
    {'id': 'Fashion', 'labelKm': 'សម្លៀកបំពាក់', 'labelEn': 'Fashion', 'icon': CupertinoIcons.bag_fill},
    {'id': 'Food', 'labelKm': 'ម្ហូប & កសិផល', 'labelEn': 'Food & Agri', 'icon': CupertinoIcons.cart_fill},
    {'id': 'Other', 'labelKm': 'ផ្សេងៗ', 'labelEn': 'Other', 'icon': CupertinoIcons.cube_box_fill},
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final prods = await _api.fetchProducts(
      category: _selectedCategory,
      query: _searchQuery,
    );
    if (mounted) {
      setState(() {
        _products = prods;
        _isLoading = false;
      });
    }
  }

  void _onCategorySelected(String categoryId) {
    setState(() {
      _selectedCategory = categoryId;
    });
    _loadProducts();
  }

  void _openProductDetail(ProductModel product) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _ProductDetailSheet(
        product: product,
        onProductDeleted: () => _loadProducts(),
      ),
    );
  }

  void _openCreateProductSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _CreateProductSheet(
        onProductCreated: () => _loadProducts(),
      ),
    );
  }

  void _openOrdersTrackingSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => const _OrdersTrackingSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.scaffoldBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppTheme.navBarBg,
        middle: Text(
          tr('ផ្សារទំនិញ (Marketplace)', 'Spaces Marketplace'),
          style: TextStyle(color: AppTheme.primaryText, fontWeight: FontWeight.w700),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: _openOrdersTrackingSheet,
              child: const Icon(CupertinoIcons.cube_box_fill, size: 20, color: Color(0xFF34C759)),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _openCreateProductSheet,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.plus_circle_fill, size: 20, color: Color(0xFF007AFF)),
                  const SizedBox(width: 4),
                  Text(
                    tr('ដាក់លក់', 'Sell'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF007AFF)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CupertinoSearchTextField(
                placeholder: tr('ស្វែងរកទំនិញ ឧបករណ៍ ឡាន ម៉ូតូ...', 'Search products, electronics, vehicles...'),
                style: TextStyle(color: AppTheme.primaryText),
                backgroundColor: AppTheme.fieldBg,
                onSubmitted: (val) {
                  setState(() => _searchQuery = val);
                  _loadProducts();
                },
                onSuffixTap: () {
                  setState(() => _searchQuery = '');
                  _loadProducts();
                },
              ),
            ),

            // Category Chips Row
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat['id'];
                  final label = tr(cat['labelKm'] as String, cat['labelEn'] as String);
                  final icon = cat['icon'] as IconData;

                  return LiquidGlassPill(
                    label: label,
                    icon: icon,
                    isSelected: isSelected,
                    onTap: () => _onCategorySelected(cat['id'] as String),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),

            // Products Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.bag, size: 48, color: AppTheme.tertiaryText),
                              const SizedBox(height: 12),
                              Text(
                                tr('គ្មានទំនិញសម្រាប់លក្ខខណ្ឌស្វែងរកនេះទេ', 'No products found'),
                                style: TextStyle(color: AppTheme.secondaryText, fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            CupertinoSliverRefreshControl(onRefresh: _loadProducts),
                            SliverPadding(
                              padding: EdgeInsets.all(ResponsiveLayout.horizontalPadding(context)),
                              sliver: SliverGrid(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: ResponsiveLayout.marketplaceColumns(
                                    MediaQuery.of(context).size.width,
                                  ),
                                  childAspectRatio: ResponsiveLayout.isCompact(context) ? 0.65 : 0.72,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final p = _products[index];
                                    return _buildProductCard(p);
                                  },
                                  childCount: _products.length,
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(height: ResponsiveLayout.bottomDockClearance(context)),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel p) {
    return LiquidGlassPressable(
      onTap: () => _openProductDetail(p),
      child: LiquidGlassContainer(
        borderRadius: 18,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaImageView(
                    url: p.imageUrl,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xCC000000),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.location.split(' ')[0],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${p.priceUsd.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryText,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.sellerName} • ${p.condition}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailSheet extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onProductDeleted;

  const _ProductDetailSheet({required this.product, this.onProductDeleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppTheme.modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MediaImageView(
                    url: product.imageUrl,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),

                // Price Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${product.priceUsd.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                    Text(
                      '~ ${product.priceKhr.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ៛',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  product.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 8),

                // Category & Location Badges
                Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.category,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.primaryText),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.condition,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF34C759),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.location,
                        style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  tr('ព័ត៌មានលម្អិតអំពីទំនិញ:', 'Product Details:'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                ),
                const SizedBox(height: 6),
                Text(
                  product.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.primaryText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                if ((product.sellerStoreBannerUrl ?? '').isNotEmpty ||
                    (product.sellerStoreTagline ?? '').isNotEmpty ||
                    (product.sellerStoreDescription ?? '').isNotEmpty) ...[
                  Builder(
                    builder: (_) {
                      Color storeAccent = const Color(0xFF007AFF);
                      final rawHex = (product.sellerStoreThemeColor ?? '').replaceAll('#', '').trim();
                      if (rawHex.length == 6) {
                        final parsed = int.tryParse('FF$rawHex', radix: 16);
                        if (parsed != null) storeAccent = Color(parsed);
                      }
                      final bannerUrl = product.sellerStoreBannerUrl ?? '';
                      final storeName = (product.sellerStoreName ?? '').isNotEmpty
                          ? product.sellerStoreName!
                          : product.sellerName;
                      final tagline = product.sellerStoreTagline ?? '';
                      final storeDesc = product.sellerStoreDescription ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              storeAccent.withOpacity(0.16),
                              storeAccent.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: storeAccent.withOpacity(0.45), width: 1),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (bannerUrl.isNotEmpty)
                              SizedBox(
                                height: 96,
                                width: double.infinity,
                                child: MediaImageView(
                                  url: bannerUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(CupertinoIcons.sparkles, size: 15, color: storeAccent),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          storeName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primaryText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (tagline.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      tagline,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: storeAccent,
                                      ),
                                    ),
                                  ],
                                  if (storeDesc.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      storeDesc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],

                // Seller Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: MediaImageView(
                          url: product.sellerAvatar,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.sellerName,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${tr("លេខទូរស័ព្ទ", "Phone")}: ${product.sellerPhone}',
                              style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                            ),
                            if (product.sellerBakongId != null && product.sellerBakongId!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(CupertinoIcons.checkmark_seal_fill, size: 12, color: Color(0xFFE1251B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr('ទទួលការទូទាត់ Bakong KHQR', 'Accepts Bakong KHQR'),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE1251B)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Button: Buy with Bakong KHQR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: CupertinoButton(
              color: const Color(0xFFE1251B), // Bakong Red
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: () {
                Navigator.pop(context);
                showCupertinoModalPopup(
                  context: context,
                  builder: (ctx) => BakongPaymentSheet(product: product),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.qrcode_viewfinder, color: CupertinoColors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    tr('ទិញតាម Bakong KHQR (Pay with Bakong)', 'Pay with Bakong KHQR'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Button: Chat to Buy
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: CupertinoButton(
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.symmetric(vertical: 14),
              onPressed: () async {
                final me = ApiService().currentUser;
                final rootNav = Navigator.of(context, rootNavigator: true);
                if (me == null) {
                  Navigator.pop(context);
                  return;
                }
                if (me.id == product.sellerId) {
                  showCupertinoDialog(
                    context: context,
                    builder: (ctx) => CupertinoAlertDialog(
                      title: Text(tr('ទំនិញរបស់អ្នកផ្ទាល់', 'Your Own Listing')),
                      content: Text(
                        tr(
                          'អ្នកជាម្ចាស់ទំនិញនេះផ្ទាល់ (មិនអាចឆាតទៅខ្លួនឯងបានទេ)។',
                          'You are the seller of this product.',
                        ),
                      ),
                      actions: [
                        CupertinoDialogAction(
                          child: Text(tr('យល់ព្រម', 'OK')),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                final chat = await ApiService().getOrCreateDirectChat(product.sellerId);
                if (context.mounted) {
                  Navigator.pop(context);
                }
                if (chat != null) {
                  rootNav.push(
                    CupertinoPageRoute(
                      builder: (_) => ChatConversationScreen(
                        chat: chat,
                        initialDraft: tr(
                          'សួស្តី! ខ្ញុំចាប់អារម្មណ៍ទិញទំនិញ "${product.title}" (\$${product.priceUsd.toStringAsFixed(0)})។',
                          'Hi! I am interested in buying "${product.title}" (\$${product.priceUsd.toStringAsFixed(0)}).',
                        ),
                      ),
                    ),
                  );
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.chat_bubble_text_fill, size: 20, color: CupertinoColors.white),
                  const SizedBox(width: 8),
                  Text(
                    tr('ផ្ញើសារទិញ (Chat with Seller)', 'Chat with Seller'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Delete product if author or admin
          Builder(
            builder: (ctx) {
              final user = ApiService().currentUser;
              final canDelete = (user != null && user.id == product.sellerId) || (user?.isAdmin ?? false);
              if (!canDelete) return const SizedBox(height: 16);

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: CupertinoButton(
                  color: AppTheme.surfaceBg,
                  borderRadius: BorderRadius.circular(14),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () {
                    Navigator.pop(context);
                    showCupertinoDialog(
                      context: context,
                      builder: (alertCtx) => CupertinoAlertDialog(
                        title: Text(tr('លុបទំនិញ', 'Delete Product')),
                        content: Text(tr(
                          'តើអ្នកពិតជាចង់លុបទំនិញ "${product.title}" មែនទេ?',
                          'Are you sure you want to delete "${product.title}"?',
                        )),
                        actions: [
                          CupertinoDialogAction(
                            child: Text(tr('បោះបង់', 'Cancel')),
                            onPressed: () => Navigator.pop(alertCtx),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            child: Text(tr('លុប', 'Delete')),
                            onPressed: () async {
                              Navigator.pop(alertCtx);
                              final ok = await ApiService().deleteProduct(product.id);
                              if (ok) {
                                onProductDeleted?.call();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.delete, color: CupertinoColors.destructiveRed, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        tr('លុបទំនិញនេះ (Delete Listing)', 'Delete Listing'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.destructiveRed,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CreateProductSheet extends StatefulWidget {
  final VoidCallback onProductCreated;

  const _CreateProductSheet({required this.onProductCreated});

  @override
  State<_CreateProductSheet> createState() => _CreateProductSheetState();
}

class _CreateProductSheetState extends State<_CreateProductSheet> {
  // Completely empty controllers - ZERO auto-filling or demo values!
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController(text: 'ភ្នំពេញ (Phnom Penh)');
  final TextEditingController _imageUrlCtrl = TextEditingController();
  final TextEditingController _storeNameCtrl = TextEditingController();
  final TextEditingController _bakongIdCtrl = TextEditingController();

  String _selectedCategory = 'Electronics';
  String _selectedCondition = 'ថ្មី (Brand New)';
  String? _importedMediaUrl; // User's chosen photo/video from device
  bool _isLoading = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    final me = ApiService().currentUser;
    if (me != null) {
      if ((me.storeName ?? '').isNotEmpty) {
        _storeNameCtrl.text = me.storeName!;
      }
      if ((me.bakongAccountId ?? '').isNotEmpty) {
        _bakongIdCtrl.text = me.bakongAccountId!;
      }
    }
  }

  final List<Map<String, String>> _categories = [
    {'id': 'Electronics', 'labelKm': 'អេឡិចត្រូនិក', 'labelEn': 'Electronics'},
    {'id': 'Vehicles', 'labelKm': 'យានយន្ត', 'labelEn': 'Vehicles'},
    {'id': 'Fashion', 'labelKm': 'សម្លៀកបំពាក់', 'labelEn': 'Fashion'},
    {'id': 'Food', 'labelKm': 'ម្ហូប & កសិផល', 'labelEn': 'Food & Agri'},
    {'id': 'Other', 'labelKm': 'ផ្សេងៗ', 'labelEn': 'Other'},
  ];

  final List<String> _conditions = [
    'ថ្មី (Brand New)',
    'មួយទឹក 99% (Like New)',
    'មួយទឹកធម្មតា (Used)',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _imageUrlCtrl.dispose();
    _storeNameCtrl.dispose();
    _bakongIdCtrl.dispose();
    super.dispose();
  }

  void _pickMediaFromDevice() async {
    setState(() => _isImporting = true);
    final media = await MediaPickerHelper.pickAndUploadMedia(accept: 'image/*,video/*');
    if (mounted) {
      setState(() {
        _isImporting = false;
        if (media != null && media.isNotEmpty) {
          _importedMediaUrl = media;
        }
      });
    }
  }

  void _submit() async {
    final title = _titleCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    final desc = _descCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final storeName = _storeNameCtrl.text.trim();
    final bakongId = _bakongIdCtrl.text.trim();

    if (title.isEmpty) {
      _showError(tr('សូមបញ្ចូលឈ្មោះទំនិញ', 'Please enter product title'));
      return;
    }
    if (price <= 0) {
      _showError(tr('សូមបញ្ចូលតម្លៃទំនិញដែលត្រឹមត្រូវ', 'Please enter valid price in USD'));
      return;
    }
    if (desc.isEmpty) {
      _showError(tr('សូមបញ្ចូលការពិពណ៌នាអំពីទំនិញ', 'Please enter product description'));
      return;
    }
    if (bakongId.isEmpty || !bakongId.contains('@')) {
      _showError(tr(
        'សូមបញ្ចូល Bakong Account ID ផ្ទាល់ខ្លួនរបស់អ្នក (ឧ. name@bkrt) ដើម្បីទទួលប្រាក់ KHQR',
        'Please enter your personal Bakong Account ID (e.g. name@bkrt) to receive KHQR payments',
      ));
      return;
    }

    final finalImageUrl = _importedMediaUrl ?? _imageUrlCtrl.text.trim();
    if (finalImageUrl.isEmpty) {
      _showError(tr('សូមជ្រើសរើសរូបភាពទំនិញជាមុនសិន', 'Please upload or select a product photo first'));
      return;
    }

    setState(() => _isLoading = true);
    final created = await ApiService().createProduct(
      title: title,
      priceUsd: price,
      category: _selectedCategory,
      description: desc,
      condition: _selectedCondition,
      imageUrl: finalImageUrl,
      location: location.isEmpty ? 'ភ្នំពេញ (Phnom Penh)' : location,
      sellerBakongId: bakongId,
      sellerStoreName: storeName.isNotEmpty ? storeName : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (created != null) {
        widget.onProductCreated();
        Navigator.pop(context);
      } else {
        _showError(tr(
          'បរាជ័យក្នុងការដាក់លក់ទំនិញ (សូមពិនិត្យ Bakong ID របស់អ្នក)',
          'Failed to create product listing (please verify your Bakong ID)',
        ));
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(tr('ជូនដំណឹង', 'Notice')),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(tr('យល់ព្រម', 'OK')),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priceVal = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    final khrEquivalent = (priceVal * 4100).round();

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.bag_badge_plus, color: Color(0xFF007AFF), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    tr('ដាក់លក់ទំនិញពិតប្រាកដ', 'Sell Real Product'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryText,
                    ),
                  ),
                ],
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: const Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.systemGrey3),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: ListView(
              children: [
                // Media Import Section from Phone/PC
                Text(
                  tr('រូបភាព ឬ វីដេអូទំនិញ (Media from Device)', 'Product Photo or Video from Device'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                ),
                const SizedBox(height: 8),

                if (_importedMediaUrl != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: MediaImageView(
                          url: _importedMediaUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _importedMediaUrl = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xCC000000),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    color: AppTheme.surfaceBg,
                    borderRadius: BorderRadius.circular(14),
                    onPressed: _isImporting ? null : _pickMediaFromDevice,
                    child: _isImporting
                        ? const CupertinoActivityIndicator()
                        : Column(
                            children: [
                              const Icon(CupertinoIcons.camera_fill, size: 36, color: Color(0xFF007AFF)),
                              const SizedBox(height: 8),
                              Text(
                                tr(
                                  'ជ្រើសរើសរូបថត ឬ វីដេអូ ចេញពីទូរស័ព្ទ / ឧបករណ៍',
                                  'Import Photo or Video from Phone / Device',
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF007AFF),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr('ជ្រើសរើសពី Gallery, Files ឬ Camera', 'Choose from Gallery, Files, or Camera'),
                                style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                              ),
                            ],
                          ),
                  ),

                const SizedBox(height: 10),

                // Alternative: Image URL
                CupertinoTextField(
                  controller: _imageUrlCtrl,
                  placeholder: tr('ឬ បញ្ចូលតំណភ្ជាប់រូបភាព (Or Paste Image URL)', 'Or paste image URL...'),
                  style: TextStyle(color: AppTheme.primaryText),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 0.6),
                  ),
                ),
                const SizedBox(height: 16),

                // Product Title
                Text(
                  tr('ឈ្មោះទំនិញ (Product Title):', 'Product Title:'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                ),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: _titleCtrl,
                  placeholder: tr('ឧទាហរណ៍: iPhone 15 Pro Max 256GB...', 'e.g. iPhone 15 Pro Max 256GB...'),
                  style: TextStyle(color: AppTheme.primaryText),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 0.6),
                  ),
                ),
                const SizedBox(height: 14),

                // Price Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('តម្លៃជាដុល្លារ \$ (Price USD):', 'Price (USD):'),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                          ),
                          const SizedBox(height: 6),
                          CupertinoTextField(
                            controller: _priceCtrl,
                            placeholder: '0.00',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: AppTheme.primaryText, fontWeight: FontWeight.bold),
                            padding: const EdgeInsets.all(12),
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Text('\$', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.fieldBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border, width: 0.6),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('តម្លៃរៀល (KHR):', 'In Riel:'),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.secondaryText),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 44,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${khrEquivalent.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} ៛',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Category Selector
                Text(
                  tr('ប្រភេទផលិតផល (Category):', 'Product Category:'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final isSel = _selectedCategory == cat['id'];
                    return LiquidGlassPill(
                      label: tr(cat['labelKm']!, cat['labelEn']!),
                      isSelected: isSel,
                      onTap: () => setState(() => _selectedCategory = cat['id']!),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Condition Selector
                Text(
                  tr('ស្ថានភាពទំនិញ (Condition):', 'Condition:'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _conditions.map((cond) {
                    final isSel = _selectedCondition == cond;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCondition = cond),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF34C759) : AppTheme.surfaceBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            cond.split(' ')[0],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? CupertinoColors.white : AppTheme.primaryText,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Location
                Text(
                  tr('ទីតាំងទំនិញ (Location):', 'Location:'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                ),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: _locationCtrl,
                  placeholder: tr('ភ្នំពេញ, សៀមរាប, បាត់ដំបង...', 'Phnom Penh, Siem Reap...'),
                  style: TextStyle(color: AppTheme.primaryText),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 0.6),
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                Text(
                  tr('ការពិពណ៌នាទំនិញលម្អិត (Description):', 'Detailed Description:'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                ),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: _descCtrl,
                  placeholder: tr(
                    'សរសេររៀបរាប់ពីគុណភាព គ្រឿងបន្លាស់ ធានា ឬមូលហេតុលក់...',
                    'Describe product details, condition, warranty...',
                  ),
                  maxLines: 4,
                  style: TextStyle(color: AppTheme.primaryText),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 0.6),
                  ),
                ),
                const SizedBox(height: 16),

                // Merchant Store & Individual Bakong Account Section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1251B).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE1251B).withOpacity(0.25), width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.qrcode_viewfinder, color: Color(0xFFE1251B), size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tr(
                                'គណនី Bakong KHQR ទទួលប្រាក់របស់អ្នក (Merchant Bakong)',
                                'Your Bakong KHQR Payout Account',
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE1251B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr('ឈ្មោះហាងរបស់អ្នក (Store Name):', 'Store Name:'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryText),
                      ),
                      const SizedBox(height: 4),
                      CupertinoTextField(
                        controller: _storeNameCtrl,
                        placeholder: tr('ឧ. Sok Cheat Shop', 'e.g. Sok Cheat Shop'),
                        style: TextStyle(color: AppTheme.primaryText),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppTheme.fieldBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border, width: 0.6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr('Bakong Account ID ផ្ទាល់ខ្លួន *:', 'Bakong Account ID *:'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryText),
                      ),
                      const SizedBox(height: 4),
                      CupertinoTextField(
                        controller: _bakongIdCtrl,
                        placeholder: 'username@bkrt',
                        style: TextStyle(color: AppTheme.primaryText, fontWeight: FontWeight.w600),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppTheme.fieldBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border, width: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          'អតិថិជនស្កេន KHQR នឹងផ្ទេរប្រាក់ចូលគណនីបាគងរបស់អ្នកផ្ទាល់។',
                          'Customers scanning KHQR will pay directly into your Bakong account.',
                        ),
                        style: TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Submit Button
          CupertinoButton(
            color: const Color(0xFF007AFF),
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(vertical: 14),
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.checkmark_seal_fill, color: CupertinoColors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        tr('បង្ហោះដាក់លក់ទំនិញភ្លាមៗ', 'Publish Product Listing'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTrackingSheet extends StatefulWidget {
  const _OrdersTrackingSheet();

  @override
  State<_OrdersTrackingSheet> createState() => _OrdersTrackingSheetState();
}

class _OrdersTrackingSheetState extends State<_OrdersTrackingSheet> {
  int _tab = 0; // 0 = Purchases, 1 = Sales
  bool _isLoading = true;
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _sales = [];
  StreamSubscription<Map<String, dynamic>>? _rtSub;

  static const List<Map<String, String>> _steps = [
    {'id': 'PROCESSING', 'km': 'កំពុងរៀបចំ', 'en': 'Preparing'},
    {'id': 'CONFIRMED', 'km': 'បានបញ្ជាក់', 'en': 'Confirmed'},
    {'id': 'SHIPPING', 'km': 'កំពុងដឹកជញ្ជូន', 'en': 'Shipping'},
    {'id': 'DELIVERED', 'km': 'បានដល់ដៃ', 'en': 'Delivered'},
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _rtSub = RealtimeService().events.listen((evt) {
      if (mounted && evt['type'] == 'ORDER_UPDATE') {
        _loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final res = await ApiService().fetchUserOrders();
    if (!mounted) return;
    setState(() {
      _purchases = res['purchases'] ?? [];
      _sales = res['sales'] ?? [];
      _isLoading = false;
    });
  }

  int _stepIndex(String status) {
    final idx = _steps.indexWhere((s) => s['id'] == status);
    return idx >= 0 ? idx : 0;
  }

  Future<void> _updateOrderStatus(Map<String, dynamic> order, String nextStatus) async {
    final noteCtrl = TextEditingController(text: order['trackingNote']?.toString() ?? '');
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(tr('ធ្វើបច្ចុប្បន្នភាពស្ថានភាពដឹកជញ្ជូន', 'Update Delivery Status')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              tr('បន្ថែមកំណត់ចំណាំ ឬលេខបុងដឹកជញ្ជូន (ស្រេចចិត្ត)', 'Optional courier or tracking note'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: noteCtrl,
              placeholder: 'ឧ. J&T #KH88291 / កំពុងចេញដំណើរ',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(tr('បោះបង់', 'Cancel')),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(tr('រក្សាទុក', 'Update')),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiService().updateOrderFulfillment(
      orderId: order['id']?.toString() ?? '',
      fulfillmentStatus: nextStatus,
      trackingNote: noteCtrl.text.trim(),
    );
    await _loadOrders();
  }

  Future<void> _chatCounterparty(String targetUserId, String productTitle) async {
    if (targetUserId.isEmpty) return;
    final rootNav = Navigator.of(context, rootNavigator: true);
    final chat = await ApiService().getOrCreateDirectChat(targetUserId);
    if (!mounted || chat == null) return;
    Navigator.pop(context);
    rootNav.push(
      CupertinoPageRoute(
        builder: (_) => ChatConversationScreen(
          chat: chat,
          initialDraft: tr(
            'សួស្តី! ទាក់ទងនឹងការបញ្ជាទិញ "$productTitle"...',
            'Hi! Regarding order "$productTitle"...',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = _tab == 0 ? _purchases : _sales;
    return LiquidGlassSheet(
      initialHeightFraction: 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr('ការបញ្ជាទិញ & ដឹកជញ្ជូន', 'Orders & Delivery Tracking'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryText),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _loadOrders,
                  child: const Icon(CupertinoIcons.arrow_clockwise, size: 20),
                ),
              ],
            ),
          ),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: _tab,
            children: {
              0: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text('${tr("ការទិញ", "Purchases")} (${_purchases.length})'),
              ),
              1: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text('${tr("ការលក់", "Sales")} (${_sales.length})'),
              ),
            },
            onValueChanged: (val) {
              if (val != null) setState(() => _tab = val);
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : orders.isEmpty
                    ? Center(
                        child: Text(
                          tr('មិនទាន់មានការបញ្ជាទិញនៅឡើយទេ', 'No orders yet'),
                          style: TextStyle(color: AppTheme.secondaryText),
                        ),
                      )
                    : ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, idx) => _buildOrderCard(orders[idx]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final title = order['productTitle']?.toString() ?? '';
    final billNumber = order['billNumber']?.toString() ?? '';
    final qty = (order['quantity'] is num) ? (order['quantity'] as num).toInt() : 1;
    final amount = order['amount']?.toString() ?? '0';
    final currency = order['currency']?.toString() ?? 'USD';
    final buyerPhone = order['buyerPhone']?.toString() ?? '';
    final shippingAddr = order['shippingAddress']?.toString() ?? '';
    final buyerNote = order['buyerNote']?.toString() ?? '';
    final payStatus = order['status']?.toString() ?? 'PENDING';
    final fulStatus = order['fulfillmentStatus']?.toString() ?? 'PROCESSING';
    final note = order['trackingNote']?.toString() ?? '';
    final activeStep = _stepIndex(fulStatus);
    final isSale = _tab == 1;
    final counterpartyId = isSale
        ? (order['buyerId']?.toString() ?? '')
        : (order['sellerId']?.toString() ?? '');
    final counterpartyName = isSale
        ? (order['buyerName']?.toString() ?? 'Buyer')
        : (order['sellerStoreName']?.toString() ?? order['sellerName']?.toString() ?? 'Seller');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  qty > 1 ? '$title (x$qty)' : title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryText),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (payStatus == 'PAID' ? const Color(0xFF34C759) : const Color(0xFFFF9500))
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  payStatus == 'PAID' ? 'PAID KHQR' : payStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: payStatus == 'PAID' ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '\$$amount $currency • $billNumber • ${isSale ? tr("អ្នកទិញ", "Buyer") : tr("អ្នកលក់", "Seller")}: $counterpartyName',
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
          if (buyerPhone.isNotEmpty || shippingAddr.isNotEmpty || buyerNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.fieldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (buyerPhone.isNotEmpty)
                    Text('📞 $buyerPhone', style: TextStyle(fontSize: 12, color: AppTheme.primaryText, fontWeight: FontWeight.w600)),
                  if (shippingAddr.isNotEmpty)
                    Text('📍 $shippingAddr', style: TextStyle(fontSize: 12, color: AppTheme.primaryText)),
                  if (buyerNote.isNotEmpty)
                    Text('📝 $buyerNote', style: TextStyle(fontSize: 11, color: AppTheme.secondaryText)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // 4-step Delivery Stepper
          Row(
            children: List.generate(_steps.length, (i) {
              final reached = i <= activeStep;
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (i > 0)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: reached ? const Color(0xFF007AFF) : AppTheme.border,
                            ),
                          ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: reached ? const Color(0xFF007AFF) : AppTheme.fieldBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: reached ? const Color(0xFF007AFF) : AppTheme.border,
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.checkmark,
                            size: 11,
                            color: reached ? CupertinoColors.white : AppTheme.tertiaryText,
                          ),
                        ),
                        if (i < _steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: (i + 1 <= activeStep) ? const Color(0xFF007AFF) : AppTheme.border,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(_steps[i]['km']!, _steps[i]['en']!),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
                        color: reached ? AppTheme.primaryText : AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '📦 $note',
                style: TextStyle(fontSize: 12, color: AppTheme.primaryText, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minSize: 0,
                color: AppTheme.fieldBg,
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _chatCounterparty(counterpartyId, title),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.chat_bubble_fill, size: 14, color: Color(0xFF007AFF)),
                    const SizedBox(width: 5),
                    Text(
                      tr('ឆាត', 'Chat'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF007AFF)),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isSale && fulStatus != 'DELIVERED') ...[
                if (fulStatus == 'PROCESSING')
                  _statusActionBtn('បញ្ជាក់', 'CONFIRMED', order),
                if (fulStatus == 'CONFIRMED' || fulStatus == 'PROCESSING') ...[
                  const SizedBox(width: 6),
                  _statusActionBtn('ដឹកជញ្ជូន', 'SHIPPING', order),
                ],
                const SizedBox(width: 6),
                _statusActionBtn('ដល់ដៃ', 'DELIVERED', order, isPrimary: true),
              ] else if (!isSale && fulStatus == 'SHIPPING') ...[
                _statusActionBtn(tr('បានទទួលទំនិញ', 'Mark Received'), 'DELIVERED', order, isPrimary: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusActionBtn(
    String label,
    String targetStatus,
    Map<String, dynamic> order, {
    bool isPrimary = false,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      minSize: 0,
      color: isPrimary ? const Color(0xFF34C759) : const Color(0xFF007AFF),
      borderRadius: BorderRadius.circular(10),
      onPressed: () => _updateOrderStatus(order, targetStatus),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CupertinoColors.white),
      ),
    );
  }
}
