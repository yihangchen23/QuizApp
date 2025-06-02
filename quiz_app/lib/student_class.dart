import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/quiz_module.dart';
import 'package:intl/intl.dart';
import 'package:quiz_app/main.dart';

class StudentClassPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String classId;
  final String className;

  const StudentClassPage({
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    Key? key,
  }) : super(key: key);

  @override
  State<StudentClassPage> createState() => _StudentClassPageState();
}

class _StudentClassPageState extends State<StudentClassPage> {
  bool _isLoading = true;
  List<dynamic> _quizzes = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchStudentQuizzes();
  }

  Future<void> _fetchStudentQuizzes() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final quizzesRes = await Supabase.instance.client
          .from('student_quizzes')
          .select()
          .eq('student_id', widget.studentId)
          .eq('class_id', widget.classId)
          .order('quiz_scheduled_at', ascending: false);

      List<dynamic> quizzesResFiltered = await _filterAvailableQuizzes(quizzesRes);
      setState(() {
        _quizzes = quizzesResFiltered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        QuizApp.errorSnackBar(context, 'Failed to load quizzes. Please refresh.');
        _isLoading = false;
      });
    }
  }

  Future<List<dynamic>> _filterAvailableQuizzes(List quizzesRes) async {
    List<dynamic> filtered = [];
    for (var q in quizzesRes) {
      bool open = (q['quiz_open'] == true);
      bool taken = await _hasStudentTakenQuiz(q['quiz_id']);
      if (open && !taken)
        filtered.add(q);
    }
    return filtered;
  }

  List<dynamic> get _filteredQuizzes {
    var filtered = _quizzes;
    filtered = filtered.where((q) => q['quiz_open'] == true).toList();
    if (_search.isNotEmpty) {
      filtered = filtered
          .where((q) =>
              (q['quiz_title'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_search.toLowerCase()) ||
              (q['quiz_description'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_search.toLowerCase()))
          .toList();
    }
    return filtered;
  }

  // Add a method to check if the student has already taken the quiz
Future<bool> _hasStudentTakenQuiz(String quizId) async {
  try {
    final result = await Supabase.instance.client
        .from('quiz_attempts')
        .select()
        .eq('student_id', widget.studentId)
        .eq('quiz_id', quizId)
        .single(); // Get the quiz record for this student and quiz ID
    return result != null;
  } catch (e) {
    // Handle error (e.g., network issue)
    return false;
  }
}

// Update onTap in _buildQuizList
Widget _buildQuizList() {
  if (_filteredQuizzes.isEmpty) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'No available quizzes',
        style: TextStyle(color: Colors.lime.shade700, fontSize: 16),
      ),
    );
  }
  return Column(
    children: _filteredQuizzes.map((quiz) {
      final isOpen = quiz['quiz_open'] == true;
      return Card(
        margin: EdgeInsets.symmetric(vertical: 8),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isOpen ? Colors.lime[50] : Colors.grey[100],
        child: ListTile(
          leading: Icon(
            isOpen ? Icons.lock_open : Icons.lock_outline,
            color: isOpen ? Colors.lightGreenAccent.shade700 : Colors.redAccent,
            size: 32,
          ),
          title: Text(
            quiz['quiz_title'] ?? 'Untitled Quiz',
            style: TextStyle(fontSize: 18, color: Colors.lightGreen.shade800, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((quiz['quiz_description'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                  child: Text(
                    quiz['quiz_description'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                ),
              Text(
                '${quiz['quiz_closes_at'] != null?
                  'Due ${DateFormat.yMMMMd().add_jm().format(DateTime.parse(quiz['quiz_closes_at']).toLocal())}'
                  : 'No due date'}',
                style: TextStyle(color: Colors.lightGreen),
              ),
              Text(
                '${isOpen ? 'Open' : 'Closed'}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isOpen ? Colors.lightGreenAccent.shade700 : Colors.redAccent,
                ),
              ),
            ],
          ),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuizModulePage(
                  studentId: widget.studentId,
                  quizId: quiz['quiz_id'],
                  quizTitle: quiz['quiz_title'],
                ),
              ),
            );
            if (result == 'completed')
              _fetchStudentQuizzes();
          },
        ),
      );
    }).toList(),
  );
}

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
      child: Flexible(
        child: SizedBox(
          width: 220,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search for a quiz',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              isDense: true,
            ),
            onChanged: (val) {
              setState(() {
                _search = val;
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchStudentQuizzes,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Card(
                  color: Colors.lightGreen,
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          widget.className,
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 30),
                        ),
                        SizedBox(height: 24),
                        // Filter/Search Bar
                        Container(
                          constraints: BoxConstraints(maxWidth: 600),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              child: _buildFilterBar(),
                            ),
                          ),
                        ),
                        // Quiz List
                        Container(
                          constraints: BoxConstraints(maxWidth: 600),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Available Quizzes',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.lime.shade900),
                                  ),
                                  SizedBox(height: 20),
                                  _buildQuizList(),
                                ],
                              )
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