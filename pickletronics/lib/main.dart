import 'package:flutter/material.dart';
import 'StartGame/startGameView.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(200, 200, 200, 200)),
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
    if (_tabController.index == 0) return 'Welcome Back';
    if (_tabController.index == 1) return 'Improve your Game';
    if (_tabController.index == 2) return 'Previous Sessions';
    return widget.title; // Fallback to default title
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_appBarTitle), // Set the title dynamically
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          StartGameView(),
          Center(child: Text('Recommendations')),
          Center(child: Text('Sessions')),
        ],
      ),
      bottomNavigationBar: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.sports_tennis), text: 'Start Game'),
          Tab(icon: Icon(Icons.read_more), text: 'Recommendations'),
          Tab(icon: Icon(Icons.analytics_outlined), text: 'Sessions'),
        ],
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.black,
      ),
    );
  }
}
