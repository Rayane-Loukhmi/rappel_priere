import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrayerTracker extends ChangeNotifier {
  final SharedPreferences? prefs;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  PrayerTracker(this.prefs) {
    _loadData();
    _loadLocalStats();
    loadFirebaseData();
  }

  Map<String, List<bool>> reminderDays = {
    'Fajr': List.filled(7, false),
    'Dohr': List.filled(7, false),
    'Asr': List.filled(7, false),
    'Maghreb': List.filled(7, false),
    'Icha': List.filled(7, false),
  };

  double prayerCompletionRate = 0.0;
  double tasbihCompletionRate = 0.0;
  int _totalPrayers = 0;
  int _tasbihCycles = 0;
  int _currentStreak = 0;
  int _recordStreak = 0;
  Map<String, String> _prayerTimes = {};

  void _loadData() {
    if (prefs == null) {
      print('SharedPreferences is null, cannot load reminder data.');
      return;
    }
    
    try {
      for (var prayer in reminderDays.keys) {
        final saved = prefs!.getStringList('reminder_$prayer');
        if (saved != null && saved.length == 7) {
          reminderDays[prayer] = saved.map((e) => e == 'true').toList();
          print('Loaded reminder data for $prayer: ${reminderDays[prayer]}');
        } else {
          print('No saved reminder data found for $prayer.');
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error loading data from SharedPreferences: $e');
    }
  }

  void _loadLocalStats() {
    if (prefs == null) return;
    
    try {
      _totalPrayers = prefs!.getInt('local_total_prayers') ?? 0;
      _tasbihCycles = prefs!.getInt('local_tasbih_cycles') ?? 0;
      _currentStreak = prefs!.getInt('local_current_streak') ?? 0;
      _recordStreak = prefs!.getInt('local_record_streak') ?? 0;
      
      _updateCompletionRates();
      notifyListeners();
    } catch (e) {
      print('Error loading local stats: $e');
    }
  }

  void _saveLocalStats() {
    if (prefs == null) return;
    
    try {
      prefs!.setInt('local_total_prayers', _totalPrayers);
      prefs!.setInt('local_tasbih_cycles', _tasbihCycles);
      prefs!.setInt('local_current_streak', _currentStreak);
      prefs!.setInt('local_record_streak', _recordStreak);
    } catch (e) {
      print('Error saving local stats: $e');
    }
  }

  void _updateCompletionRates() {
    final totalDays = 7 * 5; // 7 days * 5 prayers
    final completedPrayers = _totalPrayers;
    prayerCompletionRate = totalDays > 0 ? completedPrayers / totalDays : 0.0;
    
    final targetTasbih = 33; // Assuming 33 is the target per day
    final totalTargetTasbih = 7 * targetTasbih;
    tasbihCompletionRate = totalTargetTasbih > 0 ? _tasbihCycles / totalTargetTasbih : 0.0;
  }

  Future<void> loadFirebaseData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      
      if (data != null && data['dashboardStats'] != null) {
        final stats = data['dashboardStats'];
        _totalPrayers = stats['totalPrayers'] ?? _totalPrayers;
        _tasbihCycles = stats['tasbihCycles'] ?? _tasbihCycles;
        _currentStreak = stats['currentStreak'] ?? _currentStreak;
        _recordStreak = stats['recordStreak'] ?? _recordStreak;
        
        _updateCompletionRates();
        _saveLocalStats();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading Firebase data: $e');
      // Continue with local data
    }
  }

  Future<void> saveReminderDays(String prayer, List<bool> days) async {
    if (prefs == null) {
      print('SharedPreferences is null, cannot save reminder data for $prayer.');
      return;
    }
    
    try {
      await prefs!.setStringList('reminder_$prayer', days.map((e) => e.toString()).toList());
      reminderDays[prayer] = days;
      print('Saved reminder data for $prayer: $days');
      notifyListeners();
    } catch (e) {
      print('Error saving reminder days for $prayer: $e');
    }
  }

  List<bool> getReminderDays(String prayer) {
    return reminderDays[prayer] ?? List.filled(7, false);
  }

  int getTotalCompletedPrayers() => _totalPrayers;
  int getCompletedTasbihCycles() => _tasbihCycles;
  int getCurrentStreak() => _currentStreak;
  int getRecordStreak() => _recordStreak;

  Future<void> incrementTotalPrayers() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'dashboardStats.totalPrayers': FieldValue.increment(1),
      });
      _totalPrayers++;
      loadFirebaseData(); // Reload all stats to ensure consistency
    } catch (e) {
      print('Error incrementing total prayers: $e');
    }
  }

  Future<void> incrementTasbihCycles() async {
    _tasbihCycles++;
    _updateCompletionRates();
    _saveLocalStats();
    notifyListeners();

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'dashboardStats.tasbihCycles': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error updating tasbih cycles in Firebase: $e');
      // Continue with local data
    }
  }

  Future<void> updateStreak(int newStreak) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final updates = {
        'dashboardStats.currentStreak': newStreak,
      };

      // Update record streak if new streak is higher
      if (newStreak > _recordStreak) {
        updates['dashboardStats.recordStreak'] = newStreak;
      }

      await _firestore.collection('users').doc(user.uid).update(updates);
      loadFirebaseData(); // Reload all stats to ensure consistency
    } catch (e) {
      print('Error updating streak: $e');
    }
  }

  void setPrayerTimes(Map<String, String> times) {
    _prayerTimes = times;
    notifyListeners();
  }

  String? getPrayerTime(String prayer) {
    return _prayerTimes[prayer];
  }
}


