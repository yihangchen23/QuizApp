import 'package:flutter/material.dart';
import 'package:quiz_app/signup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/teacher_dashboard.dart';
import 'package:quiz_app/student_dashboard.dart';
import 'package:crypto/crypto.dart'; // for SHA256 hashing
import 'dart:convert'; // for utf8.encode
import 'package:quiz_app/main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;

  // SHA256 Hashing Function
  String _generateSha256Hash(String password) {
    var bytes = utf8.encode(password); // Convert string to bytes
    var digest = sha256.convert(bytes); // Hash the bytes using SHA-256
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 500), // Limit max width to 500px
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    AnimatedContainer(
                      duration: Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      width: 120.0,
                      height: 120.0,
                      child: Image.asset('../assets/logo.png'), // Replace with your logo
                    ),
                    SizedBox(height: 15.0),
                    Text(
                      'KwikGrade',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40, color: Colors.black),
                    ),
                    Text(
                      'AI graded quizzes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.lightGreen.shade900),
                    ),
                    SizedBox(height: 40.0),
                    Card (
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column (
                          children: [
                            // Username Field
                            TextField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                labelStyle: TextStyle(
                                  color: Colors.lightGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: Icon(Icons.person, color: Colors.lightGreen),
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.1),
                                contentPadding: EdgeInsets.symmetric(vertical: 18.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                              ),
                            ),
                            SizedBox(height: 25.0),

                            // Password Field
                            TextField(
                              controller: _passwordController,
                              obscureText: _isObscure,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(
                                  color: Colors.lightGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: Icon(Icons.lock, color: Colors.lightGreen),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isObscure ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isObscure = !_isObscure;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.1),
                                contentPadding: EdgeInsets.symmetric(vertical: 18.0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                              ),
                            ),
                            SizedBox(height: 30.0),

                            // Login Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 40.0),
                                child: _isLoading
                                    ? CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                        'Log In',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.lime.shade900),
                                      ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lime,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                elevation: 8,
                              ),
                            ),
                            SizedBox(height: 15.0),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpScreen()));
                              },
                              child: Text(
                                'Don\'t have an account? Sign Up',
                                style: TextStyle(
                                  color: Colors.lime.shade700,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final String username = _usernameController.text;
    final String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        QuizApp.errorSnackBar(context, 'Please fill out both fields');
      });
      return;
    }

    try {
      // Query the teachers table to check if the user exists
      final teacherResponse = await Supabase.instance.client
          .from('teachers')
          .select()
          .eq('email', username);

      // Query the students table to check if the user exists
      final studentResponse = await Supabase.instance.client
          .from('students')
          .select()
          .eq('email', username);

      // Check if the user is a teacher
      if (teacherResponse.isNotEmpty) {
        final teacher = teacherResponse[0];
        String storedHash = teacher['password'] as String; // Assuming 'password' is SHA256 hashed

        // Generate SHA256 hash of the entered password and compare
        String enteredPasswordHash = _generateSha256Hash(password);
        print('$enteredPasswordHash ||| $storedHash');

        if (storedHash == enteredPasswordHash) {
          // Password matches, navigate to teacher dashboard
          //Navigator.pushReplacementNamed(context, '/teacher_dashboard');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TeacherDashboardScreen(teacherId: teacher['id'], teacherName: teacher['full_name'],), // Pass the teacher ID
            ),
          );
          print('Navigate to teacher dashboard');
        } else {
          setState(() {
            _isLoading = false;
            QuizApp.errorSnackBar(context, 'Invalid username or password');
          });
        }
      }
      // Check if the user is a student
      else if (studentResponse.isNotEmpty) {
        final student = studentResponse[0];
        String storedHash = student['password']; // Assuming 'password' is SHA256 hashed

        // Generate SHA256 hash of the entered password and compare
        String enteredPasswordHash = _generateSha256Hash(password);

        if (storedHash == enteredPasswordHash) {
          // Password matches, navigate to student dashboard
          //Navigator.pushReplacementNamed(context, '/student_dashboard');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => StudentDashboardScreen(studentId: student['id'], studentName: student['full_name'],), // Pass the student ID
            ),
          );
          print('navigate to student dashboard');
        } else {
          setState(() {
            _isLoading = false;
            QuizApp.errorSnackBar(context, 'Invalid username or password');
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          QuizApp.errorSnackBar(context, 'Invalid username or password');
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        QuizApp.errorSnackBar(context, 'An error occurred. Please try again.');
        print('login error: $e');
      });
    }
  }
}
