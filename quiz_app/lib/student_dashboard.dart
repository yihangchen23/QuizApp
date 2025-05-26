import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/login.dart';
import 'package:quiz_app/student_class.dart';
import 'package:quiz_app/student_history.dart';

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
  String _errorMessage = '';
  final _enrollClassIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
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
        _errorMessage = 'Error fetching classes.';
        print('Error: $e');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _enrollInClass() async {
    final classId = _enrollClassIdController.text.trim();
    if (classId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a class ID.';
      });
      return;
    }

    try {
      await Supabase.instance.client.from('enrollments').insert([
        {'student_id': widget.studentId, 'class_id': classId}
      ]);
      _enrollClassIdController.clear();
      _fetchClasses();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to enroll. Ensure class ID is valid.';
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
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Container(
                  constraints: BoxConstraints(maxWidth: 600),
                  child: Card(
                    elevation: 8,
                    margin: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Welcome, ${widget.studentName}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Here are your current classes.',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Classes
                Container(
                  constraints: BoxConstraints(maxWidth: 600),
                  child: Card(
                    elevation: 8,
                    margin: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Your Classes',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                          SizedBox(height: 20),
                          if (_isLoading)
                            CircularProgressIndicator()
                          else if (_errorMessage.isNotEmpty)
                            Text(_errorMessage, style: TextStyle(color: Colors.red))
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
                                  color: Colors.blue[100],
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                                    title: Text(classItem['class_name'], style: TextStyle(fontSize: 18)),
                                    subtitle: Text('Teacher: ${classItem['teacher_name']}'),
                                    onTap: () { 
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => StudentClassPage(studentId: widget.studentId, studentName: widget.studentName, classId: classItem['class_id'],))
                                      );
                                    },
                                  ),
                                );
                              },
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
                    elevation: 8,
                    margin: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Your History',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => StudentHistoryPage(studentId: widget.studentId, studentName: widget.studentName)),
                              );
                            },
                            child: Text('View History', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Enroll in Class
                Container(
                  constraints: BoxConstraints(maxWidth: 600),
                  child: Card(
                    elevation: 8,
                    margin: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Enroll in a Class',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          SizedBox(height: 20),
                          TextField(
                            controller: _enrollClassIdController,
                            decoration: InputDecoration(
                              labelText: 'Class ID',
                              prefixIcon: Icon(Icons.class_),
                            ),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _enrollInClass,
                            child: Text('Enroll', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
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
    );
  }
}
