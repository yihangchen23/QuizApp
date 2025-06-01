import 'package:flutter/material.dart';
import 'package:quiz_app/signup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/teacher_dashboard.dart';
import 'package:quiz_app/student_dashboard.dart';
import 'package:crypto/crypto.dart'; // for SHA256 hashing
import 'dart:convert'; // for utf8.encode

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;
  String _errorMessage = '';

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
                      child: Image.asset('../assets/logo.jpg'), // Replace with your logo
                    ),
                    SizedBox(height: 40.0),

                    // Username Field
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Icon(Icons.person, color: Colors.blueAccent),
                        filled: true,
                        fillColor: Colors.blueGrey.withOpacity(0.1),
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
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Icon(Icons.lock, color: Colors.blueAccent),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscure = !_isObscure;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: Colors.blueGrey.withOpacity(0.1),
                        contentPadding: EdgeInsets.symmetric(vertical: 18.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 30.0),

                    // Error message
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 40.0),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Log In',
                                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                              ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        elevation: 5.0,
                      ),
                    ),
                    SizedBox(height: 15.0),

                    /* "Forgot Password?" text
                    GestureDetector(
                      onTap: () {
                        print('Navigate to Forgot Password screen');
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 30.0),
                    */
                    // Sign-Up Link
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpScreen()));
                      },
                      child: Text(
                        'Don\'t have an account? Sign Up',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
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
      _errorMessage = '';
    });

    final String username = _usernameController.text;
    final String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please fill out both fields';
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
            _errorMessage = 'Invalid password for teacher account';
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
            _errorMessage = 'Invalid password for student account';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not found in teachers or students database.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred. Please try again.';
        print('login error: $e');
      });
    }
  }
}
