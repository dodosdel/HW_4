import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => WelcomeScreen(),
        '/main': (context) => MainScreen(),
        '/saved': (context) => SavedDataScreen(),
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkFirstLaunch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data!) {
            return WelcomeTutorial();
          } else {
            return MainScreen();
          }
        } else {
          return CircularProgressIndicator();
        }
      },
    );
  }

  Future<bool> _checkFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('firstLaunch') ?? true;
  }
}

class WelcomeTutorial extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome Tutorial'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome Tutorial'),
            ElevatedButton(
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.setBool('firstLaunch', false);
                Navigator.pushReplacementNamed(context, '/main');
              },
              child: Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Map<String, dynamic>> users = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Screen'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              // Fetch more users from API
              List<Map<String, dynamic>> newUsers = await _fetchUsers();
              setState(() {
                users.addAll(newUsers);
              });
            },
            child: Text('Fetch More Users'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Store data in SQLite database
              await _storeDataInDatabase(users);
            },
            child: Text('Store Data in Database'),
          ),
          ElevatedButton(
            onPressed: () {
              // Navigate to the saved data screen with a fade transition
              Navigator.push(context, _fadeTransition(SavedDataScreen()));
            },
            child: Text('View Saved Data'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_getUserName(users[index])),
                  subtitle: Text(users[index]['email'] ?? ''),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final response =
        await http.get(Uri.parse('https://randomuser.me/api/?results=5'));

    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to load users');
    }
  }

  Future<void> _storeDataInDatabase(List<Map<String, dynamic>> users) async {
    final database = await openDatabase(
      join(await getDatabasesPath(), 'user_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, email TEXT)',
        );
      },
      version: 1,
    );

    for (var user in users) {
      var filteredUser = {
        'name': _getUserName(user),
        'email': user['email'] ?? '',
      };

      await database.insert(
        'users',
        filteredUser,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  String _getUserName(Map<String, dynamic> user) {
    final name = user['name'];
    if (name is Map<String, dynamic>) {
      final firstName = name['first'] ?? '';
      final lastName = name['last'] ?? '';
      return '$firstName $lastName';
    }
    return '';
  }

  Route _fadeTransition(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.easeInOut;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        var fadeAnimation = animation.drive(tween);

        return FadeTransition(
          opacity: fadeAnimation,
          child: child,
        );
      },
    );
  }
}

class SavedDataScreen extends StatefulWidget {
  @override
  _SavedDataScreenState createState() => _SavedDataScreenState();
}

class _SavedDataScreenState extends State<SavedDataScreen> {
  List<Map<String, dynamic>> savedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final database = await openDatabase(
      join(await getDatabasesPath(), 'user_database.db'),
    );

    final List<Map<String, dynamic>> savedData = await database.query('users');

    setState(() {
      savedUsers = savedData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Data Screen'),
      ),
      body: ListView.builder(
        itemCount: savedUsers.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(savedUsers[index]['name'] ?? ''),
            subtitle: Text(savedUsers[index]['email'] ?? ''),
          );
        },
      ),
    );
  }
}
