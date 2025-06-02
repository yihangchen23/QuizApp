import 'package:flutter/material.dart';
import 'package:quiz_app/teacher_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/login.dart';
import 'package:quiz_app/student_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kacvtverzchkkfrolwik.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImthY3Z0dmVyemNoa2tmcm9sd2lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDcwNjQ3NDgsImV4cCI6MjA2MjY0MDc0OH0.yFUaKLAyREtx9O_qey3_H6-8v5bk1bxZ4SOf6kSx0Js',
  );

  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Quiz App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.lightGreen,
        scaffoldBackgroundColor: Colors.lightGreen.shade700,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.lightGreen.shade900,
          elevation: 8,
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            iconColor: MaterialStateProperty.all(Colors.lightGreen),
          ),
        ),
        iconTheme: IconThemeData(
          color: Colors.lightGreen,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          margin: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          color: Colors.limeAccent[100],
        ),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.lightGreen.shade800, width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.lightGreen.shade600, width: 1.0),
          ),
        ),
      ),
      home: LoginScreen(),
    );
  }

  static void errorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 16),
            Text(message, style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
