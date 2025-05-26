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
        primaryColor: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
          ),
        ),
      ),
      home: LoginScreen(),
    );
  }
}
