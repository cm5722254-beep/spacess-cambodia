import 'package:flutter/cupertino.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import 'marketplace_screen.dart';

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  List<SpaceModel> spaces = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpaces();
  }

  void _loadSpaces() async {
    setState(() => isLoading = true);
    final fetched = await ApiService().fetchSpaces();
    if (mounted) {
      setState(() {
        spaces = fetched;
        isLoading = false;
      });
    }
  }

  Color _getBadgeColor(String mode) {
    switch (mode) {
      case 'FAMILY':
        return const Color(0xFF34C759);
      case 'TEAM':
        return const Color(0xFFAF52DE);
      default:
        return const Color(0xFF007AFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Spaces ទាំងអស់ (Workspaces)'),
      ),
      child: isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: spaces.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF007AFF).withOpacity(0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(18),
                      onPressed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(builder: (_) => const MarketplaceScreen()),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              CupertinoIcons.bag_fill,
                              color: CupertinoColors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Spaces Marketplace',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: CupertinoColors.white,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'E-COMMERCE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF34C759),
                                        backgroundColor: Color(0x33000000),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'ទិញ-លក់ទំនិញអេឡិចត្រូនិក សម្លៀកបំពាក់ យានយន្តក្នុងបណ្ដាញសង្គម',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            color: CupertinoColors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final space = spaces[index - 1];
                final color = _getBadgeColor(space.mode);

                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.systemGrey4.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                        child: Stack(
                          children: [
                            Image.network(
                              space.bannerUrl,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              height: 140,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    CupertinoColors.black.withOpacity(0.6),
                                    CupertinoColors.transparent,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  space.mode,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 14,
                              child: Text(
                                space.khmerName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Details
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              space.description,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: CupertinoColors.label,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Member & post count
                            Row(
                              children: [
                                const Icon(CupertinoIcons.person_2_fill, size: 16, color: CupertinoColors.secondaryLabel),
                                const SizedBox(width: 6),
                                Text(
                                  '${space.memberCount} សមាជិក',
                                  style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
                                ),
                                const SizedBox(width: 14),
                                const Icon(CupertinoIcons.doc_plaintext, size: 16, color: CupertinoColors.secondaryLabel),
                                const SizedBox(width: 6),
                                Text(
                                  '${space.postCount} ការបង្ហោះ',
                                  style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Features
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: space.features.map((feat) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.checkmark_alt, size: 12, color: color),
                                      const SizedBox(width: 4),
                                      Text(
                                        feat,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

