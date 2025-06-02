import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/main.dart';

class TeacherClassPage extends StatefulWidget {
  final String classId;
  final String teacherId;

  const TeacherClassPage({
    required this.classId,
    required this.teacherId,
    Key? key,
  }) : super(key: key);

  @override
  State<TeacherClassPage> createState() => _TeacherClassPageState();
}

class _TeacherClassPageState extends State<TeacherClassPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _classInfo;
  List<dynamic> _students = [];
  List<dynamic> _quizzes = [];

  // --- Quiz Creation Controllers ---
  final _quizTitleController = TextEditingController();
  final _quizDescController = TextEditingController();
  final _quizCloseController = TextEditingController();
  final _quizScheduleController = TextEditingController();
  bool _isQuizOpen = false;

  // --- Questions inside quiz creation ---
  final List<_QuizQuestion> _newQuestions = [];

  // --- UI state ---
  bool _isCreatingQuiz = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final classRes = await Supabase.instance.client
          .from('classes')
          .select()
          .eq('id', widget.classId)
          .single();

      final studentsRes = await Supabase.instance.client
          .from('student_class_enrollments')
          .select()
          .eq('class_id', widget.classId);

      final quizzesRes = await Supabase.instance.client
          .from('quizzes')
          .select()
          .eq('class_id', widget.classId)
          .order('created_at', ascending: false);

      setState(() {
        _classInfo = classRes;
        _students = studentsRes;
        _quizzes = quizzesRes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        QuizApp.errorSnackBar(context, 'Failed to load class data. Please try again.');
        _isLoading = false;
      });
    }
  }

  // --- Add question to the quiz being created (locally) ---
  void _addNewQuestion() {
    setState(() {
      _newQuestions.add(_QuizQuestion());
    });
  }

  void _removeNewQuestion(int index) {
    setState(() {
      if (index >= 0 && index < _newQuestions.length) {
        _newQuestions.removeAt(index);
      }
    });
  }

  // --- Validate the quiz + questions form ---
  bool _validateQuizAndQuestions() {
    if (_quizTitleController.text.trim().isEmpty) {
      QuizApp.errorSnackBar(context, 'Quiz title is required.');
      return false;
    }

    if (_newQuestions.isEmpty) {
      QuizApp.errorSnackBar(context, 'Please add at least one question.');
      return false;
    }

    for (var i = 0; i < _newQuestions.length; i++) {
      final q = _newQuestions[i];
      if (q.questionController.text.trim().isEmpty) {
        QuizApp.errorSnackBar(context, 'Question ${i + 1} text is required.');
        return false;
      }
      if (q.pointsController.text.trim().isNotEmpty) {
        final points = double.tryParse(q.pointsController.text.trim());
        if (points == null || points <= 0) {
          QuizApp.errorSnackBar(context, 'Question ${i + 1} points must be a positive number.');
          return false;
        }
      }
    }

    return true;
  }

  Future<void> _submitQuizWithQuestions() async {
    if (!_validateQuizAndQuestions()) return;

    setState(() {
      _isCreatingQuiz = true;
    });

    try {
      final quizData = {
        'title': _quizTitleController.text.trim(),
        'description': _quizDescController.text.trim().isEmpty
            ? null
            : _quizDescController.text.trim(),
        'class_id': widget.classId,
        'teacher_id': widget.teacherId,
        'is_open': _isQuizOpen,
        'scheduled_at': _quizScheduleController.text.trim().isEmpty
            ? null
            : _quizScheduleController.text.trim(),
        'closes_at': _quizCloseController.text.trim().isEmpty
            ? null
            : _quizCloseController.text.trim(),
      };

      final quizInsertRes = await Supabase.instance.client
          .from('quizzes')
          .insert([quizData])
          .select()
          .single();

      if (quizInsertRes == null || quizInsertRes['id'] == null) {
        throw Exception('Failed to create quiz');
      }

      final quizId = quizInsertRes['id'];

      // Insert all questions for this quiz
      final questionsData = _newQuestions.map((q) {
        return {
          'question_text': q.questionController.text.trim(),
          'expected_answer': q.answerController.text.trim(),
          'expected_keywords': q.keywordsController.text.trim().isEmpty
              ? null
              : q.keywordsController.text.trim(),
          'quiz_id': quizId,
          'points': double.tryParse(q.pointsController.text.trim()) ?? 1,
        };
      }).toList();

      await Supabase.instance.client.from('questions').insert(questionsData);

      // Reset form & refresh data
      _quizTitleController.clear();
      _quizDescController.clear();
      _quizCloseController.clear();
      _quizScheduleController.clear();
      _isQuizOpen = false;
      _newQuestions.clear();

      await _fetchAll();

      setState(() {
        _isCreatingQuiz = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quiz and questions created successfully!')),
      );
    } catch (e) {
      setState(() {
        _isCreatingQuiz = false;
        QuizApp.errorSnackBar(context, 'Failed to create quiz. Please try again.');
        print(e);
      });
    }
  }

  // --- Other UI building helpers from previous version (slightly trimmed for brevity) ---

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.lime.shade900,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }

  Widget _buildEnrollmentCode() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                'Class Code: ${widget.classId}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.lime.shade700),
              ),
            ),
            IconButton(
              icon: Icon(Icons.copy, color: Colors.lime.shade700),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.classId));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Class code copied!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    if (_students.isEmpty) {
      return Center(
        child: Text(
          'No students enrolled in this class.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      );
    }
    return Column(
      children: _students.map((student) {
        return Card(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.lime.shade700,
              child: Text(
                (student['student_name'] as String).substring(0, 1).toUpperCase(),
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              student['student_name'],
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Text('ID: ${student['student_id']}'),
            trailing: IconButton(
              icon: Icon(Icons.remove_circle, color: Colors.redAccent, size: 28),
              tooltip: 'Remove from class',
              onPressed: () async {
                try {
                  await Supabase.instance.client
                      .from('student_class_enrollments')
                      .delete()
                      .eq('id', student['enrollment_id']);
                  await _fetchAll();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Student removed from class.')),
                  );
                } catch (e) {
                  QuizApp.errorSnackBar(context, 'Failed to remove student.');
                }
              },
              splashRadius: 24,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuizList() {
    if (_quizzes.isEmpty) {
      return Text(
        'No quizzes created yet.',
        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
      );
    }
    return Column(
      children: _quizzes.map((quiz) {
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
            title: Text(
              quiz['title'] ?? 'Untitled Quiz',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.lime.shade900),
            ),
            subtitle: Text(quiz['description'] ?? ''),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Scheduled At: ${quiz['scheduled_at'] ?? 'Not scheduled'}\n'
                  'Closes At: ${quiz['closes_at'] ?? 'No closing date'}\n'
                  'Status: ${quiz['is_open'] == true ? 'Open' : 'Closed'}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showQuizQuestions(quiz['id']),
                icon: Icon(Icons.question_answer, color: Colors.lime.shade700),
                label: Text('View Questions'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showQuizQuestions(dynamic quizId) async {
    final questions = await Supabase.instance.client
        .from('questions')
        .select()
        .eq('quiz_id', quizId);

    if (questions == null || questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No questions found for this quiz.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Quiz Questions'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final q = questions[index];
                return ListTile(
                  title: Text(q['question_text']),
                  subtitle: Text(
                    'Expected Answer: ${q['expected_answer']}\n'
                    'Keywords: ${q['expected_keywords'] ?? 'None'}\n'
                    'Points: ${q['points'] ?? 1}',
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('Close', style: TextStyle(color: Colors.lime.shade700)),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        );
      },
    );
  }

  // --- UI Widget for questions inside the quiz creation form ---
  Widget _buildQuestionForm(int index) {
    final question = _newQuestions[index];
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Question ${index + 1}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.lime.shade800),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => _removeNewQuestion(index),
                  icon: Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Remove this question',
                  splashRadius: 22,
                ),
              ],
            ),
            SizedBox(height: 8),
            TextField(
              controller: question.questionController,
              decoration: InputDecoration(
                labelText: 'Question Text',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.question_mark, color: Colors.lime.shade700),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 10),
            TextField(
              controller: question.answerController,
              decoration: InputDecoration(
                labelText: 'Expected Answer (optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.check_circle, color: Colors.lime.shade700),
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateQuizAndQuestionsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.symmetric(vertical: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Quiz',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.lime.shade900,
                  ),
            ),
            SizedBox(height: 18),

            // Quiz title
            TextField(
              controller: _quizTitleController,
              decoration: InputDecoration(
                labelText: 'Quiz Title',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.title, color: Colors.lime.shade700),
              ),
            ),
            SizedBox(height: 14),

            // Quiz description
            TextField(
              controller: _quizDescController,
              decoration: InputDecoration(
                labelText: 'Quiz Description (optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.description, color: Colors.lime.shade700),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 14),

            // Close datetime
            TextField(
              controller: _quizCloseController,
              decoration: InputDecoration(
                labelText: 'Due Date (optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.timer_off, color: Colors.orange.shade700),
                hintText: 'YYYY-MM-DDTHH:mm:ss',
              ),
            ),
            SizedBox(height: 14),

            // Is open switch
            SwitchListTile.adaptive(
              title: Text('Is Quiz Open?'),
              value: _isQuizOpen,
              onChanged: (val) {
                setState(() {
                  _isQuizOpen = val;
                });
              },
              activeColor: Colors.lime.shade600,
            ),

            Divider(height: 30, thickness: 1.2),

            // Questions list (dynamic)
            if (_newQuestions.isEmpty)
              Text(
                'Add at least one question to this quiz.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),

            ..._newQuestions
                .asMap()
                .entries
                .map((entry) => _buildQuestionForm(entry.key))
                .toList(),

            SizedBox(height: 8),

            // Add question button
            Center(
              child: ElevatedButton.icon(
                onPressed: _addNewQuestion,
                icon: Icon(Icons.add_circle_outline),
                label: Text('Add Question'),
                style: ElevatedButton.styleFrom(
                  padding:
                      EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.lime.shade700,
                ),
              ),
            ),

            SizedBox(height: 22),

            Center(
              child: ElevatedButton.icon(
                onPressed: _isCreatingQuiz ? null : _submitQuizWithQuestions,
                icon: _isCreatingQuiz
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Icons.save_outlined),
                label: Text(_isCreatingQuiz ? 'Saving...' : 'Create Quiz'),
                style: ElevatedButton.styleFrom(
                  padding:
                      EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _quizTitleController.dispose();
    _quizDescController.dispose();
    _quizCloseController.dispose();
    _quizScheduleController.dispose();
    for (var q in _newQuestions) {
      q.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_classInfo != null ? 'Class: ${_classInfo!['name']}' : 'Loading...'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Enrollment Code Card
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
                          child: _buildEnrollmentCode(),
                        ),
                      ),
                    ),
                    // Students Card
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Students'),
                              _buildStudentList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Quizzes Card
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Quizzes'),
                              _buildQuizList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Create Quiz Card
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
                          child: _buildCreateQuizAndQuestionsSection(),
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

class _QuizQuestion {
  final TextEditingController questionController = TextEditingController();
  final TextEditingController answerController = TextEditingController();
  final TextEditingController keywordsController = TextEditingController();
  final TextEditingController pointsController = TextEditingController();

  void dispose() {
    questionController.dispose();
    answerController.dispose();
    keywordsController.dispose();
    pointsController.dispose();
  }
}
