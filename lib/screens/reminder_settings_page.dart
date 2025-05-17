import 'package:flutter/material.dart';
import '../services/prayer_tracker.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';  

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  final List<String> prayers = ['Fajr', 'Dohr', 'Asr', 'Maghreb', 'Icha'];
  final List<String> days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  Map<String, List<bool>> remindersPerPrayer = {};

  final Map<String, String> prayerImages = {
    'Fajr': 'assets/ressources/fajr.png',
    'Dohr': 'assets/ressources/dohr.png',
    'Asr': 'assets/ressources/ASR.png',
    'Maghreb': 'assets/ressources/maghreb.png',
    'Icha': 'assets/ressources/icha.png',
  };

  @override
  void initState() {
    super.initState();
    _loadSavedReminders();
  }

  void _loadSavedReminders() async {
    final tracker = Provider.of<PrayerTracker>(context, listen: false);

    for (var prayer in prayers) {
      List<bool> savedDays = await tracker.getReminderDays(prayer);
      setState(() {
        remindersPerPrayer[prayer] = savedDays.isNotEmpty ? savedDays : List.filled(7, false);
      });
    }
  }

  void _saveAllReminders() async {
    try {
      final tracker = Provider.of<PrayerTracker>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);

      // Vérifier si les heures de prière sont disponibles
      bool hasPrayerTimes = true;
      for (var prayer in prayers) {
        if (tracker.getPrayerTime(prayer) == null) {
          hasPrayerTimes = false;
          break;
        }
      }

      if (!hasPrayerTimes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez d\'abord charger les heures de prière depuis l\'écran d\'accueil'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      for (var prayer in prayers) {
        final selectedDays = remindersPerPrayer[prayer]!;
        await tracker.saveReminderDays(prayer, selectedDays);

        for (int i = 0; i < selectedDays.length; i++) {
          if (selectedDays[i]) {
            try {
              DateTime scheduledTime = _getNextOccurrence(i, prayer);
              debugPrint("Planification de la notification pour $prayer le jour $i à ${scheduledTime.toString()}");
              
              await notificationService.schedulePrayerNotification(
                id: _generateNotificationId(prayer, i),
                title: 'Rappel de prière',
                body: 'Il est temps pour $prayer',
                scheduledTime: scheduledTime,
              );
            } catch (e) {
              debugPrint("Erreur lors de la planification de la notification pour $prayer le jour $i: $e");
            }
          }
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rappels enregistrés avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Erreur lors de l'enregistrement des rappels: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'enregistrement des rappels'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Rappels de Prière'),
        backgroundColor: Colors.brown[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            ...prayers.map((prayer) => Padding(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Replacing Icon with Image
                          Image.asset(
                            prayerImages[prayer]!, // Using the prayer's image
                            width: 32,
                            height: 32,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            prayer,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ToggleButtons(
                        borderRadius: BorderRadius.circular(12),
                        selectedColor: Colors.white,
                        fillColor: Colors.green[700],
                        color: Colors.green[900],
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        isSelected: remindersPerPrayer[prayer]!,
                        onPressed: (int index) {
                          setState(() {
                            remindersPerPrayer[prayer]![index] =
                                !remindersPerPrayer[prayer]![index];
                          });
                        },
                        children: days
                            .map((d) =>
                                Text(d, style: const TextStyle(fontWeight: FontWeight.bold)))
                            .toList(),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                _saveAllReminders();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[800],
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Enregistrer',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _generateNotificationId(String prayer, int weekdayIndex) {
    return prayer.hashCode + weekdayIndex;
  }

  DateTime _getNextOccurrence(int weekdayIndex, String prayer) {
    final tracker = Provider.of<PrayerTracker>(context, listen: false);
    final timeStr = tracker.getPrayerTime(prayer);

    if (timeStr == null) {
      debugPrint("Heure de prière non disponible pour $prayer");
      return DateTime.now().add(const Duration(minutes: 1)); // Retourne une date par défaut
    }

    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final now = DateTime.now();
      final currentWeekday = now.weekday;
      
      // Calcul du nombre de jours jusqu'au prochain jour de prière
      int daysUntilNext = (weekdayIndex + 1 - currentWeekday + 7) % 7;
      if (daysUntilNext == 0) {
        // Si c'est aujourd'hui, vérifions si l'heure est déjà passée
        final todayPrayerTime = DateTime(now.year, now.month, now.day, hour, minute);
        if (now.isAfter(todayPrayerTime)) {
          daysUntilNext = 7; // Planifier pour la semaine prochaine
        }
      }

      final nextDate = now.add(Duration(days: daysUntilNext));
      return DateTime(nextDate.year, nextDate.month, nextDate.day, hour, minute);
    } catch (e) {
      debugPrint("Erreur lors du calcul de la date pour $prayer: $e");
      return DateTime.now().add(const Duration(minutes: 1));
    }
  }
}

