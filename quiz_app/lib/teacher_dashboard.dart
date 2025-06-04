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
      setState(() {
        _classNameController.clear();
        _fetchClasses();
      });
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

  void _classCreationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Create a New Class',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.lightGreen.shade800,
            ),
          ),
          content: Form(
            child: TextField(
              controller: _classNameController,
              decoration: InputDecoration(
                labelText: 'Class Name',
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
              child: Text('Create', style: TextStyle(color: Colors.lightGreen.shade900)),
              onPressed: () {
               _createNewClass();
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
                        widget.teacherName.substring(0, 1).toUpperCase(),
                        style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      widget.teacherName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.lightGreen.shade900,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Teacher Dashboard',
                      style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 32),                    
                    Container(
                      constraints: BoxConstraints(maxWidth: 600), // Constrained width
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Your Classes',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.lime.shade900),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add),
                                    onPressed: () => _classCreationDialog(context),
                                    tooltip: 'Create a new class',
                                  ),
                                ],
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
                                        margin: EdgeInsets.symmetric(vertical: 8),
                                        color: Colors.white,
                                        elevation: 8,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                                          title: Text(
                                            classItem['name'],
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.lightGreen.shade800),
                                          ),
                                          trailing: Icon(Icons.arrow_forward, color: Colors.lightGreen.shade800),
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
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'Your Classes\' History',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.lime.shade900),
                              ),
                              SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => TeacherHistoryPage(teacherId: widget.teacherId, teacherName: widget.teacherName)),
                                  );
                                },
                                child: Text('View History', style: TextStyle(color: Colors.lime.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.lime,
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
