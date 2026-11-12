import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  AdminStats? _stats;
  List<UserModel> _users = [];
  List<Map<String, dynamic>> _reports = [];
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final statsFuture = _api.fetchAdminStats();
    final usersFuture = _api.fetchAdminUsers();
    final reportsFuture = _api.fetchAdminReports();

    final results = await Future.wait([statsFuture, usersFuture, reportsFuture]);
    if (!mounted) return;

    setState(() {
      _stats = results[0] as AdminStats?;
      _users = results[1] as List<UserModel>;
      _reports = List<Map<String, dynamic>>.from(results[2] as List);
      _isLoading = false;
    });
  }

  Future<void> _resolveReport(String reportId, String action) async {
    final ok = await _api.resolveAdminReport(reportId, action);
    if (ok) {
      await _loadDashboardData();
    }
  }

  Future<void> _toggleBan(UserModel user) async {
    if (user.role == 'ADMIN') {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('សកម្មភាពត្រូវបានហាមឃាត់'),
          content: const Text('មិនអាចផ្អាកគណនី Admin បានឡើយ។'),
          actions: [
            CupertinoDialogAction(
              child: const Text('យល់ព្រម'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
      return;
    }

    final actionText = user.isBanned ? 'បើកដំណើរការឡើងវិញ' : 'ផ្អាកដំណើរការ (Ban)';
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('បញ្ជាក់ការ$actionText'),
        content: Text('តើអ្នកពិតជាចង់$actionTextគណនី ${user.name} (@${user.username}) មែនទេ?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('បោះបង់'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: !user.isBanned,
            child: Text(actionText),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _api.toggleBanUser(user.id);
      if (success) {
        await _loadDashboardData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredUsers = _users.where((u) {
      if (_searchFilter.isEmpty) return true;
      final query = _searchFilter.toLowerCase();
      return u.name.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.phone.contains(query);
    }).toList();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('ផ្ទាំងគ្រប់គ្រង Admin (Dashboard)'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loadDashboardData,
          child: const Icon(CupertinoIcons.arrow_clockwise, size: 20),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
                slivers: [
                  // Analytics Cards Grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ទិន្នន័យប្រព័ន្ធទូទៅ (System Overview)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? CupertinoColors.white : CupertinoColors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_stats != null) _buildStatsGrid(_stats!, isDark),
                          if (_reports.any((r) => r['status'] == 'OPEN')) ...[
                            const SizedBox(height: 22),
                            Text(
                              'របាយការណ៍បំពានរង់ចាំពិនិត្យ (${_reports.where((r) => r['status'] == 'OPEN').length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: CupertinoColors.destructiveRed,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ..._reports
                                .where((r) => r['status'] == 'OPEN')
                                .map((rep) => _buildReportCard(rep, isDark)),
                          ],
                          const SizedBox(height: 24),
                          Text(
                            'ការគ្រប់គ្រងគណនីអ្នកប្រើប្រាស់ (${_users.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? CupertinoColors.white : CupertinoColors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Search Box
                          CupertinoSearchTextField(
                            placeholder: 'ស្វែងរកតាមឈ្មោះ ឬលេខទូរស័ព្ទ...',
                            onChanged: (val) => setState(() => _searchFilter = val),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Users List
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final user = filteredUsers[index];
                          return _buildUserCard(user, isDark);
                        },
                        childCount: filteredUsers.length,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 40),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsGrid(AdminStats stats, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildStatCard('អ្នកប្រើប្រាស់សរុប', '${stats.totalUsers} នាក់',
                  CupertinoIcons.person_2_fill, const Color(0xFF007AFF), isDark),
              const SizedBox(height: 10),
              _buildStatCard('ការបង្ហោះសរុប', '${stats.totalPosts} Posts',
                  CupertinoIcons.square_grid_2x2_fill, const Color(0xFF34C759), isDark),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              _buildStatCard('Spaces សកម្ម', '${stats.totalSpaces} តំបន់',
                  CupertinoIcons.rectangle_3_offgrid_fill, const Color(0xFF5856D6), isDark),
              const SizedBox(height: 10),
              _buildStatCard('អន្តរកម្ម Reactions', '${stats.totalReactions}',
                  CupertinoIcons.heart_fill, const Color(0xFFFF2D55), isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.systemGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserModel user, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isBanned
              ? CupertinoColors.destructiveRed.withOpacity(0.5)
              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA)),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              user.avatar,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 42,
                height: 42,
                color: CupertinoColors.systemGrey5,
                child: const Icon(CupertinoIcons.person_fill, color: CupertinoColors.systemGrey),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? CupertinoColors.white : CupertinoColors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.role == 'ADMIN') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5856D6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: CupertinoColors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username} • ${user.phone}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                if (user.isBanned) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'ស្ថានភាព: ផ្អាកដំណើរការ (Banned)',
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.destructiveRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Ban/Unban Button
          if (user.role != 'ADMIN')
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minSize: 0,
              color: user.isBanned ? const Color(0xFF34C759) : CupertinoColors.destructiveRed,
              borderRadius: BorderRadius.circular(8),
              onPressed: () => _toggleBan(user),
              child: Text(
                user.isBanned ? 'Unban' : 'Ban',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> rep, bool isDark) {
    final reportId = rep['id']?.toString() ?? '';
    final targetType = rep['targetType']?.toString() ?? 'POST';
    final reason = rep['reason']?.toString() ?? '';
    final preview = rep['targetPreview']?.toString() ?? '';
    final reporter = rep['reporterName']?.toString() ?? 'User';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CupertinoColors.destructiveRed.withOpacity(0.45), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                  size: 16, color: CupertinoColors.destructiveRed),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$targetType • ដោយ $reporter',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('មូលហេតុ: $reason',
              style: const TextStyle(fontSize: 12, color: CupertinoColors.systemOrange, fontWeight: FontWeight.w600)),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                minSize: 0,
                color: CupertinoColors.systemGrey.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
                onPressed: () => _resolveReport(reportId, 'DISMISS'),
                child: Text(
                  'មិនអើពើ',
                  style: TextStyle(fontSize: 11, color: isDark ? CupertinoColors.white : CupertinoColors.black),
                ),
              ),
              if (targetType == 'POST') ...[
                const SizedBox(width: 6),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  minSize: 0,
                  color: const Color(0xFFFF9500),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: () => _resolveReport(reportId, 'DELETE_POST'),
                  child: const Text('លុប Post', style: TextStyle(fontSize: 11, color: CupertinoColors.white)),
                ),
              ],
              const SizedBox(width: 6),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                minSize: 0,
                color: CupertinoColors.destructiveRed,
                borderRadius: BorderRadius.circular(8),
                onPressed: () => _resolveReport(reportId, 'BAN_USER'),
                child: const Text('Ban គណនី', style: TextStyle(fontSize: 11, color: CupertinoColors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
