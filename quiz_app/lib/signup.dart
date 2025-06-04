import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart'; // for SHA256 hashing
import 'package:quiz_app/login.dart';
import 'dart:convert'; // for utf8.encode
import 'package:quiz_app/main.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;
  String _selectedRole = 'student'; // Default role is student

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
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column (
                          children: [
                            // Full Name Field
                            TextField(
                              controller: _fullNameController,
                              decoration: InputDecoration(
                                labelText: 'Full Name',
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

                            // Email Field
                            TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(
                                  color: Colors.lightGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: Icon(Icons.email, color: Colors.lightGreen),
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

                            // Role Selection (Student or Teacher)
                            Row(
                              children: [
                                Text('I am a: ', style: TextStyle(color: Colors.lime.shade700)),
                                Radio<String>(
                                  value: 'student',
                                  groupValue: _selectedRole,
                                  fillColor: MaterialStateProperty.all(Colors.lime.shade900),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRole = value!;
                                    });
                                  },
                                ),
                                Text('Student', style: TextStyle(color: Colors.lime.shade700)),
                                Radio<String>(
                                  value: 'teacher',
                                  groupValue: _selectedRole,
                                  fillColor: MaterialStateProperty.all(Colors.lime.shade900),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRole = value!;
                                    });
                                  },
                                ),
                                Text('Teacher', style: TextStyle(color: Colors.lime.shade700)),
                              ],
                            ),

                            // Sign Up Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _signUp,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 40.0),
                                child: _isLoading
                                    ? CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                        'Sign Up',
                                        style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.lime.shade900),
                                      ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lime,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                elevation: 5.0,
                              ),
                            ),
                            SizedBox(height: 15.0),

                            // Already have an account? Login Link
                            GestureDetector(
                              onTap: () {
                                print('Navigate to Login screen');
                                Navigator.pop(context); // Navigate to the login screen
                              },
                              child: Text(
                                'Already have an account? Log In',
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

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });

    final String email = _emailController.text;
    final String fullName = _fullNameController.text;
    final String password = _passwordController.text;

    // Validate input fields
    if (email.isEmpty || fullName.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        QuizApp.errorSnackBar(context, 'Please fill out all fields');
      });
      return;
    }

    try {
      // Check if the email already exists in either the 'teachers' or 'students' tables
      final teacherResponse = await Supabase.instance.client
          .from('teachers')
          .select()
          .eq('email', email);

      final studentResponse = await Supabase.instance.client
          .from('students')
          .select()
          .eq('email', email);

      if (teacherResponse.isNotEmpty || studentResponse.isNotEmpty) {
        setState(() {
          _isLoading = false;
          QuizApp.errorSnackBar(context, 'Username has been taken. Please try again.');
        });
        return;
      }

      // Hash the password using SHA256
      String passwordHash = _generateSha256Hash(password);

      // Insert into the appropriate table based on the selected role
      if (_selectedRole == 'student') {
        final insertStudentResponse = await Supabase.instance.client.from('students').insert([
          {
            'email': email,
            'password': passwordHash,
            'full_name': fullName,
          }
        ]);

        if (insertStudentResponse.error == null) {
          // Navigate to login page
          Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
        } else {
          setState(() {
            _isLoading = false;
            QuizApp.errorSnackBar(context, 'Failed to create account');
          });
        }
      } else if (_selectedRole == 'teacher') {
        final insertTeacherResponse = await Supabase.instance.client.from('teachers').insert([
          {
            'email': email,
            'password': passwordHash,
            'full_name': fullName,
          }
        ]);

        if (insertTeacherResponse.error == null) {
          // Navigate to login page
          Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
        } else {
          setState(() {
            _isLoading = false;
            QuizApp.errorSnackBar(context, 'Failed to create account');
          });
        }
      }
    } catch (e) {
      QuizApp.happySnackBar(context, 'Account Creation Successful!');
      Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
    }
  }
}
