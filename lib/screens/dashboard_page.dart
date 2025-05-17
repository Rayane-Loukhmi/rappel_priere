import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/prayer_tracker.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tracker = Provider.of<PrayerTracker>(context, listen: false);
      tracker.loadFirebaseData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tracker = Provider.of<PrayerTracker>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/ressources/logo.png',
              height: 30,
              width: 30,
            ),
            const SizedBox(width: 10),
            const Text('Tableau de Bord'),
          ],
        ),
        backgroundColor: Colors.transparent, // Make appbar transparent
        elevation: 0, // Remove shadow
      ),
      extendBodyBehindAppBar: true, // Important for background to extend behind appbar
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/ressources/background.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Color overlay to improve text readability (adjust opacity as needed)
          Container(
            color: Colors.black.withOpacity(0.2),
          ),
          // Your content
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 16), // Extra top padding for appbar
              child: Column(
                children: [
                  _buildDateHeader(),
                  const SizedBox(height: 20),
                  // Weekly Summary Title with improved visibility
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Suivi Hebdomadaire',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Cards with slight transparency
                  _buildProgressCard(
                    context,
                    title: 'Prières effectuées à temps',
                    progress: tracker.prayerCompletionRate,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 15),
                  
                  _buildProgressCard(
                    context,
                    title: 'Tasbih complétés',
                    progress: tracker.tasbihCompletionRate,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 25),
                  
                  _buildStatsGrid(context, tracker),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Update your card widgets to be slightly transparent
  Widget _buildProgressCard(
    BuildContext context, {
    required String title,
    required double progress,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      color: Colors.white.withOpacity(0.8), // Added transparency
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.2),
              color: color,
              minHeight: 10,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progression'),
                Text('${(progress * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, PrayerTracker tracker) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _buildStatCard(
          icon: Icons.mosque,
          value: '${tracker.getTotalCompletedPrayers()}',
          label: 'Prières totales',
        ),
        _buildStatCard(
          icon: Icons.repeat,
          value: '${tracker.getCompletedTasbihCycles()}',
          label: 'Cycles de Tasbih',
        ),
        _buildStatCard(
          icon: Icons.calendar_today,
          value: '${tracker.getCurrentStreak()} jours',
          label: 'Série actuelle',
        ),
        _buildStatCard(
          icon: Icons.star,
          value: '${tracker.getRecordStreak()} jours',
          label: 'Record',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white.withOpacity(0.8), // Added transparency
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.amber[700]),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Update date header for better visibility
  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            DateFormat('EEEE, d MMMM yyyy', 'fr_FR').format(DateTime.now()),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}