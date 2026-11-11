import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';

class BakongPaymentSheet extends StatefulWidget {
  final ProductModel product;

  const BakongPaymentSheet({super.key, required this.product});

  @override
  State<BakongPaymentSheet> createState() => _BakongPaymentSheetState();
}

class _BakongPaymentSheetState extends State<BakongPaymentSheet> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? checkoutData;
  Timer? _pollTimer;
  bool isPaid = false;
  Map<String, dynamic>? transactionData;

  @override
  void initState() {
    super.initState();
    _startCheckout();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startCheckout() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final res = await ApiService().checkoutProduct(
      productId: widget.product.id,
      currency: 'USD',
    );

    if (mounted) {
      if (res != null && (res['success'] == true || res['md5'] != null)) {
        final data = res['data'] is Map ? Map<String, dynamic>.from(res['data']) : res;
        setState(() {
          checkoutData = data;
          isLoading = false;
        });
        final md5 = data['md5'] ?? res['md5'];
        if (md5 != null) {
          _startPolling(md5.toString());
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = res?['message'] ?? 'មិនអាចបង្កើតកូដ Bakong KHQR បានទេ';
        });
      }
    }
  }

  void _startPolling(String md5) {
    _pollTimer?.cancel();
    // Poll NBC ledger every 2.5 seconds
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
      final statusRes = await ApiService().checkOrderStatus(md5);
      if (statusRes != null && statusRes['paid'] == true) {
        timer.cancel();
        if (mounted) {
          setState(() {
            isPaid = true;
            transactionData = statusRes['transaction'];
          });
        }
      }
    });
  }

  Widget _buildQrImage(String rawImage, [String? fallbackQrString]) {
    String effectiveQr = rawImage.trim();
    if (effectiveQr.isEmpty && fallbackQrString != null) {
      effectiveQr = fallbackQrString.trim();
    }
    if (effectiveQr.isEmpty) {
      return Container(
        width: 220,
        height: 220,
        color: CupertinoColors.white,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(radius: 14),
              SizedBox(height: 10),
              Text(
                'កំពុងទាញយក Bakong KHQR...',
                style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
              ),
            ],
          ),
        ),
      );
    }
    try {
      if (effectiveQr.startsWith('data:image')) {
        final comma = effectiveQr.indexOf(',');
        final base64Str = comma != -1 ? effectiveQr.substring(comma + 1).trim() : effectiveQr.trim();
        final cleaned = base64Str.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
        final bytes = base64Decode(cleaned);
        return Image.memory(
          bytes,
          width: 220,
          height: 220,
          fit: BoxFit.contain,
        );
      } else if (effectiveQr.startsWith('http')) {
        return Image.network(
          effectiveQr,
          width: 220,
          height: 220,
          fit: BoxFit.contain,
        );
      } else {
        // EMVCo raw KHQR string fallback -> render via dynamic QR service
        final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&margin=8&data=${Uri.encodeComponent(effectiveQr)}';
        return Image.network(
          qrUrl,
          width: 220,
          height: 220,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(CupertinoIcons.qrcode, size: 90, color: Color(0xFFE1251B)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error decoding QR image: $e');
    }
    return Container(
      width: 220,
      height: 220,
      color: CupertinoColors.white,
      child: const Center(
        child: Icon(CupertinoIcons.qrcode, size: 90, color: Color(0xFFE1251B)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppTheme.modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1251B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(CupertinoIcons.qrcode_viewfinder, color: Color(0xFFE1251B), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bakong KHQR Payway',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        Text(
                          tr('ទូទាត់រហ័ស & ស្វ័យប្រវត្តិជាមួយបាគង', 'Fast & instant Bakong payment'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.systemGrey3, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: AppTheme.divider),

          // Content
          Expanded(
            child: isPaid ? _buildSuccessView() : _buildPaymentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final invoice = checkoutData?['billNumber'] ?? 'INV-PAID';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.checkmark_seal_fill,
                color: Color(0xFF34C759),
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'ការទូទាត់បានជោគជ័យ!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF34C759),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ប្រព័ន្ធបានផ្ទៀងផ្ទាត់លើ NBC Ledger និងដោះសោការបញ្ជាទិញរួចរាល់',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CupertinoColors.systemGrey5),
            ),
            child: Column(
              children: [
                _buildReceiptRow('ទំនិញ:', widget.product.title),
                const SizedBox(height: 8),
                _buildReceiptRow('វិក្កយបត្រ:', invoice),
                const SizedBox(height: 8),
                _buildReceiptRow('ចំនួនទឹកប្រាក់:', '\$${widget.product.priceUsd.toStringAsFixed(2)} USD'),
                const SizedBox(height: 8),
                _buildReceiptRow('ស្ថានភាព:', 'PAID (ជោគជ័យ)', isBold: true, valueColor: const Color(0xFF34C759)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              borderRadius: BorderRadius.circular(14),
              child: const Text('រួចរាល់ (Done)', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentView() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 18),
            SizedBox(height: 16),
            Text(
              'កំពុងបង្កើតកូដ Bakong KHQR...',
              style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFFF9500), size: 48),
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: CupertinoColors.destructiveRed),
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: _startCheckout,
                child: const Text('ព្យាយាមម្តងទៀត (Retry)'),
              ),
            ],
          ),
        ),
      );
    }

    final merchant = checkoutData?['merchantName'] ??
        ((widget.product.sellerStoreName != null && widget.product.sellerStoreName!.isNotEmpty)
            ? widget.product.sellerStoreName!
            : widget.product.sellerName);
    final bakongId = checkoutData?['sellerBakongId'] ?? widget.product.sellerBakongId ?? '';
    final qrImg = checkoutData?['qrImage'] ?? checkoutData?['data']?['qrImage'] ?? '';
    final qrStr = checkoutData?['qrString'] ?? checkoutData?['qr'] ?? checkoutData?['data']?['qrString'] ?? checkoutData?['data']?['qr'] ?? '';
    final deeplink = checkoutData?['deeplink'] ?? '';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Store & Merchant Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.bag_fill, color: Color(0xFF007AFF), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        'Bakong: $bakongId',
                        style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // QR Code Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1251B).withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Bakong Logo Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1251B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'KHQR',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'BAKONG',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFFE1251B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // QR Image
                _buildQrImage(qrImg, qrStr),

                const SizedBox(height: 12),
                Text(
                  '\$${widget.product.priceUsd.toStringAsFixed(2)} USD',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF007AFF),
                  ),
                ),
                Text(
                  '~ ${widget.product.priceKhr.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} ៛',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Waiting for payment indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(radius: 9),
              const SizedBox(width: 8),
              Text(
                'កំពុងរង់ចាំការផ្ទេរប្រាក់ (Live Polling)...',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF007AFF).withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1-Tap Pay Deeplink Button
          if (deeplink.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: const Color(0xFFE1251B),
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: () {
                  // Launch deeplink or copy URL
                  showCupertinoDialog(
                    context: context,
                    builder: (ctx) => CupertinoAlertDialog(
                      title: const Text('Bakong Deeplink'),
                      content: Text('បើកទូទាត់ក្នុង Bakong App ឬ Mobile Banking:\n\n$deeplink'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('យល់ព្រម (OK)'),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.device_phone_portrait, color: CupertinoColors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'បើកក្នុង Bakong App (1-Tap Pay)',
                      style: TextStyle(fontWeight: FontWeight.w700, color: CupertinoColors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? CupertinoColors.label,
          ),
        ),
      ],
    );
  }
}

