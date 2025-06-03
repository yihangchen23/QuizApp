import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/main.dart';
import 'package:intl/intl.dart';

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
  Map<String, bool> _isQuizOpenInList = {};

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

      _clearQuizForm();

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

  void _clearQuizForm() {
    _quizTitleController.clear();
    _quizDescController.clear();
    _quizCloseController.clear();
    _quizScheduleController.clear();
    _isQuizOpen = false;
    _newQuestions.clear();
  }

  // --- Other UI building helpers from previous version (slightly trimmed for brevity) ---

  Widget _sectionTitle(String text) {
    return Column(
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.lime.shade900,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
        ),
        SizedBox(height: 14),
      ],
    );
  }

  Widget _buildEnrollmentCode() {
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            'Class Code: ${widget.classId}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.lime.shade900),
          ),
        ),
        IconButton(
          icon: Icon(Icons.copy, color: Colors.lime.shade900),
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
    );
  }

  Widget _buildStudentList() {
    if (_students.isEmpty) {
      return Center(
        child: Text(
          'No students enrolled in this class.',
          style: TextStyle(color: Colors.lime.shade700, fontSize: 16),
        ),
      );
    }
    return Column(
      children: _students.map((student) {
        return Card(
          elevation: 8,
          color: Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepOrange.shade800,
              child: Text(
                (student['student_name'] as String).substring(0, 1).toUpperCase(),
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            title: Text(
              student['student_name'],
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.lightGreen.shade800),
            ),
            subtitle: Text(
              'ID: ${student['student_id']}',
              style: TextStyle(color: Colors.lightGreen)
            ),
            trailing: IconButton(
              icon: Icon(Icons.remove_circle, color: Colors.redAccent, size: 28),
              tooltip: 'Remove from class',
              onPressed: () async {
                try {
                  await Supabase.instance.client
                      .from('enrollments')
                      .delete()
                      .eq('student_id', student['student_id']);
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

  Future<void> _updateQuizStatus(String quizId, bool open) async {
    try {
      final response = await Supabase.instance.client
          .from('quizzes')
          .update({
            'is_open': open,
          })
          .eq('id', quizId)
          .select()
          .single();
    } catch (e) {
      print('Error opening/closing quiz: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change quiz status. Please try again.')),
      );
    }
  }

  Widget _buildQuizList() {
    if (_quizzes.isEmpty) {
      return Text(
        'No quizzes created yet.',
        style: TextStyle(fontSize: 16, color: Colors.lime.shade700),
      );
    }
    return Column(
      children: _quizzes.map((quiz) {
        bool quizOpen = _isQuizOpenInList.putIfAbsent(quiz['id'], () => quiz['is_open'] ?? false);
        
        return Card(
          color: Colors.white,
          elevation: 8,
          child: ExpansionTile(
            title: Text(
              quiz['title'] ?? 'Untitled Quiz',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.lightGreen.shade800),
            ),
            subtitle: Text(quiz['description'] ?? 'No Description', style: TextStyle(color: Colors.lightGreen)),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${(quiz['closes_at'] != null && quiz['closes_at'].trim() != '')?
                        'Due ${DateFormat.yMMMMd().add_jm().format(DateTime.parse(quiz['closes_at']).toLocal())}'
                        :'No due date'}',
                      style: TextStyle(color: Colors.black),
                    ),
                    Center(
                      child: Row (
                        children: [
                          Icon(
                            quizOpen ? Icons.lock_open : Icons.lock_outline,
                            color: quizOpen ? Colors.lightGreenAccent.shade700 : Colors.redAccent,
                            size: 24,
                          ),
                          // Is open switch
                          SizedBox(
                            width: 200,
                            child: SwitchListTile.adaptive(
                              title: Text(
                                quizOpen?'Open':'Closed',
                                style: TextStyle(
                                  color: quizOpen ? Colors.lightGreenAccent.shade700 : Colors.redAccent,
                                ),
                              ),
                              value: _isQuizOpenInList[quiz['id']] ?? false,
                              onChanged: (val) {
                                setState(() {
                                  _isQuizOpenInList[quiz['id']] = val;
                                  _updateQuizStatus(quiz['id'], val);
                                });
                              },
                              activeColor: Colors.lightGreenAccent.shade700,
                            ),
                          ),
                        ]
                      ),
                    ),
                    SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _showQuizQuestions(quiz['id']),
                      icon: Icon(Icons.question_answer, color: Colors.lime.shade700),
                      label: Text('View Questions', style: TextStyle(color: Colors.lime.shade700)),
                    ),
                  ],
                ),
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
                  subtitle:Text('${q['expected_answer'].trim() != ''?'Expected Answer: ${q['expected_answer']}':''}'),
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
  Widget _buildQuestionForm(int index, BuildContext context, void Function(void Function()) setLocalState) {
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
                  onPressed: () {
                    setLocalState(() {
                      if (index >= 0 && index < _newQuestions.length)
                        _newQuestions.removeAt(index);
                    });
                  },
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

  void _showQuizCreationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Create a New Quiz',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.lightGreen.shade800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 600,
                      child: Column(
                        children: [
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

                          // Close datetime -> SWITCH TO CALENDAR INPUT
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

                          StatefulBuilder(
                            builder: (BuildContext context, void Function(void Function()) setLocalState) {
                              return Row (
                                children: [
                                  Icon(
                                    _isQuizOpen ? Icons.lock_open : Icons.lock_outline,
                                    color: _isQuizOpen ? Colors.lightGreenAccent.shade700 : Colors.redAccent,
                                    size: 24,
                                  ),
                                  // Is open switch
                                  SizedBox(
                                    width: 200,
                                    child: SwitchListTile.adaptive(
                                      title: Text(
                                        _isQuizOpen?'Open':'Closed',
                                        style: TextStyle(
                                          color: _isQuizOpen ? Colors.lightGreenAccent.shade700 : Colors.redAccent,
                                        ),
                                      ),
                                      value: _isQuizOpen,
                                      onChanged: (val) {
                                        setLocalState(() {
                                          _isQuizOpen = val;
                                        });
                                      },
                                      activeColor: Colors.lightGreenAccent.shade700,
                                    ),
                                  ),
                                ]
                              );
                            }
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                StatefulBuilder(
                  builder: (BuildContext context, void Function(void Function()) setLocalState) {
                    return Card(
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            if (_newQuestions.isEmpty)
                              Text(
                                'Add at least one question to this quiz.',
                                style: TextStyle(color: Colors.lime.shade700, fontSize: 14),
                              ),

                            ..._newQuestions
                                .asMap()
                                .entries
                                .map((entry) => _buildQuestionForm(entry.key, context, setLocalState))
                                .toList(),

                            SizedBox(height: 16),

                            // Add question button
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setLocalState(() {
                                    _newQuestions.add(_QuizQuestion());
                                    print(_newQuestions);
                                  });
                                },
                                icon: Icon(Icons.add_circle_outline, color: Colors.lime.shade900),
                                label: Text('Add Question', style: TextStyle(color: Colors.lime.shade900, fontSize: 16, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  backgroundColor: Colors.lime,
                                  elevation: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.lightGreen.shade700)),
              onPressed: () {
                _clearQuizForm();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (!_isCreatingQuiz) {
                  _submitQuizWithQuestions();
                  Navigator.of(context).pop();
                }
              },
              icon: _isCreatingQuiz
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.save_outlined, color: Colors.lightGreen.shade900),
              label: Text(_isCreatingQuiz ? 'Saving...' : 'Create Quiz', style: TextStyle(color: Colors.lightGreen.shade900)),
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
      appBar: AppBar(),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_classInfo!['name']}',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 30),
                        ),
                        SizedBox(height: 24),
                        // Enrollment Code Card
                        Container(
                          constraints: BoxConstraints(maxWidth: 600),
                          child: Card(
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
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Stack(
                                children: [
                                   Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _sectionTitle('Quizzes'),
                                      _buildQuizList(),
                                    ],
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: Icon(Icons.add),
                                      onPressed: () => _showQuizCreationDialog(context),
                                      tooltip: 'Create a new quiz',
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
