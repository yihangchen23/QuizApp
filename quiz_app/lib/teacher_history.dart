import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/main.dart';
import 'package:intl/intl.dart';

class TeacherHistoryPage extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const TeacherHistoryPage({
    required this.teacherId,
    required this.teacherName,
    Key? key,
  }) : super(key: key);

  @override
  State<TeacherHistoryPage> createState() => _TeacherHistoryPageState();
}

class _TeacherHistoryPageState extends State<TeacherHistoryPage> {
  bool _isLoading = true;

  Map<String, dynamic> _classes = {}; //class name => class data
  List<dynamic> _quizzes = [];
  List<dynamic> _attemptsForClass = [];
  List<dynamic> _attemptsForQuiz = [];
  
  // Filters
  String? _selectedClass;
  String? _selectedQuiz;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    try {
      final classesRes = await Supabase.instance.client
        .from('classes')
        .select()
        .eq('teacher_id', widget.teacherId);
      setState(() {
        for (final classData in classesRes)
          _classes[classData['name']] = classData;
        _isLoading = false;  
      });
    } catch (e) {
      setState(() {
        QuizApp.errorSnackBar(context, 'Failed to fetch classes. Please try again.');
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchQuizzesForClass() async {
    String selectedClassId = _classes[_selectedClass]['id'];

    setState(() => _isLoading = true);
    try {
      print('Fetching quizzes for $selectedClassId');
      final quizzesRes = await Supabase.instance.client
        .from('quizzes')
        .select()
        .eq('class_id', selectedClassId ?? '');
      final attemptsRes = await Supabase.instance.client.rpc(
        'get_class_quiz_history',
        params: {'p_class_id': selectedClassId},
      );
      
      setState(() {
        _quizzes = quizzesRes;
        _attemptsForClass = attemptsRes;
        _isLoading = false;  
      });
    } catch (e) {
      setState(() {
        print(e);
        QuizApp.errorSnackBar(context, 'Failed to fetch quizzes. Please try again.');
        _isLoading = false;
      });
    }
  }

  List<dynamic> _filterAttempts() {
    List<dynamic> filtered = [];
    filtered = _attemptsForClass.where((a) =>
      a['quiz_title'] == _selectedQuiz
    ).toList();
    print(filtered);
    return filtered;
  }

  Widget _buildFilters() {
    return Container(
      constraints: BoxConstraints(maxWidth: 800),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find a Quiz',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.lime.shade900,
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedClass,
                      hint: Text('Select a Class'),
                      items: [
                        ..._classes.keys.map((c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedClass = value;
                          _selectedQuiz = null;
                          _fetchQuizzesForClass();
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Quiz',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedQuiz,
                      hint: Text('Select a Quiz'),
                      items: [
                        ..._quizzes.map((c) => DropdownMenuItem<String>(
                              value: c['title'],
                              child: Text(c['title']),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedQuiz = value;
                          _attemptsForQuiz = _filterAttempts();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ); //TO-DO filter by quizzes with flagged answers
  }

  Future<void> _updateAnswerScore(String answerId, double newScore, String teacherFeedback) async {
    if (answerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Cannot identify answer to update')),
      );
      return;
    }

    try {
      // Debug print to verify the values
      print('Updating answer $answerId with score: $newScore and feedback: $teacherFeedback');

      final response = await Supabase.instance.client
          .from('answers')
          .update({
            'ai_score': newScore,
            'ai_feedback': teacherFeedback,  // Fixed: Changed from ai_feedback to teacher_feedback
            'reviewed_by_teacher': true,
          })
          .eq('id', answerId)
          .select()  // Add select() to get the updated record
          .single();

      // Debug print to verify the update
      
      setState(() {
        print('Update response: $response');
        _fetchQuizzesForClass();
        _filterAttempts();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Score updated successfully')),
      );
    } catch (e) {
      print('Error updating score: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update score. Please try again.')),
      );
    }
  }

  // Modify the _buildQuizList() method to include override functionality:
  Widget _buildQuizList() {
    if (_attemptsForQuiz.isEmpty) {
      return Center(
        child: Text(
          '${(_selectedQuiz ?? '') == ''?'Select a quiz to view attempts':'No attempts found for selected quiz'}',
          style: TextStyle(color: Colors.lime.shade800, fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student Quiz Attempts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.lime.shade900,
          ),
        ),
        SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _attemptsForQuiz.length,
          itemBuilder: (context, index) {
            final attempt = _attemptsForQuiz[index];
            return Card(
              color: Colors.white,
              elevation: 8,
              child: Padding (
                padding: const EdgeInsets.all(10),
                child: ExpansionTile(
                  title: Text(attempt['student_name'], style: TextStyle(color: Colors.lightGreen.shade800, fontWeight: FontWeight.bold, fontSize: 18)),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Score: ${attempt['average_score']?.toStringAsFixed(1) ?? '0'}/10', style: TextStyle(color: attempt['average_score'] >= 7? Colors.lightGreen : Colors.red)),
                          Text('Completed ${DateFormat.yMMMMd().add_jm().format(DateTime.parse(attempt['completed_at']).toLocal()) ?? 'N/A'}', style: TextStyle(color: Colors.black)),
                          Divider(),
                          ...((attempt['answers'] ?? []) as List).map((answer) => 
                            ListTile(
                              title: Text(answer['question_text'] ?? 'No question text', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Student Answer: ${answer['student_response'] ?? 'No response'}'),
                                  Text(
                                    'AI Score: ${answer['ai_score']?.toString() ?? '0'}/10',
                                    style: TextStyle(
                                      color: (answer['ai_score'] ?? 0) >= 7 
                                          ? Colors.lightGreen
                                          : Colors.red,
                                    ),
                                  ),
                                  Text('AI Feedback: ${answer['ai_feedback'] ?? 'No feedback'}'),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: Colors.lime.shade700,
                                ),
                                onPressed: () => _showOverrideDialog(answer),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showOverrideDialog(Map<String, dynamic> answer) {
    final scoreController = TextEditingController(
      text: answer['teacher_override_score']?.toString() ?? 
           answer['ai_score']?.toString() ?? '0'
    );
    final feedbackController = TextEditingController(
      text: answer['teacher_feedback'] ?? answer['ai_feedback'] ?? ''
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Override Score'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreController,
              decoration: InputDecoration(
                labelText: 'Score (0-10)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              decoration: InputDecoration(
                labelText: 'Teacher Feedback',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Save'),
            onPressed: () {
              final score = double.tryParse(scoreController.text);
              if (score != null && score >= 0 && score <= 10) {
                _updateAnswerScore(
                  answer['id'],
                  score,
                  feedbackController.text,
                );

                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  // Add export buttons to the AppBar
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _classes = {};
              _quizzes = [];
              _attemptsForClass = [];
              _attemptsForQuiz = [];
              _selectedClass = null;
              _selectedQuiz = null;
              _fetchClasses();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 750,
                  child: Card(
                    color: Colors.lightGreen,
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24),
                      child: Column(
                        children: [
                          Text('Performance Records', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 30)),
                            SizedBox(height: 24),
                          _buildFilters(),
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: _buildQuizList(),
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