import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? currentUser;
  List<Map<String, dynamic>> favoriteFoods = [];
  final FirestoreService _fs = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      if (_auth.currentUser == null) return;
      final userData = await _fs.getCurrentUser();
      final ingredients = await _fs.getUserIngredients();
      if (!mounted) return;
      setState(() {
        currentUser = userData;
        favoriteFoods = ingredients;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')));
    }
  }

  String get _initials {
    final first = currentUser?['first_name'] ?? '';
    final last = currentUser?['last_name'] ?? '';
    return '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'
        .toUpperCase();
  }

  String get _bmiStatus {
    final bmi = (currentUser?['bmi'] as num?)?.toDouble() ?? 0;
    if (bmi == 0) return 'Not set';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal ✅';
    if (bmi < 30) return 'Overweight ⚠️';
    return 'Obese ❗';
  }

  Color get _bmiColor {
    final bmi = (currentUser?['bmi'] as num?)?.toDouble() ?? 0;
    if (bmi == 0) return AppColors.textMuted;
    if (bmi < 18.5) return AppColors.info;
    if (bmi < 25) return AppColors.primary;
    if (bmi < 30) return AppColors.warning;
    return AppColors.danger;
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This action is permanent and cannot be undone. All your data will be erased.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      await _fs.deleteUser();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to delete. Please re-login first.'),
      ));
    }
  }

  void _changePassword() {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Change Password',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _pwField(ctx, 'Current Password', currentPwCtrl,
                  obscureCurrent, () {
                setModalState(() => obscureCurrent = !obscureCurrent);
              }),
              const SizedBox(height: 14),
              _pwField(
                  ctx, 'New Password', newPwCtrl, obscureNew, () {
                setModalState(() => obscureNew = !obscureNew);
              }),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Update Password',
                icon: Icons.lock_reset_rounded,
                onPressed: () async {
                  final user = _auth.currentUser;
                  if (user == null || user.email == null) return;
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPwCtrl.text.trim(),
                  );
                  try {
                    await user.reauthenticateWithCredential(cred);
                    await user.updatePassword(newPwCtrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Password updated ✅')),
                    );
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pwField(BuildContext ctx, String label,
      TextEditingController ctrl, bool obscure, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardLight),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: obscure,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              suffixIcon: GestureDetector(
                onTap: toggle,
                child: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final bmi = (currentUser!['bmi'] as num?)?.toDouble() ?? 0.0;
    final calories = (currentUser!['calories'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Hero profile card
            GlassCard(
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradientPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${currentUser!['first_name'] ?? ''} ${currentUser!['last_name'] ?? ''}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser!['email'] ?? '',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  // Quick tags
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PillBadge(
                          label: currentUser!['gender'] ?? 'Gender',
                          color: AppColors.secondary),
                      const SizedBox(width: 8),
                      PillBadge(
                          label: '${currentUser!['age'] ?? '--'} yrs',
                          color: AppColors.info),
                      const SizedBox(width: 8),
                      PillBadge(
                          label: currentUser!['activity'] ?? 'Activity',
                          color: AppColors.warning),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Body metrics
            _buildSectionCard('Body Metrics', Icons.accessibility_new_rounded, [
              _metricTile('Height', '${currentUser!['height'] ?? '--'} cm',
                  Icons.height_rounded, AppColors.info),
              _metricTile('Weight', '${currentUser!['weight'] ?? '--'} kg',
                  Icons.scale_outlined, AppColors.secondary),
              _metricTile(
                  'BMI',
                  bmi > 0 ? bmi.toStringAsFixed(1) : '--',
                  Icons.monitor_weight_outlined,
                  _bmiColor,
                  subtitle: _bmiStatus),
              _metricTile(
                  'Calories',
                  calories > 0
                      ? '${calories.toInt()} kcal'
                      : '--',
                  Icons.local_fire_department_outlined,
                  AppColors.warning),
            ]),
            const SizedBox(height: 16),

            // Fitness goal
            _buildSectionCard('Fitness Goal', Icons.flag_rounded, [
              _metricTile('Target', currentUser!['target'] ?? '--',
                  Icons.track_changes_rounded, AppColors.primary),
            ]),
            const SizedBox(height: 16),

            // Favorite foods
            if (favoriteFoods.isNotEmpty)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.restaurant_outlined,
                              color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text('Favorite Ingredients',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        const Spacer(),
                        Text('${favoriteFoods.length} items',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: favoriteFoods.map((f) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.cardLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            f['name'] ?? 'Unknown',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Actions
            GlassCard(
              child: Column(
                children: [
                  _actionTile(
                    'Change Password',
                    Icons.lock_outline_rounded,
                    AppColors.secondary,
                    _changePassword,
                  ),
                  const Divider(color: AppColors.cardLight, height: 20),
                  _actionTile(
                    'Delete Account',
                    Icons.delete_outline_rounded,
                    AppColors.danger,
                    _confirmDeleteAccount,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      String title, IconData icon, List<Widget> items) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _metricTile(
      String label, String value, IconData icon, Color color,
      {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              if (subtitle != null)
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 15)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              color: color.withOpacity(0.5), size: 20),
        ],
      ),
    );
  }
}
