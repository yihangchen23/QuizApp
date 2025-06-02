import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/login.dart';
import 'package:quiz_app/teacher_class.dart';
import 'package:quiz_app/teacher_history.dart';
import 'package:quiz_app/main.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  TeacherDashboardScreen({required this.teacherId, required this.teacherName});

  @override
  _TeacherDashboardScreenState createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _classes = [];
  String _errorMessage = '';
  final _classNameController = TextEditingController();

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
          .from('classes')
          .select()
          .eq('teacher_id', widget.teacherId);

      if (response.isNotEmpty) {
        setState(() {
          _classes = response;
        });
      } else {
        setState(() {
          _errorMessage = 'You have no classes.';
        });
      }
    } catch (e) {
      setState(() {
        QuizApp.errorSnackBar(context, 'Failed to fetch classes. Please try again.');
      });
      print('Error fetching classes: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewClass() async {
    final className = _classNameController.text;

    if (className.isEmpty) {
      setState(() {
        QuizApp.errorSnackBar(context, 'Please enter a class name.');
      });
      return;
    }

    try {
      final response = await Supabase.instance.client.from('classes').insert([
        {
          'name': className,
          'teacher_id': widget.teacherId,
        }
      ]);

      if (response.error == null) {
        setState(() {
          _fetchClasses();
        });
      } else {
        setState(() {
          QuizApp.errorSnackBar(context, 'Failed to create class.');
        });
      }
    } catch (e) {
      setState(() {
        QuizApp.errorSnackBar(context, 'An error occurred. Please try again.');
      });
      print('Error creating class: $e');
    }
  }

  void _goToClassPage(String classId, String teacherId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherClassPage(classId: classId, teacherId: teacherId,),
      ),
    );
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
      appBar:  PreferredSize(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Teacher Header
                Container(
                  constraints: BoxConstraints(maxWidth: 600), // Constrained width
                  child: Card(
                    elevation: 8,
                    margin: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.lime[50], // Lighter lime background
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Welcome, ${widget.teacherName}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.limeAccent.shade400,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You can manage your classes below.',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Class List Section
                Container(
                  constraints: BoxConstraints(maxWidth: 600), // Constrained width
                  child: Card(
                    elevation: 8,
                    margin: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.lime[50], // Lighter lime background
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Your Classes',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.limeAccent.shade400),
                          ),
                          SizedBox(height: 20),
                          if (_isLoading)
                            Center(child: CircularProgressIndicator())
                          else if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          // Display the list of classes
                          if (_classes.isNotEmpty)
                            ListView.builder(
                              shrinkWrap: true, // Allow ListView to shrink to fit its children
                              itemCount: _classes.length,
                              itemBuilder: (context, index) {
                                final classItem = _classes[index];
                                return GestureDetector(
                                  onTap: () => _goToClassPage(classItem['id'], widget.teacherId),
                                  child: Card(
                                    elevation: 8,
                                    margin: EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    color: Colors.lime[100], // Lighter lime background
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                                      title: Text(
                                        classItem['name'],
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                      ),
                                      trailing: Icon(Icons.arrow_forward, color: Colors.black),
                                    ),
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
                    color: Colors.lime[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Your Classes\' History',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.limeAccent.shade400),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => TeacherHistoryPage(teacherId: widget.teacherId, teacherName: widget.teacherName)),
                              );
                            },
                            child: Text('View History', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.limeAccent.shade400,
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

                // Class Creation Card
                Container(
                  constraints: BoxConstraints(maxWidth: 600), // Constrained width
                  child: Card(
                    elevation: 8,
                    margin: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    color: Colors.lime[50], // Lighter lime background
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Create New Class',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.limeAccent.shade400,
                            ),
                          ),
                          SizedBox(height: 20),
                          TextField(
                            controller: _classNameController,
                            decoration: InputDecoration(
                              labelText: 'Class Name',
                              labelStyle: TextStyle(color: Colors.black),
                              prefixIcon: Icon(Icons.class_, color: Colors.black),
                            ),
                          ),
                          SizedBox(height: 20),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _createNewClass,
                            child: Text('Create', style: TextStyle(color: Colors.white),),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.limeAccent.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.0),
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

class ClassPage extends StatelessWidget {
  final int classId;

  ClassPage({required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Class $classId'),
      ),
      body: Center(
        child: Text('Details of class $classId will be here'),
      ),
    );
  }
}
