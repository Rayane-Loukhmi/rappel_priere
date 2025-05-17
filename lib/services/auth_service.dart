import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  final SharedPreferences? prefs;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool _isLoggedIn = false;

  AuthService(this.prefs) {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoggedIn = user != null;
      notifyListeners();
    });
  }

  bool get isLoggedIn => _isLoggedIn;
  User? get user => _user;

  Future<String?> signUp(String email, String password) async {
    try {
      print('Tentative de création de compte avec email: $email');
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Compte créé avec succès, UID: ${result.user?.uid}');
      
      // Créer un document utilisateur dans Firestore
      try {
        if (result.user == null) {
          throw Exception('User is null after successful authentication');
        }
        
        await _firestore.collection('users').doc(result.user!.uid).set({
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'prayerReminders': {},
          'dashboardStats': {
            'totalPrayers': 0,
            'tasbihCycles': 0,
            'currentStreak': 0,
            'recordStreak': 0,
          }
        });
        print('Document utilisateur créé dans Firestore');
      } catch (e) {
        print('Erreur lors de la création du document Firestore: $e');
        // Supprimer le compte utilisateur si la création du document échoue
        await result.user?.delete();
        return 'Erreur lors de la création du profil utilisateur: $e';
      }

      return null; // Pas d'erreur
    } on FirebaseAuthException catch (e) {
      print('Erreur Firebase Auth lors de l\'inscription: ${e.code} - ${e.message}');
      return e.message ?? 'Une erreur est survenue lors de l\'inscription';
    } catch (e) {
      print('Erreur inattendue lors de l\'inscription: $e');
      return 'Une erreur inattendue est survenue';
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      print('Tentative de connexion avec email: $email');
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Connexion réussie');
      return null; // Pas d'erreur
    } on FirebaseAuthException catch (e) {
      print('Erreur Firebase Auth lors de la connexion: ${e.code} - ${e.message}');
      return e.message ?? 'Une erreur est survenue lors de la connexion';
    } catch (e) {
      print('Erreur inattendue lors de la connexion: $e');
      return 'Une erreur inattendue est survenue';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> savePrayerReminders(Map<String, List<bool>> reminders) async {
    if (_user == null) {
      print('Tentative de sauvegarde des rappels sans utilisateur connecté');
      return;
    }
    
    try {
      print('Tentative de sauvegarde des rappels pour l\'utilisateur ${_user!.uid}');
      await _firestore.collection('users').doc(_user!.uid).update({
        'prayerReminders': reminders,
      });
      print('Rappels sauvegardés avec succès');
    } catch (e) {
      print('Erreur lors de la sauvegarde des rappels: $e');
      rethrow;
    }
  }

  Future<Map<String, List<bool>>> getPrayerReminders() async {
    if (_user == null) {
      print('Tentative de récupération des rappels sans utilisateur connecté');
      return {};
    }
    
    try {
      print('Tentative de récupération des rappels pour l\'utilisateur ${_user!.uid}');
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      final data = doc.data();
      if (data == null || data['prayerReminders'] == null) {
        print('Aucun rappel trouvé pour l\'utilisateur');
        return {};
      }
      
      return Map<String, List<bool>>.from(data['prayerReminders']);
    } catch (e) {
      print('Erreur lors de la récupération des rappels: $e');
      return {};
    }
  }

  Future<void> updateDashboardStats({
    int? totalPrayers,
    int? tasbihCycles,
    int? currentStreak,
    int? recordStreak,
  }) async {
    if (_user == null) {
      print('Tentative de mise à jour des statistiques sans utilisateur connecté');
      return;
    }

    try {
      print('Tentative de mise à jour des statistiques pour l\'utilisateur ${_user!.uid}');
      final updates = <String, dynamic>{};
      if (totalPrayers != null) updates['dashboardStats.totalPrayers'] = totalPrayers;
      if (tasbihCycles != null) updates['dashboardStats.tasbihCycles'] = tasbihCycles;
      if (currentStreak != null) updates['dashboardStats.currentStreak'] = currentStreak;
      if (recordStreak != null) updates['dashboardStats.recordStreak'] = recordStreak;

      await _firestore.collection('users').doc(_user!.uid).update(updates);
      print('Statistiques mises à jour avec succès');
    } catch (e) {
      print('Erreur lors de la mise à jour des statistiques: $e');
      // Don't rethrow the error, just log it
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    if (_user == null) return {
      'totalPrayers': 0,
      'tasbihCycles': 0,
      'currentStreak': 0,
      'recordStreak': 0,
    };
    
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      final data = doc.data();
      if (data == null || data['dashboardStats'] == null) return {
        'totalPrayers': 0,
        'tasbihCycles': 0,
        'currentStreak': 0,
        'recordStreak': 0,
      };
      
      return Map<String, dynamic>.from(data['dashboardStats']);
    } catch (e) {
      print('Error getting dashboard stats: $e');
      // Return default values if there's an error
      return {
        'totalPrayers': 0,
        'tasbihCycles': 0,
        'currentStreak': 0,
        'recordStreak': 0,
      };
    }
  }
}
