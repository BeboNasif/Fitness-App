import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'bmi_screen.dart';
import 'food_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final data = await FirestoreService().getCurrentUser();
    if (mounted) {
      setState(() {
        userData = data;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Loading your data...',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (userData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load user data',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadUserData,
                child: const Text('Retry',
                    style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
      );
    }

    final pages = [
      _DashboardTab(
        user: userData!,
        onRefresh: _loadUserData,
      ),
      BMIScreen(user: userData!),
      FoodScreen(user: userData!),
      ProfileScreen(user: userData!),
    ];

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => setState(() => currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.monitor_weight_outlined),
              activeIcon: Icon(Icons.monitor_weight_rounded),
              label: 'BMI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_outlined),
              activeIcon: Icon(Icons.restaurant_rounded),
              label: 'Food',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Tab ────────────────────────────────────────────────────────────
class _DashboardTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onRefresh;

  const _DashboardTab({required this.user, required this.onRefresh});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final FirestoreService _fs = FirestoreService();
  int waterCurrent = 0;
  int waterGoal = 8;
  double caloriesConsumed = 0;
  bool loadingWater = true;
  final TextEditingController _caloriesConsumedCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWater();
  }

  Future<void> _loadWater() async {
    final data = await _fs.getWaterData();
    if (mounted) {
      setState(() {
        waterCurrent = data['today'];
        waterGoal = data['goal'];
        loadingWater = false;
      });
    }
  }

  Future<void> _updateWater(int newVal) async {
    final clamped = newVal.clamp(0, waterGoal + 4);
    setState(() => waterCurrent = clamped);
    await _fs.updateWater(clamped);
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  String get _bmiLabel {
    final bmi = (widget.user['bmi'] ?? 0.0).toDouble();
    if (bmi == 0) return 'Not set';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal ✅';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final firstName = user['first_name'] ?? 'User';
    final bmi = (user['bmi'] ?? 0.0).toDouble();
    final calories = (user['calories'] ?? 0.0).toDouble();
    final weight = (user['weight'] ?? 0.0).toDouble();
    final height = (user['height'] ?? 0.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: null,
        toolbarHeight: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          widget.onRefresh();
          await _loadWater();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top header
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            firstName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      // Avatar circle
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradientPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (firstName.isNotEmpty)
                                ? firstName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: AppColors.bg,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Hero card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4AA), Color(0xFF00A882)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Goal',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          calories > 0
                              ? '${calories.toInt()} kcal'
                              : 'Not calculated',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user['target'] ?? 'Set your target',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick stats grid
              SectionHeader(
                title: 'Stats Overview',
                subtitle: 'Your body metrics',
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  StatTile(
                    label: 'Body Mass Index',
                    value: bmi > 0 ? bmi.toStringAsFixed(1) : '--',
                    unit: _bmiLabel,
                    icon: Icons.monitor_weight_outlined,
                    iconColor: bmi > 0 && bmi < 25
                        ? AppColors.primary
                        : AppColors.warning,
                  ),
                  StatTile(
                    label: 'Body Weight',
                    value: weight > 0 ? weight.toStringAsFixed(1) : '--',
                    unit: 'kg',
                    icon: Icons.scale_outlined,
                    iconColor: AppColors.secondary,
                  ),
                  StatTile(
                    label: 'Height',
                    value: height > 0 ? height.toStringAsFixed(0) : '--',
                    unit: 'cm',
                    icon: Icons.height_rounded,
                    iconColor: AppColors.info,
                  ),
                  StatTile(
                    label: 'Activity Level',
                    value: user['activity'] ?? '--',
                    unit: '',
                    icon: Icons.directions_run_rounded,
                    iconColor: AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Calorie tracker
              if (calories > 0) ...[
                SectionHeader(title: 'Calorie Tracker'),
                const SizedBox(height: 12),
                CalorieRing(consumed: caloriesConsumed, goal: calories),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _caloriesConsumedCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Add consumed calories...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          final val =
                              double.tryParse(_caloriesConsumedCtrl.text) ?? 0;
                              setState(() {
                                caloriesConsumed = (caloriesConsumed + val).clamp(0.0, calories * 2) as double;
                              });
                          _fs.updateCaloriesConsumed(caloriesConsumed);
                          _caloriesConsumedCtrl.clear();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientWarm,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '+ Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Water tracker
              SectionHeader(title: 'Hydration'),
              const SizedBox(height: 12),
              loadingWater
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : WaterTrackerWidget(
                      current: waterCurrent,
                      goal: waterGoal,
                      onAdd: () => _updateWater(waterCurrent + 1),
                      onRemove: () => _updateWater(waterCurrent - 1),
                    ),
              const SizedBox(height: 20),

              // Quick workout log
              _QuickWorkoutLog(fs: _fs),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Workout Log ───────────────────────────────────────────────────────
class _QuickWorkoutLog extends StatefulWidget {
  final FirestoreService fs;
  const _QuickWorkoutLog({required this.fs});

  @override
  State<_QuickWorkoutLog> createState() => _QuickWorkoutLogState();
}

class _QuickWorkoutLogState extends State<_QuickWorkoutLog> {
  List<Map<String, dynamic>> logs = [];
  bool loading = true;

  final workoutTypes = [
    {'name': 'Running', 'icon': Icons.directions_run_rounded, 'color': AppColors.primary},
    {'name': 'Weights', 'icon': Icons.fitness_center_rounded, 'color': AppColors.secondary},
    {'name': 'Cycling', 'icon': Icons.pedal_bike_rounded, 'color': AppColors.info},
    {'name': 'Yoga', 'icon': Icons.self_improvement_rounded, 'color': AppColors.warning},
    {'name': 'Swimming', 'icon': Icons.pool_rounded, 'color': AppColors.info},
    {'name': 'Walk', 'icon': Icons.directions_walk_rounded, 'color': AppColors.primary},
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final data = await widget.fs.getWorkoutLogs();
    if (mounted) setState(() { logs = data; loading = false; });
  }

  void _showAddWorkout() {
    String selectedType = 'Running';
    final durationCtrl = TextEditingController(text: '30');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Log Workout',
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
              const Text('Workout Type',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: workoutTypes.map((w) {
                  final sel = selectedType == w['name'];
                  return GestureDetector(
                    onTap: () =>
                        setModalState(() => selectedType = w['name'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? (w['color'] as Color).withOpacity(0.2)
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel
                              ? (w['color'] as Color)
                              : AppColors.cardLight,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(w['icon'] as IconData,
                              color: sel
                                  ? (w['color'] as Color)
                                  : AppColors.textSecondary,
                              size: 16),
                          const SizedBox(width: 6),
                          Text(
                            w['name'] as String,
                            style: TextStyle(
                              color: sel
                                  ? (w['color'] as Color)
                                  : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text('Duration (minutes)',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardLight),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Save Workout',
                icon: Icons.check_rounded,
                onPressed: () async {
                  final dur = int.tryParse(durationCtrl.text) ?? 30;
                  await widget.fs.addWorkoutLog(
                    name: selectedType,
                    durationMinutes: dur,
                    type: selectedType,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadLogs();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Recent Workouts',
          trailing: GestureDetector(
            onTap: _showAddWorkout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded,
                      color: AppColors.primary, size: 16),
                  SizedBox(width: 4),
                  Text('Log',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const CircularProgressIndicator(color: AppColors.primary)
        else if (logs.isEmpty)
          GlassCard(
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.fitness_center_outlined,
                      color: AppColors.textMuted, size: 36),
                  const SizedBox(height: 8),
                  const Text('No workouts logged yet',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _showAddWorkout,
                    child: const Text('Log your first workout',
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          )
        else
          ...logs.take(5).map((log) {
            final type = log['type'] ?? 'Workout';
            final wt = workoutTypes.firstWhere(
              (w) => w['name'] == type,
              orElse: () => workoutTypes[0],
            );
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            (wt['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(wt['icon'] as IconData,
                          color: wt['color'] as Color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log['name'] ?? 'Workout',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            log['date'] ?? '',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PillBadge(
                      label: '${log['duration']} min',
                      color: wt['color'] as Color,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
