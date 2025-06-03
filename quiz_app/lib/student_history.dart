import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:quiz_app/main.dart';

class StudentHistoryPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentHistoryPage({
    required this.studentId,
    required this.studentName,
    Key? key,
  }) : super(key: key);

  @override
  State<StudentHistoryPage> createState() => _StudentHistoryPageState();
}

class _StudentHistoryPageState extends State<StudentHistoryPage> {
  bool _isLoading = true;
  Map<String, List<dynamic>> _quizzesByClass = {};
  List<dynamic> _classes = [];
  Map<String, double> _averageScoresByClass = {};
  List<double> _recentScores = [];
  String? _selectedClass;
  String _scoreFilter = 'all'; // 'all', 'high', 'low'

  @override
  void initState() {
    super.initState();
    _fetchStudentHistory();
  }

  Future<void> _fetchStudentHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all classes the student is enrolled in
      final classesRes = await Supabase.instance.client
          .from('student_class_enrollments')
          .select()
          .eq('student_id', widget.studentId);
      _classes = classesRes;

      // For each class, fetch quiz attempts and answers
      for (final classData in _classes) {
        final quizzesRes = await Supabase.instance.client.rpc(
          'get_student_quiz_history',
          params: {
            'p_student_id': widget.studentId,
            'p_class_id': classData['class_id'],
          },
        );

        _quizzesByClass[classData['class_name']] = quizzesRes;

        // Calculate average score for this class
        if (quizzesRes.isNotEmpty) {
          double totalScore = 0;
          int count = 0;
          for (final quiz in quizzesRes) {
            if (quiz['average_score'] != null) {
              totalScore += quiz['average_score'];
              count++;
            }
          }
          _averageScoresByClass[classData['class_name']] = 
              count > 0 ? totalScore / count : 0;
        }
      }

      // Get recent scores for trend chart
      final recentScores = await Supabase.instance.client
          .from('answers')
          .select('ai_score')
          .eq('student_id', widget.studentId)
          .order('answered_at', ascending: true)
          .limit(10);

      _recentScores = recentScores
          .map((score) => (score['ai_score'] ?? 0).toDouble())
          .toList()
          .cast<double>();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        QuizApp.errorSnackBar(context, 'Failed to load history. Please try again.');
        _isLoading = false;
      });
    }
  }

  Widget _buildClassSection(String className, List<dynamic> quizzes) {
    return Container(
      constraints: BoxConstraints(maxWidth: 600),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: ExpansionTile(
            title: Text(
              className,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.lime.shade900),
            ),
            children: quizzes.map((quiz) {
              return Card(
                margin: EdgeInsets.symmetric(vertical: 12),
                color: Colors.white,
                elevation: 8,
                child: ListTile(
                  title: Text(quiz['quiz_title'] ?? 'Untitled Quiz', style: TextStyle(fontSize: 18, color: Colors.lightGreen.shade800, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quiz Score: ${quiz['average_score']?.toStringAsFixed(2) ?? 'N/A'}', style: TextStyle(color: Colors.lightGreen)),
                      Text('Completed ${DateFormat.yMMMMd().add_jm().format(DateTime.parse(quiz['completed_at']).toLocal()) ?? 'N/A'}', style: TextStyle(color: Colors.lightGreen)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.visibility),
                    tooltip: 'View Your Answers',
                    onPressed: () => _showQuizDetails(quiz),
                  ),
                ),
              );
            }).toList(),  
          ),
        ),
      ),
    );
  }

  void _showQuizDetails(dynamic quiz) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(quiz['quiz_title'] ?? 'Quiz Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Score: ${quiz['average_score']?.toStringAsFixed(2) ?? 'N/A'}/10'),
              Divider(),
              if (quiz['answers'] != null) ...[
                ...quiz['answers'].map((answer) => Card(
                      color: Colors.white,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Q: ${answer['question_text']}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text('Your Answer: ${answer['student_response']}'),
                            Text(
                              'Score: ${answer['ai_score']?.toString() ?? 'N/A'}/10',
                              style: TextStyle(
                                color: (answer['ai_score'] ?? 0) >= 7
                                    ? Colors.lightGreen
                                    : Colors.red,
                              ),
                            ),
                            Text('Feedback: ${answer['ai_feedback'] ?? 'N/A'}'),
                          ],
                        ),
                      ),
                    ))
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      constraints: BoxConstraints(maxWidth: 600),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.lime.shade900,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Class',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedClass,
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text('All Classes'),
                        ),
                        ..._quizzesByClass.keys.map((className) {
                          return DropdownMenuItem(
                            value: className,
                            child: Text(className),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedClass = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Score Filter',
                        border: OutlineInputBorder(),
                      ),
                      value: _scoreFilter,
                      items: [
                        DropdownMenuItem(value: 'all', child: Text('All Scores')),
                        DropdownMenuItem(value: 'high', child: Text('High Scores (≥7)')),
                        DropdownMenuItem(value: 'low', child: Text('Low Scores (<7)')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _scoreFilter = value ?? 'all';
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter quizzes based on selection
    var filteredQuizzesByClass = Map<String, List<dynamic>>.from(_quizzesByClass);
    
    if (_selectedClass != null) {
      filteredQuizzesByClass = {
        _selectedClass!: _quizzesByClass[_selectedClass!] ?? [],
      };
    }

    // Apply score filter
    filteredQuizzesByClass.forEach((className, quizzes) {
      if (_scoreFilter != 'all') {
        filteredQuizzesByClass[className] = quizzes.where((quiz) {
          final score = quiz['average_score'] ?? 0;
          return _scoreFilter == 'high' ? score >= 7 : score < 7;
        }).toList();
      }
    });

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchStudentHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24),
                  child: Card(
                    color: Colors.lightGreen,
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24),
                      child: Column(
                        children: [
                          Text('Quiz History', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 30)),
                          SizedBox(height: 24),
                          _buildFilters(), // Add filters section
                          ...filteredQuizzesByClass.entries
                              .where((entry) => entry.value.isNotEmpty)
                              .map(
                                (entry) => _buildClassSection(entry.key, entry.value),
                              ),
                          if (filteredQuizzesByClass.values.every((v) => v.isEmpty))
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No quizzes match the selected filters',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
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