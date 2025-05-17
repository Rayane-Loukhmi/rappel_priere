import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/prayer_tracker.dart';

class TasbihPage extends StatefulWidget {
  const TasbihPage({super.key});

  @override
  State<TasbihPage> createState() => _TasbihPageState();
}

class _TasbihPageState extends State<TasbihPage> {
  int _count = 0;
  final String _storageKey = 'tasbih_count';
  bool _isCycleComplete = false;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _count = prefs.getInt(_storageKey) ?? 0;
    });
  }

  Future<void> _saveCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storageKey, _count);
  }

  void _incrementCounter() {
    setState(() {
      if (_count == 33) {
        _count = 0;
        _isCycleComplete = true;
      } else {
        _count++;
        _isCycleComplete = false;
      }
    });
    _saveCount();

    // If we've completed a cycle, increment the tasbih cycles in Firebase
    if (_isCycleComplete) {
      final tracker = Provider.of<PrayerTracker>(context, listen: false);
      tracker.incrementTasbihCycles().then((_) {
        // Show a completion message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cycle de Tasbih complété!'),
            duration: Duration(seconds: 2),
          ),
        );
      }).catchError((error) {
        print('Error updating tasbih cycles: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la mise à jour des statistiques'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      });
    }
  }

  void _resetCounter() {
    setState(() {
      _count = 0;
      _isCycleComplete = false;
    });
    _saveCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/ressources/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Image en haut comme dans le modèle
              Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: Image.asset(
                  'assets/ressources/tasbihpage.png',
                  width: 250,
                  height: 324,
                  fit: BoxFit.contain,
                ),
              ),

              const Spacer(),

              // Bouton avec compteur intégré
              Stack(
                alignment: Alignment.center,
                children: [
                  // Cercle doré en fond
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAC67C).withOpacity(0.7),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),

                  // Texte du compteur
                  Text(
                    '$_count/33',
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'Kanit',
                    ),
                  ),

                  // Overlay décoratif
                  Opacity(
                    opacity: 0.8,
                    child: Image.asset(
                      'assets/ressources/tasbihbutton.png',
                      width: 220,
                      height: 220,
                    ),
                  ),

                  // Zone cliquable
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(110),
                        onTap: _incrementCounter,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Bouton Reset
              Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: TextButton(
                  onPressed: _resetCounter,
                  child: const Text(
                    'Réinitialiser',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black54,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}