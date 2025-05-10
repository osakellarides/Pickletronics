import 'package:flutter/material.dart';
import 'package:pickletronics/viewSessions/SessionsTab.dart';
import 'StartGame/start_game_view.dart';
import 'package:logger/logger.dart';
import 'insightsTab/insights_tab.dart';

final Logger _logger = Logger();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(198, 48, 119, 87)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Pickletronics'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose(); // Clean up the controller when the widget is disposed.
    super.dispose();
  }

  String get _appBarTitle {
    // Check if the TabController is initialized and return the title based on the selected tab index
    if (_tabController.index == 0) return 'Pickletronics';
    if (_tabController.index == 1) return 'Improve your Game';
    if (_tabController.index == 2) return 'Previous Sessions';
    return widget.title; // Fallback to default title
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(197, 251, 251, 252),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Ensures spacing between text and logo
          children: [
            // Center this image in the app bar
            Image.asset(
              'assets/pickletronics_banner.png',
              height: 175,
              fit: BoxFit.fitHeight,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          StartGameView(),
          SessionsTab(),
          InsightsTab(),
        ],
      ),
      bottomNavigationBar: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.sports_tennis), text: 'Dashboard'),
          Tab(icon: Icon(Icons.analytics_outlined), text: 'Sessions'),
          Tab(icon: Icon(Icons.read_more), text: 'Insights'),
        ],
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.black,
      ),
    );
  }
}

void startGame() {
  _logger.i('Start Game button pressed');
}
