import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/login.dart';
import 'package:quiz_app/student_class.dart';
import 'package:quiz_app/student_history.dart';
import 'package:quiz_app/main.dart';

class StudentDashboardScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  StudentDashboardScreen({required this.studentId, required this.studentName});

  @override
  _StudentDashboardScreenState createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _classes = [];
  final _enrollClassIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchClasses(context);
    });
  }

  Future<void> _fetchClasses(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('student_class_enrollments')
          .select()
          .eq('student_id', widget.studentId);

      setState(() {
        _classes = response;
      });
    } catch (e) {
      setState(() {
        QuizApp.errorSnackBar(context, 'Error fetching classes');
        print('Error: $e');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _enrollmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Enter a class ID to enroll',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.lightGreen.shade800,
            ),
          ),
          content: Form(
            child: TextField(
              controller: _enrollClassIdController,
              decoration: InputDecoration(
                labelText: 'Class ID',
                prefixIcon: Icon(Icons.class_),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.lightGreen.shade700)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Enroll', style: TextStyle(color: Colors.lightGreen.shade900)),
              onPressed: () {
                _enrollInClass(context);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightGreen,
              ),
            ),
          ],
        );
      }
    );
  }

  Future<void> _enrollInClass(BuildContext context) async {
    final classId = _enrollClassIdController.text.trim();
    
    if (classId.isEmpty) {
      setState(() {
        QuizApp.errorSnackBar(context, 'Please enter a class ID');
      });
      return;
    }

    try {
      await Supabase.instance.client.from('enrollments').insert([
        {'student_id': widget.studentId, 'class_id': classId}
      ]);
      setState() {
        _enrollClassIdController.clear();
        _fetchClasses(context);
      }
    } catch (e) {
      setState(() {
        QuizApp.errorSnackBar(context, 'Failed to enroll. Ensure class ID is valid.');
        print('Enroll Error: $e');
      });
    }
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(85.0),
        child: AppBar(
          flexibleSpace: Center(
            child: Row(
              children: [
                SizedBox(width: 18),
                AnimatedContainer(
                  duration: Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  width: 56,
                  height: 56,
                  child: Image.asset('../assets/logo.png'), // Replace with your logo
                ),
              ],
            ),
          ),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.exit_to_app),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            color: Colors.lightGreen,
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.deepOrange.shade800,
                    child: Text(
                      widget.studentName.substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    widget.studentName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.lightGreen.shade900,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Student Dashboard',
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 32),
                  // Classes
                  Container(
                    constraints: BoxConstraints(maxWidth: 600),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Classes',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.lime.shade900),
                                ),
                                SizedBox(height: 20),
                                if (_isLoading)
                                  CircularProgressIndicator()
                                else if (_classes.isEmpty)
                                  Text('You are not enrolled in any classes yet.'),
                                if (_classes.isNotEmpty)
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    itemCount: _classes.length,
                                    itemBuilder: (context, index) {
                                      final classItem = _classes[index];
                                      return Card(
                                        margin: EdgeInsets.symmetric(vertical: 8),
                                        color: Colors.white,
                                        elevation: 8,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                                          title: Text(classItem['class_name'], style: TextStyle(fontSize: 18, color: Colors.lightGreen.shade800, fontWeight: FontWeight.bold)),
                                          subtitle: Text('Teacher: ${classItem['teacher_name']}', style: TextStyle(color: Colors.lightGreen)),
                                          onTap: () { 
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => StudentClassPage(studentId: widget.studentId, studentName: widget.studentName, classId: classItem['class_id'], className: classItem['class_name']))
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ],
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: Icon(Icons.add),
                                onPressed: () => _enrollmentDialog(context),
                                tooltip: 'Add a Class',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  //History
                  Container(
                    constraints: BoxConstraints(maxWidth: 600),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Performance History',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.lime.shade900),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => StudentHistoryPage(studentId: widget.studentId, studentName: widget.studentName)),
                                );
                              },
                              child: Text('View Past Quizzes', style: TextStyle(fontSize: 16, color: Colors.lime.shade900)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lime,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
