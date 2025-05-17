import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/prayer_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';


class PrayerTimesPage extends StatefulWidget {
  const PrayerTimesPage({super.key});

  @override
  _PrayerTimesPageState createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  Map<String, String> prayerTimes = {};
  Map<String, bool> completedPrayers = {};
  bool isLoading = true;
  String errorMessage = '';
  String location = '';
  String hijriDate = '';
  List<bool> selectedDays = List.filled(7, true); // Tous les jours sélectionnés par défaut

  @override
  void initState() {
    super.initState();
    _fetchPrayerTimes();
    _loadCompletedPrayers();
  }

  Future<void> _loadCompletedPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    final saved = prefs.getString('completed_prayers_$today');
    
    if (saved != null) {
      setState(() {
        completedPrayers = Map<String, bool>.from(jsonDecode(saved));
      });
    } else {
      setState(() {
        completedPrayers = {
          'Fajr': false,
          'Dohr': false,
          'Asr': false,
          'Maghreb': false,
          'Icha': false,
        };
      });
    }
  }

  Future<void> _saveCompletedPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    await prefs.setString('completed_prayers_$today', jsonEncode(completedPrayers));
  }

  Future<void> _markPrayerAsCompleted(String prayerName) async {
    if (!completedPrayers[prayerName]!) {
      setState(() {
        completedPrayers[prayerName] = true;
      });
      await _saveCompletedPrayers();
      
      // Update Firebase stats
      final tracker = Provider.of<PrayerTracker>(context, listen: false);
      await tracker.incrementTotalPrayers();
      
      // Check if all prayers are completed for the day
      if (completedPrayers.values.every((completed) => completed)) {
        final currentStreak = tracker.getCurrentStreak();
        await tracker.updateStreak(currentStreak + 1);
      }
    }
  }

  Future<void> _fetchPrayerTimes() async {
    try {
      print('Début de la récupération des temps de prière');
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Service de localisation désactivé');
        setState(() {
          errorMessage = 'Activez les services de localisation';
          isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('Permission de localisation refusée, demande de permission');
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          print('Permission de localisation refusée après demande');
          setState(() {
            errorMessage = 'Permissions de localisation refusées';
            isLoading = false;
          });
          return;
        }
      }

      print('Récupération de la position');
      Position position = await Geolocator.getCurrentPosition();
      final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
      
      print('Position: ${position.latitude}, ${position.longitude}');
      print('Date: $date');

      print('Appel de l\'API Aladhan');
      final response = await http.get(Uri.parse(
          'http://api.aladhan.com/v1/timings/$date?latitude=${position.latitude}&longitude=${position.longitude}&method=4'));

      print('Réponse API reçue: ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Erreur API: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      print('Données décodées: $data');

      if (data['data'] == null || data['data']['timings'] == null) {
        throw Exception('Format de réponse invalide');
      }

      final timings = data['data']['timings'];
      print('Timings extraits: $timings');

      final Map<String, String> newPrayerTimes = {
        'Fajr': timings['Fajr']?.toString() ?? '00:00',
        'Dohr': timings['Dhuhr']?.toString() ?? '00:00',
        'Asr': timings['Asr']?.toString() ?? '00:00',
        'Maghreb': timings['Maghrib']?.toString() ?? '00:00',
        'Icha': timings['Isha']?.toString() ?? '00:00',
      };

      print('Nouveaux temps de prière créés: $newPrayerTimes');

      setState(() {
        prayerTimes = newPrayerTimes;
        location = data['data']['meta']?['timezone']?.toString() ?? 'Timezone inconnue';
        hijriDate = '${data['data']['date']?['hijri']?['day'] ?? '?'} ${data['data']['date']?['hijri']?['month']?['en'] ?? '?'} ${data['data']['date']?['hijri']?['year'] ?? '?'}';
        isLoading = false;
      });

      if (mounted) {
        print('Mise à jour du tracker');
        final tracker = Provider.of<PrayerTracker>(context, listen: false);
        tracker.setPrayerTimes(newPrayerTimes);
        _schedulePrayerNotifications();
      }
    } catch (e, stackTrace) {
      print('Erreur détaillée: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        errorMessage = 'Erreur: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _schedulePrayerNotifications() {
    if (!mounted) return;
    
    try {
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      final now = DateTime.now();

      prayerTimes.forEach((prayerName, prayerTimeStr) {
        try {
          final prayerTime = DateFormat('HH:mm').parse(prayerTimeStr);
          final prayerDateTime = DateTime(
            now.year, 
            now.month, 
            now.day, 
            prayerTime.hour, 
            prayerTime.minute
          );

          // Planifier pour chaque jour sélectionné
          for (int i = 0; i < selectedDays.length; i++) {
            if (selectedDays[i]) {
              final notificationTime = _getNextWeekday(i, prayerDateTime);
              notificationService.schedulePrayerNotification(
                id: i + prayerName.hashCode,
                title: 'Rappel: $prayerName',
                body: 'Il est temps pour la prière de $prayerName',
                scheduledTime: notificationTime,
              );
            }
          }
        } catch (e) {
          debugPrint('Erreur de planification pour $prayerName: $e');
        }
      });
    } catch (e) {
      debugPrint('Erreur lors de la planification des notifications: $e');
    }
  }

  DateTime _getNextWeekday(int weekday, DateTime baseTime) {
    var nextDate = baseTime.add(Duration(days: (weekday - baseTime.weekday) % 7));
    if (nextDate.isBefore(baseTime)) {
      nextDate = nextDate.add(const Duration(days: 7));
    }
    return nextDate;
  }

  Widget _buildPrayerTimeCard(String prayerName, String time) {
    final isCompleted = completedPrayers[prayerName] ?? false;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          prayerName,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: Text(time),
        trailing: isCompleted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : IconButton(
                icon: const Icon(Icons.check),
                onPressed: () => _markPrayerAsCompleted(prayerName),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/ressources/background.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Column(
                              children: [
                                Text(
                                  'RAPPEL PRIÈRE',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat('dd MMMM yyyy').format(DateTime.now()),
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.black87),
                                ),
                                Text(
                                  hijriDate,
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.black54),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  location,
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              children: prayerTimes.entries.map((entry) {
                                return _buildPrayerTimeCard(entry.key, entry.value);
                              }).toList(),
                            ),
                          ),
                          // Bouton pour gérer les rappels
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  
}
