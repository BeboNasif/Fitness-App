import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class BMIScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const BMIScreen({super.key, required this.user});

  @override
  State<BMIScreen> createState() => _BMIScreenState();
}

class _BMIScreenState extends State<BMIScreen>
    with SingleTickerProviderStateMixin {
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();

  double? bmi;
  double? calories;
  String result = '';
  Map<String, dynamic>? currentUser;
  double? idealWeightMin;
  double? idealWeightMax;
  bool saveToFirebase = true;
  bool isCalculating = false;
  List<Map<String, dynamic>> bmiHistory = [];

  final FirestoreService _fs = FirestoreService();

  final List<String> activities = [
    'Low', 'Light', 'Moderate', 'High', 'Very High'
  ];
  String selectedActivity = 'Low';
  final Map<String, double> activityMultiplier = {
    'Low': 1.2,
    'Light': 1.375,
    'Moderate': 1.55,
    'High': 1.725,
    'Very High': 1.9,
  };

  final List<String> targets = [
    'Lose Weight', 'Maintain Weight', 'Gain Weight'
  ];
  String selectedTarget = 'Maintain Weight';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    currentUser = widget.user;
    _loadUserData();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    ageController.text = currentUser?['age']?.toString() ?? '';
    heightController.text = currentUser?['height']?.toString() ?? '';
    weightController.text = currentUser?['weight']?.toString() ?? '';
    bmi = (currentUser?['bmi'] as num?)?.toDouble();
    calories = (currentUser?['calories'] as num?)?.toDouble();
    if (bmi != null && bmi! > 0) _setBMIResult(bmi!);
    selectedActivity = currentUser?['activity'] ?? 'Low';
    selectedTarget = currentUser?['target'] ?? 'Maintain Weight';
    _calculateIdealWeight();
  }

  Future<void> _loadHistory() async {
    final history = await _fs.getBMIHistory();
    if (mounted) setState(() => bmiHistory = history);
  }

  void _setBMIResult(double v) {
    if (v < 18.5) result = 'Underweight';
    else if (v < 25) result = 'Normal weight';
    else if (v < 30) result = 'Overweight';
    else result = 'Obese';
  }

  double calculateCalories(double weight, double height, int age,
      String activity, String target) {
    final bmr = (currentUser!['gender'] == 'Female')
        ? 10 * weight + 6.25 * height - 5 * age - 161
        : 10 * weight + 6.25 * height - 5 * age + 5;
    double tdee = bmr * activityMultiplier[activity]!;
    if (target == 'Lose Weight') tdee -= 500;
    if (target == 'Gain Weight') tdee += 500;
    return tdee;
  }

  void _calculateIdealWeight() {
    final height = double.tryParse(heightController.text);
    if (height == null) return;
    idealWeightMin = 18.5 * (height / 100) * (height / 100);
    idealWeightMax = 24.9 * (height / 100) * (height / 100);
  }

  Future<void> calculateBMI() async {
    final age = int.tryParse(ageController.text);
    final height = double.tryParse(heightController.text);
    final weight = double.tryParse(weightController.text);
    if (age == null || height == null || weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => isCalculating = true);
    final h = height / 100;
    final bmiValue = weight / (h * h);
    final tdee = calculateCalories(weight, height, age, selectedActivity, selectedTarget);

    setState(() {
      bmi = bmiValue;
      calories = tdee;
      _setBMIResult(bmiValue);
      _calculateIdealWeight();
      isCalculating = false;
    });

    if (saveToFirebase) {
      try {
        await _fs.updateUserData(
          age: age, height: height, weight: weight,
          bmi: bmiValue, calories: tdee,
          activity: selectedActivity, target: selectedTarget,
        );
        await _loadHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data saved successfully ✅')),
          );
        }
      } catch (e) {
        debugPrint('Failed to update: $e');
      }
    }
  }

  Color get _bmiColor {
    if (bmi == null) return AppColors.textSecondary;
    if (bmi! < 18.5) return AppColors.info;
    if (bmi! < 25) return AppColors.primary;
    if (bmi! < 30) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BMI Calculator'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Calculator'),
            Tab(text: 'History'),
          ],
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalculatorTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildCalculatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // BMI Result Display
          if (bmi != null && bmi! > 0) ...[
            GlassCard(
              child: Column(
                children: [
                  const Text(
                    'Your BMI',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  BMIGauge(bmi: bmi!),
                  const SizedBox(height: 12),
                  // BMI scale legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _scaleDot('Under', AppColors.info),
                      _scaleDot('Normal', AppColors.primary),
                      _scaleDot('Over', AppColors.warning),
                      _scaleDot('Obese', AppColors.danger),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Input Fields
          GlassCard(
            child: Column(
              children: [
                _buildInputRow(
                  'Age', ageController, 'years', Icons.cake_outlined,
                  TextInputType.number),
                const SizedBox(height: 14),
                _buildInputRow(
                  'Height', heightController, 'cm', Icons.height_rounded,
                  TextInputType.number),
                const SizedBox(height: 14),
                _buildInputRow(
                  'Weight', weightController, 'kg', Icons.monitor_weight_outlined,
                  TextInputType.number),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Activity & Target
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Activity Level',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: activities.map((a) {
                    final sel = selectedActivity == a;
                    return GestureDetector(
                      onTap: () => setState(() => selectedActivity = a),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.primary.withOpacity(0.2)
                              : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          a,
                          style: TextStyle(
                            color: sel
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const Text('Goal',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: targets.map((t) {
                    final sel = selectedTarget == t;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => selectedTarget = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(
                              right: targets.last == t ? 0 : 8),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: sel ? AppColors.gradientPrimary : null,
                            color: sel ? null : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              t.split(' ').first,
                              style: TextStyle(
                                color: sel
                                    ? AppColors.bg
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Save toggle + Calculate
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => saveToFirebase = !saveToFirebase),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: saveToFirebase
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: saveToFirebase
                          ? AppColors.primary.withOpacity(0.3)
                          : AppColors.cardLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        saveToFirebase
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        color: saveToFirebase
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Save',
                        style: TextStyle(
                          color: saveToFirebase
                              ? AppColors.primary
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  label: 'Calculate BMI',
                  onPressed: calculateBMI,
                  isLoading: isCalculating,
                  icon: Icons.calculate_outlined,
                ),
              ),
            ],
          ),

          // Results Card
          if (bmi != null && calories != null) ...[
            const SizedBox(height: 20),
            GlassCard(
              child: Column(
                children: [
                  _resultRow('Daily Calories', '${calories!.toInt()} kcal',
                      AppColors.warning),
                  _resultRow('Activity', selectedActivity, AppColors.info),
                  _resultRow('Goal', selectedTarget, AppColors.secondary),
                  if (idealWeightMin != null && idealWeightMax != null)
                    _resultRow(
                      'Ideal Weight',
                      '${idealWeightMin!.toStringAsFixed(1)} – ${idealWeightMax!.toStringAsFixed(1)} kg',
                      AppColors.primary,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (bmiHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded,
                color: AppColors.textMuted, size: 52),
            const SizedBox(height: 12),
            const Text('No BMI history yet',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Calculate and save your BMI to track progress',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: bmiHistory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final entry = bmiHistory[i];
        final bmiVal = (entry['bmi'] as num?)?.toDouble() ?? 0.0;
        Color c;
        if (bmiVal < 18.5) c = AppColors.info;
        else if (bmiVal < 25) c = AppColors.primary;
        else if (bmiVal < 30) c = AppColors.warning;
        else c = AppColors.danger;

        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    bmiVal.toStringAsFixed(1),
                    style: TextStyle(
                      color: c,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['date'] ?? '',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${entry['weight']} kg',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              PillBadge(
                label: bmiVal < 18.5
                    ? 'Under'
                    : bmiVal < 25
                        ? 'Normal'
                        : bmiVal < 30
                            ? 'Over'
                            : 'Obese',
                color: c,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _scaleDot(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _buildInputRow(String label, TextEditingController ctrl, String unit,
      IconData icon, TextInputType type) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              TextField(
                controller: ctrl,
                keyboardType: type,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: '0',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  suffixText: unit,
                  suffixStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
