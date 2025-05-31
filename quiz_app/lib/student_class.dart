import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/quiz_module.dart';

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
  String _errorMessage = '';
  List<dynamic> _quizzes = [];
  String _search = '';
  String _filterStatus = 'all'; // all, open, closed

  @override
  void initState() {
    super.initState();
    _fetchStudentQuizzes();
  }

  Future<void> _fetchStudentQuizzes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final quizzesRes = await Supabase.instance.client
          .from('student_quizzes')
          .select()
          .eq('student_id', widget.studentId)
          .eq('class_id', widget.classId)
          .order('quiz_scheduled_at', ascending: false);

      setState(() {
        _quizzes = quizzesRes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load quizzes. Please try again.';
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredQuizzes {
    var filtered = _quizzes;
    if (_filterStatus == 'open') {
      filtered = filtered.where((q) => q['quiz_open'] == true).toList();
    } else if (_filterStatus == 'closed') {
      filtered = filtered.where((q) => q['quiz_open'] == false).toList();
    }
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

  Future<void> _showQuizDetails(dynamic quiz) async {
    final questions = await Supabase.instance.client
        .from('questions')
        .select()
        .eq('quiz_id', quiz['quiz_id']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(quiz['quiz_title'] ?? 'Quiz Details'),
          content: SizedBox(
            width: double.maxFinite,
            child: questions == null || questions.isEmpty
                ? Text('No questions found for this quiz.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      return ListTile(
                        title: Text(q['question_text']),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              child: Text('Close', style: TextStyle(color: Colors.blue.shade700)),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        );
      },
    );
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
        'No quizzes found.',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
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
        color: isOpen ? Colors.green[50] : Colors.grey[100],
        child: ListTile(
          leading: Icon(
            isOpen ? Icons.lock_open : Icons.lock_outline,
            color: isOpen ? Colors.green : Colors.redAccent,
            size: 32,
          ),
          title: Text(
            quiz['quiz_title'] ?? 'Untitled Quiz',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
              fontSize: 17,
            ),
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
                'Scheduled: ${quiz['quiz_scheduled_at'] ?? 'N/A'}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              Text(
                'Closes: ${quiz['quiz_closes_at'] ?? 'N/A'}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              Text(
                'Status: ${isOpen ? 'Open' : 'Closed'}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isOpen ? Colors.green : Colors.redAccent,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.info_outline, color: Colors.blue.shade700),
            tooltip: 'View Quiz Details',
            onPressed: () => _showQuizDetails(quiz),
          ),
          onTap: isOpen
              ? () async {
                  final hasTaken = await _hasStudentTakenQuiz(quiz['quiz_id']);
                  if (hasTaken) {
                    // Show dialog that the quiz has already been taken
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text('Quiz Already Taken'),
                          content: Text(
                            'You have already taken this quiz. You can review the questions below.',
                          ),
                          actions: [
                            TextButton(
                              child: Text('Close'),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    // Allow the student to take the quiz
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizModulePage(
                          studentId: widget.studentId,
                          quizId: quiz['quiz_id'],
                          quizTitle: quiz['quiz_title'],
                        ),
                      ),
                    );
                  }
                }
              : null,
        ),
      );
    }).toList(),
  );
}

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: SizedBox(
              width: 220,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search quizzes...',
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
          SizedBox(width: 12),
          DropdownButton<String>(
            value: _filterStatus,
            borderRadius: BorderRadius.circular(12),
            items: [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(value: 'closed', child: Text('Closed')),
            ],
            onChanged: (val) {
              setState(() {
                _filterStatus = val ?? 'all';
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
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
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Center(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Filter/Search Bar
                        Container(
                          constraints: BoxConstraints(maxWidth: 600),
                          child: Card(
                            elevation: 4,
                            margin: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            color: Colors.blue[50],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Text(
                                      widget.className,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                  _buildFilterBar(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Quiz List
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
                              child: _buildQuizList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}