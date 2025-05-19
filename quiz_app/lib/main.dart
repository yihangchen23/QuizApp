import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';

// Initialize Supabase
const String supabaseUrl = 'https://your-supabase-url.supabase.co';
const String supabaseKey = 'your-api-key';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthScreen(),
      routes: {
        '/dashboard': (context) => Dashboard(),
        '/quiz': (context) => QuizScreen(),
      },
    );
  }
}

// Hash password function for secure password storage (SHA256)
String _hashPassword(String password) {
  final bytes = utf8.encode(password);
  final hash = sha256.convert(bytes);
  return hash.toString();
}

// Auth Screen (Login/Register using `users` table)
class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _role = 'student';
  bool _isLogin = true;
  String _error = '';

  Future<void> _loginUser() async {
    try {
      final email = _emailController.text;
      final password = _passwordController.text;
      final hashedPassword = _hashPassword(password);

      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('email', email)
          .eq('password', hashedPassword)
          .single();

      if (response == null) {
        setState(() {
          _error = 'Invalid email or password';
        });
      } else {
        // You can store user info in local storage or navigation here
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      setState(() {
        _error = 'Login failed: $e';
      });
    }
  }

  Future<void> _registerUser() async {
    try {
      final email = _emailController.text;
      final password = _passwordController.text;
      final fullName = _nameController.text;
      final hashedPassword = _hashPassword(password);

      // Insert the new user into the users table
      final response = await Supabase.instance.client.from('users').insert([
        {
          'email': email,
          'password': hashedPassword,
          'full_name': fullName,
          'role': _role,
        }
      ]);

      if (response.error != null) {
        setState(() {
          _error = response.error!.message;
        });
      } else {
        setState(() {
          _isLogin = true;
          _error = 'Registration successful! Please login.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Registration failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login/Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Full Name'),
              ),
              DropdownButton<String>(
                value: _role,
                onChanged: (value) {
                  setState(() {
                    _role = value!;
                  });
                },
                items: <String>['student', 'teacher']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ],
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLogin ? _loginUser : _registerUser,
              child: Text(_isLogin ? 'Login' : 'Register'),
            ),
            SizedBox(height: 20),
            if (_error.isNotEmpty) Text(_error, style: TextStyle(color: Colors.red)),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                  _error = '';
                });
              },
              child: Text(_isLogin
                  ? 'Don’t have an account? Register here.'
                  : 'Already have an account? Login here.'),
            ),
          ],
        ),
      ),
    );
  }
}

// Dashboard Screen for Students/Teachers
class Dashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/quiz');
              },
              child: Text('Start Quiz'),
            ),
            ElevatedButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                Navigator.pushReplacementNamed(context, '/');
              },
              child: Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

// Quiz Screen
class QuizScreen extends StatefulWidget {
  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> questions = [
    {'question': 'What is Flutter?', 'answer': ''},
    {'question': 'What is Dart?', 'answer': ''},
  ];

  Future<void> _submitQuiz() async {
    // Simulate AI-based feedback
    for (var question in questions) {
      question['feedback'] = 'Good answer! Try to expand on your explanation.';
    }
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Quiz Submitted'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: questions.map((q) {
              return Text('${q['question']}: ${q['feedback']}');
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Take Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ...questions.map((q) {
              return TextField(
                onChanged: (value) {
                  q['answer'] = value;
                },
                decoration: InputDecoration(labelText: q['question']),
              );
            }).toList(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitQuiz,
              child: Text('Submit Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}
