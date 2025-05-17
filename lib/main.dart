import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/auth/login_page.dart';
import 'screens/auth/signup_page.dart';
import 'screens/prayer_times_page.dart';
import 'services/auth_service.dart';
import 'services/prayer_tracker.dart';
import 'screens/reminder_settings_page.dart';
import 'services/notification_service.dart';
import 'screens/tasbih_page.dart';
import 'screens/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize date formatting for French locale
  await initializeDateFormatting('fr_FR', null);
  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyD4I1-CXuZKPwCn6oWzh9bjlJiB9pEzmHE",
          authDomain: "test1pfa-9886e.firebaseapp.com",
          projectId: "test1pfa-9886e",
          storageBucket: "test1pfa-9886e.appspot.com",
          messagingSenderId: "287989378369",
          appId: "1:287989378369:web:6cfc7fd8701886f7a485c0",
        ),
      );
      
      // Enable offline persistence for Firestore
      FirebaseFirestore.instance.enablePersistence()
        .catchError((e) => print('Error enabling Firestore persistence: $e'));
    }
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
    // Continue without Firebase
  }
  
  SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    print('SharedPreferences initialized successfully');
  } catch (e) {
    print('Error initializing SharedPreferences: $e');
    // Create a mock SharedPreferences instance
    prefs = await SharedPreferences.getInstance();
  }

  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthService(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => PrayerTracker(prefs),
        ),
        Provider<NotificationService>.value(
          value: notificationService,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAFFEL PRIÈRE',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainNavigationPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const MainNavigationPage(),
      },
      onGenerateRoute: (settings) {
        // Handle any other routes here
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) => const MainNavigationPage());
        }
        return null;
      },
      onUnknownRoute: (settings) {
        // Handle unknown routes by redirecting to home
        return MaterialPageRoute(builder: (context) => const MainNavigationPage());
      },
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = [
    const PrayerTimesPage(),
    const ReminderSettingsPage(),
    const TasbihPage(),
    const DashboardPage(),
  ];

  final Color navbarColor = const Color(0xFF2A1B04);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove default back button
        backgroundColor: navbarColor,
        title: const Text('RAFFEL PRIÈRE', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: navbarColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (auth.isLoggedIn)
                    Text(
                      auth.user?.email ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    )
                  else
                    const Text(
                      'Guest',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            if (auth.isLoggedIn)
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: const Text('Profile'),
                onTap: () {
                  // Add profile navigation here
                  Navigator.pop(context);
                },
              ),
            if (!auth.isLoggedIn)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Login'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/login');
                },
              ),
            if (!auth.isLoggedIn)
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Sign Up'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/signup');
                },
              ),
            if (auth.isLoggedIn)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(context);
                  auth.signOut();
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                // Add settings navigation here
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Feedback'),
              onTap: () {
                // Add help navigation here
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: navbarColor,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0 || auth.isLoggedIn) {
            setState(() {
              _currentIndex = index;
            });
          } else {
            Navigator.pushNamed(context, '/login');
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Image.asset('assets/ressources/icon_home.png', width: 24),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/ressources/icon_time_.png', width: 24),
            label: 'Rappels',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/ressources/icon_tasbih.png', width: 67),
            label: 'Tasbih',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/ressources/icon_stats.png', width: 24),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}