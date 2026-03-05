import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── REGISTER ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String gender,
    int age = 0,
    double height = 0.0,
    double weight = 0.0,
    double bmi = 0.0,
    double calories = 0.0,
    String activity = 'Low',
    String target = 'Maintain Weight',
    List<Map<String, String>> ingredients = const [],
  }) async {
    try {
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCred.user!.uid;
      await _db.collection('users').doc(uid).set({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'age': age,
        'height': height,
        'weight': weight,
        'bmi': bmi,
        'calories': calories,
        'activity': activity,
        'target': target,
        'gender': gender,
        'ingredients': ingredients,
        'water_goal': 8,
        'water_today': 0,
        'water_date': DateTime.now().toIso8601String().substring(0, 10),
        'calories_consumed': 0.0,
        'bmi_history': [],
        'workout_logs': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      return {'success': true, 'uid': uid};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Registration failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── LOGIN ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final doc = await _db.collection('users').doc(userCred.user!.uid).get();
      if (!doc.exists) return {'success': false, 'message': 'User profile not found'};
      return {'success': true, 'data': doc.data()};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  // ─── GET CURRENT USER ────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // ─── UPDATE USER ─────────────────────────────────────────────────────────
  Future<void> updateUserData({
    int? age,
    double? height,
    double? weight,
    double? bmi,
    double? calories,
    String? activity,
    String? target,
    String? gender,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = <String, dynamic>{};
    if (age != null) data['age'] = age;
    if (height != null) data['height'] = height;
    if (weight != null) data['weight'] = weight;
    if (bmi != null) data['bmi'] = bmi;
    if (calories != null) data['calories'] = calories;
    if (activity != null) data['activity'] = activity;
    if (target != null) data['target'] = target;
    if (gender != null) data['gender'] = gender;

    // Save BMI history entry
    if (bmi != null && weight != null) {
      final doc = await _db.collection('users').doc(user.uid).get();
      final docData = doc.data() ?? {};
      final existing = List<dynamic>.from((docData['bmi_history'] as List<dynamic>?) ?? []);
      existing.add({
        'bmi': bmi,
        'weight': weight,
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      if (existing.length > 30) existing.removeAt(0);
      data['bmi_history'] = existing;
    }

    await _db.collection('users').doc(user.uid).update(data);
  }

  // ─── BMI HISTORY ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBMIHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return [];
    final docData = doc.data() ?? {};
    final raw = (docData['bmi_history'] as List<dynamic>?) ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ─── INGREDIENTS ─────────────────────────────────────────────────────────
  Future<void> saveUserIngredients(List<Map<String, String>> ingredients) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({'ingredients': ingredients});
  }

  Future<List<Map<String, String>>> getUserIngredients() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return [];
    final docData = doc.data() ?? {};
    final raw = (docData['ingredients'] as List<dynamic>?) ?? [];
    return raw.map((e) => Map<String, String>.from(e)).toList();
  }

  // ─── WATER TRACKER ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getWaterData() async {
    final user = _auth.currentUser;
    if (user == null) return {'today': 0, 'goal': 8};
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return {'today': 0, 'goal': 8};
    final docData = doc.data() ?? {};
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = (docData['water_date'] as String?) ?? '';
    final waterToday = storedDate == today ? ((docData['water_today'] as int?) ?? 0) : 0;
    return {'today': waterToday, 'goal': (docData['water_goal'] as int?) ?? 8};
  }

  Future<void> updateWater(int glasses) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _db.collection('users').doc(user.uid).update({
      'water_today': glasses,
      'water_date': today,
    });
  }

  // ─── CALORIES CONSUMED ───────────────────────────────────────────────────
  Future<void> updateCaloriesConsumed(double calories) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'calories_consumed': calories,
      'calories_date': DateTime.now().toIso8601String().substring(0, 10),
    });
  }

  // ─── WORKOUT LOG ─────────────────────────────────────────────────────────
  Future<void> addWorkoutLog({
    required String name,
    required int durationMinutes,
    required String type,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await _db.collection('users').doc(user.uid).get();
    final docData = doc.data() ?? {};
    final existing = List<dynamic>.from((docData['workout_logs'] as List<dynamic>?) ?? []);
    existing.add({
      'name': name,
      'duration': durationMinutes,
      'type': type,
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    if (existing.length > 50) existing.removeAt(0);
    await _db.collection('users').doc(user.uid).update({'workout_logs': existing});
  }

  Future<List<Map<String, dynamic>>> getWorkoutLogs() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return [];
    final docData = doc.data() ?? {};
    final raw = (docData['workout_logs'] as List<dynamic>?) ?? [];
    return raw.reversed.take(20).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ─── DELETE / LOGOUT ─────────────────────────────────────────────────────
  Future<void> deleteUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).delete();
    await user.delete();
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
