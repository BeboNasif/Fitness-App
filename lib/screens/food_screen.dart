import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class FoodScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const FoodScreen({super.key, required this.user});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController searchController = TextEditingController();
  final FirestoreService _fs = FirestoreService();

  final Map<String, List<String>> ingredientsByType = {
    'Protein': ['Chicken', 'Eggs', 'Beef', 'Fish', 'Tofu', 'Lentils', 'Turkey', 'Shrimp'],
    'Carb': ['Rice', 'Oats', 'Bread', 'Pasta', 'Potato', 'Quinoa', 'Sweet Potato', 'Barley'],
    'Vegetable': ['Broccoli', 'Tomato', 'Carrot', 'Spinach', 'Cucumber', 'Pepper', 'Zucchini', 'Kale'],
    'Fruit': ['Apple', 'Banana', 'Orange', 'Strawberry', 'Grapes', 'Mango', 'Blueberry', 'Pineapple'],
    'Dairy': ['Milk', 'Cheese', 'Yogurt', 'Butter', 'Greek Yogurt'],
    'Nuts': ['Almonds', 'Cashews', 'Peanuts', 'Walnuts', 'Chia Seeds'],
  };

  final Map<String, Color> typeColors = {
    'Protein': AppColors.danger,
    'Carb': AppColors.warning,
    'Vegetable': AppColors.primary,
    'Fruit': const Color(0xFFFF6BD6),
    'Dairy': AppColors.info,
    'Nuts': const Color(0xFFB8A058),
  };

  final Map<String, IconData> typeIcons = {
    'Protein': Icons.egg_outlined,
    'Carb': Icons.grain_outlined,
    'Vegetable': Icons.eco_outlined,
    'Fruit': Icons.apple_outlined,
    'Dairy': Icons.water_drop_outlined,
    'Nuts': Icons.agriculture_outlined,
  };

  Set<String> selectedIngredients = {};
  Map<String, String> ingredientTypeMap = {};
  List<Map<String, String>> mealPlan = [];
  bool generatingPlan = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    ingredientsByType.forEach((type, list) {
      for (final ing in list) {
        ingredientTypeMap[ing] = type.toLowerCase();
      }
    });
    _loadSelectedIngredients();
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedIngredients() async {
    try {
      final ingredients = await _fs.getUserIngredients();
      if (!mounted) return;
      setState(() {
        selectedIngredients = ingredients.map((e) => e['name']!).toSet();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load ingredients')),
      );
    }
  }

  Future<void> _saveIngredients() async {
    final dataToSave = selectedIngredients
        .map((ing) => {'name': ing, 'type': ingredientTypeMap[ing]!})
        .toList();

    final countByType = <String, int>{};
    for (final map in dataToSave) {
      final type = map['type']!;
      countByType[type] = (countByType[type] ?? 0) + 1;
    }

    final insufficient = <String>[];
    for (final type in ['protein', 'carb', 'vegetable', 'fruit']) {
      if ((countByType[type] ?? 0) < 2) {
        insufficient.add(type[0].toUpperCase() + type.substring(1));
      }
    }

    if (insufficient.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select at least 2 from: ${insufficient.join(', ')}',
          ),
        ),
      );
      return;
    }

    await _fs.saveUserIngredients(dataToSave);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preferences saved ✅')),
    );
  }

  void _generateMealPlan() {
    setState(() => generatingPlan = true);

    final grouped = <String, List<String>>{};
    for (final ing in selectedIngredients) {
      final type = ingredientTypeMap[ing] ?? 'other';
      grouped.putIfAbsent(type, () => []).add(ing);
    }

    grouped.forEach((k, v) => v.shuffle());

    final proteins = grouped['protein'] ?? [];
    final carbs = grouped['carb'] ?? [];
    final veggies = grouped['vegetable'] ?? [];
    final fruits = grouped['fruit'] ?? [];

    final plan = <Map<String, String>>[];

    // Breakfast
    plan.add({
      'meal': 'Breakfast',
      'dish': _buildMeal([
        if (proteins.isNotEmpty) proteins[0],
        if (carbs.isNotEmpty) carbs[0],
        if (fruits.isNotEmpty) fruits[0],
      ], 'Breakfast Bowl'),
      'icon': '🌅',
      'time': '7:00 AM',
    });

    // Lunch
    plan.add({
      'meal': 'Lunch',
      'dish': _buildMeal([
        if (proteins.length > 1) proteins[1] else if (proteins.isNotEmpty) proteins[0],
        if (carbs.length > 1) carbs[1] else if (carbs.isNotEmpty) carbs[0],
        if (veggies.isNotEmpty) veggies[0],
      ], 'Power Plate'),
      'icon': '☀️',
      'time': '12:30 PM',
    });

    // Snack
    plan.add({
      'meal': 'Snack',
      'dish': _buildMeal([
        if (fruits.length > 1) fruits[1] else if (fruits.isNotEmpty) fruits[0],
        if (grouped['nuts']?.isNotEmpty ?? false) grouped['nuts']![0],
      ], 'Energy Snack'),
      'icon': '🍎',
      'time': '3:30 PM',
    });

    // Dinner
    plan.add({
      'meal': 'Dinner',
      'dish': _buildMeal([
        if (proteins.length > 2) proteins[2] else if (proteins.isNotEmpty) proteins[0],
        if (veggies.length > 1) veggies[1] else if (veggies.isNotEmpty) veggies[0],
        if (carbs.length > 2) carbs[2] else if (carbs.isNotEmpty) carbs[0],
      ], 'Balanced Dinner'),
      'icon': '🌙',
      'time': '7:00 PM',
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          mealPlan = plan;
          generatingPlan = false;
        });
        _tabController.animateTo(1);
      }
    });
  }

  String _buildMeal(List<String> items, String fallback) {
    final filtered = items.where((s) => s.isNotEmpty).toList();
    if (filtered.isEmpty) return fallback;
    if (filtered.length == 1) return filtered[0];
    final last = filtered.removeLast();
    return '${filtered.join(', ')} & $last';
  }

  List<String> _filterList(String type) {
    final q = searchController.text.toLowerCase();
    if (q.isEmpty) return ingredientsByType[type]!;
    return ingredientsByType[type]!
        .where((item) => item.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ingredients'),
            Tab(text: 'Meal Plan'),
          ],
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
          _buildIngredientsTab(),
          _buildMealPlanTab(),
        ],
      ),
    );
  }

  Widget _buildIngredientsTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardLight),
            ),
            child: TextField(
              controller: searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Search ingredients...',
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textMuted, size: 20),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),

        // Selected count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${selectedIngredients.length} selected',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              if (selectedIngredients.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => selectedIngredients.clear()),
                  child: const Text('Clear all',
                      style: TextStyle(
                          color: AppColors.danger, fontSize: 13)),
                ),
            ],
          ),
        ),

        // Categories + items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: ingredientsByType.keys.map((type) {
              final list = _filterList(type);
              if (list.isEmpty) return const SizedBox();
              final color = typeColors[type] ?? AppColors.primary;
              final icon = typeIcons[type] ?? Icons.food_bank_outlined;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${selectedIngredients.where((ing) => ingredientTypeMap[ing]?.toLowerCase() == type.toLowerCase()).length}/${list.length}',
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: list.map((item) {
                      final selected = selectedIngredients.contains(item);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              selectedIngredients.remove(item);
                            } else {
                              selectedIngredients.add(item);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withOpacity(0.2)
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? color : AppColors.cardLight,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected)
                                Icon(Icons.check_rounded,
                                    color: color, size: 14),
                              if (selected) const SizedBox(width: 4),
                              Text(
                                item,
                                style: TextStyle(
                                  color: selected
                                      ? color
                                      : AppColors.textSecondary,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMealPlanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Generate button
          GlassCard(
            child: Column(
              children: [
                const Icon(Icons.restaurant_menu_rounded,
                    color: AppColors.primary, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'AI Meal Planner',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Generate a daily meal plan based on your selected ingredients',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GradientButton(
                        label: generatingPlan
                            ? 'Generating...'
                            : 'Generate Plan',
                        onPressed: selectedIngredients.length >= 4
                            ? _generateMealPlan
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Select at least 4 ingredients first'),
                                  ),
                                );
                              },
                        isLoading: generatingPlan,
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _saveIngredients,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardLight),
                        ),
                        child: const Icon(Icons.save_outlined,
                            color: AppColors.textSecondary, size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (mealPlan.isEmpty && !generatingPlan) ...[
            const Center(
              child: Column(
                children: [
                  SizedBox(height: 40),
                  Icon(Icons.dining_outlined,
                      color: AppColors.textMuted, size: 52),
                  SizedBox(height: 12),
                  Text('No meal plan yet',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 16)),
                  SizedBox(height: 6),
                  Text(
                      'Select ingredients and hit Generate',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ] else ...[
            const SectionHeader(title: "Today's Meal Plan"),
            const SizedBox(height: 12),
            ...mealPlan.map((meal) => _buildMealCard(meal)),
          ],
        ],
      ),
    );
  }

  Widget _buildMealCard(Map<String, String> meal) {
    const mealColors = {
      'Breakfast': AppColors.warning,
      'Lunch': AppColors.primary,
      'Snack': const Color(0xFFFF6BD6),
      'Dinner': AppColors.secondary,
    };
    final color =
        mealColors[meal['meal']] ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Row(
          children: [
            Text(meal['icon'] ?? '🍽️', style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PillBadge(label: meal['meal'] ?? '', color: color),
                      Text(
                        meal['time'] ?? '',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meal['dish'] ?? '',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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
