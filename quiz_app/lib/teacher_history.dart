import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

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
  String _errorMessage = '';
  List<dynamic> _classes = [];
  Map<String, List<dynamic>> _quizzesByClass = {};
  Map<String, List<dynamic>> _studentsByClass = {};
  Map<String, Map<String, double>> _studentAverages = {};
  
  // Filters
  String? _selectedClass;
  String? _selectedStudent;
  String _scoreFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchTeacherHistory();
  }

  Future<void> _fetchTeacherHistory() async {
    setState(() => _isLoading = true);
    try {
      // Fetch classes
      final classesRes = await Supabase.instance.client
          .from('classes')
          .select()
          .eq('teacher_id', widget.teacherId);
      _classes = classesRes;

      // For each class, fetch students and quizzes
      for (final classData in _classes) {
        final String classId = classData['id'];
        final String className = classData['name'];

        // Fetch students in this class
        final studentsRes = await Supabase.instance.client
            .from('student_class_enrollments')
            .select()
            .eq('class_id', classId);
        _studentsByClass[className] = studentsRes;

        // Fetch quiz attempts and results
        final quizzesRes = await Supabase.instance.client.rpc(
          'get_class_quiz_history',
          params: {'p_class_id': classId},
        );
        _quizzesByClass[className] = quizzesRes ?? [];

        // Calculate student averages
        _studentAverages[className] = {};
        for (final student in studentsRes) {
          final studentAttempts = quizzesRes.where(
            (q) => q['student_id'] == student['student_id'],
          ).toList();
          
          if (studentAttempts.isNotEmpty) {
            double total = 0;
            int count = 0;
            for (final attempt in studentAttempts) {
              if (attempt['average_score'] != null) {
                total += attempt['average_score'];
                count++;
              }
            }
            _studentAverages[className]![student['student_name']] = 
                count > 0 ? total / count : 0;
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load history: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildFilters() {
    return Container(
      constraints: BoxConstraints(maxWidth: 800),
      child: Card(
        elevation: 4,
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Search students or quizzes',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedClass,
                      items: [
                        DropdownMenuItem<String>(value: null, child: Text('All Classes')),
                        ..._classes.map((c) => DropdownMenuItem<String>(
                              value: c['name'],
                              child: Text(c['name']),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedClass = value;
                          _selectedStudent = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Student',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedStudent,
                      items: [
                        DropdownMenuItem<String>(value: null, child: Text('All Students')),
                        ...(_selectedClass != null
                            ? _studentsByClass[_selectedClass]!
                                .map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(
                                      value: s['student_name'],
                                      child: Text(s['student_name']),
                                    ))
                                .toList()
                            : []),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedStudent = value);
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
                        DropdownMenuItem(value: 'high', child: Text('High (≥7)')),
                        DropdownMenuItem(value: 'low', child: Text('Low (<7)')),
                      ],
                      onChanged: (value) {
                        setState(() => _scoreFilter = value!);
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

  Widget _buildClassPerformanceChart() {
    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 10,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= _classes.length) return const Text('');
                  return RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      _classes[value.toInt()]['name'],
                      style: TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: _classes.asMap().entries.map((entry) {
            final className = entry.value['name'];
            final averages = _studentAverages[className] ?? {};
            final classAverage = averages.isEmpty
                ? 0.0
                : averages.values.reduce((a, b) => a + b) / averages.length;
            
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: classAverage,
                  color: Colors.blue,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  List<dynamic> _getFilteredQuizzes() {
    List<dynamic> filtered = [];
    
    if (_selectedClass != null) {
      filtered = _quizzesByClass[_selectedClass]!;
    } else {
      _quizzesByClass.values.forEach(filtered.addAll);
    }

    if (_selectedStudent != null) {
      filtered = filtered.where((q) => 
        q['student_name'] == _selectedStudent
      ).toList();
    }

    if (_scoreFilter != 'all') {
      filtered = filtered.where((q) {
        final score = q['average_score'] ?? 0;
        return _scoreFilter == 'high' ? score >= 7 : score < 7;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((q) =>
        q['student_name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
        q['quiz_title'].toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return filtered;
  }

  Future<void> _updateAnswerScore(String answerId, double newScore, String teacherFeedback) async {
    try {
      await Supabase.instance.client.from('answers').update({
        'teacher_override_score': newScore,
        'ai_feedback': teacherFeedback,
        'reviewed_by_teacher': true, 
      }).eq('id', answerId);
      
      await _fetchTeacherHistory(); // Refresh data
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Score updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update score: $e')),
      );
    }
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    final filtered = _getFilteredQuizzes();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Quiz History Report')),
          pw.Header(level: 1, child: pw.Text('Generated on: ${DateTime.now()}')),
          ...filtered.map((quiz) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 2, child: pw.Text(quiz['quiz_title'])),
              pw.Text('Student: ${quiz['student_name']}'),
              pw.Text('Class: ${quiz['class_name']}'),
              pw.Text('Score: ${quiz['average_score']?.toStringAsFixed(1) ?? 'N/A'}/10'),
              ...((quiz['answers'] ?? []) as List).map((answer) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Question: ${answer['question_text']}'),
                  pw.Text('Answer: ${answer['student_response']}'),
                  pw.Text('AI Score: ${answer['ai_score']?.toStringAsFixed(1) ?? 'N/A'}/10'),
                  if (answer['teacher_override_score'] != null)
                    pw.Text('Teacher Score: ${answer['teacher_override_score']?.toStringAsFixed(1)}/10'),
                  pw.Text('AI Feedback: ${answer['ai_feedback']}'),
                  if (answer['teacher_feedback'] != null)
                    pw.Text('Teacher Feedback: ${answer['teacher_feedback']}'),
                ],
              )),
              pw.Divider(),
            ],
          )),
        ],
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/quiz_history.pdf');
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF saved to: ${file.path}')),
    );
  }

  Future<void> _exportToCSV() async {
    final filtered = _getFilteredQuizzes();
    final List<List<dynamic>> rows = [
      // Header
      ['Quiz Title', 'Student Name', 'Class', 'Score', 'Question', 'Answer', 
       'AI Score', 'Teacher Score', 'AI Feedback', 'Teacher Feedback'],
    ];

    // Data rows
    for (final quiz in filtered) {
      for (final answer in (quiz['answers'] ?? [])) {
        rows.add([
          quiz['quiz_title'],
          quiz['student_name'],
          quiz['class_name'],
          quiz['average_score']?.toStringAsFixed(1) ?? 'N/A',
          answer['question_text'],
          answer['student_response'],
          answer['ai_score']?.toStringAsFixed(1) ?? 'N/A',
          answer['teacher_override_score']?.toStringAsFixed(1) ?? '',
          answer['ai_feedback'],
          answer['teacher_feedback'] ?? '',
        ]);
      }
    }

    final csv = const ListToCsvConverter().convert(rows);
    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/quiz_history.csv');
    await file.writeAsString(csv);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV saved to: ${file.path}')),
    );
  }

  // Modify the _buildQuizList() method to include override functionality:
  Widget _buildQuizList() {
    final filtered = _getFilteredQuizzes();
    
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No quizzes match the selected filters.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final quiz = filtered[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ExpansionTile(
            title: Text(quiz['quiz_title']),
            subtitle: Text(
              'Student: ${quiz['student_name']} | ' 
              'Score: ${quiz['average_score']?.toStringAsFixed(1) ?? 'N/A'}/10',
            ),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class: ${quiz['class_name']}'),
                    Text('Completed: ${quiz['completed_at']}'),
                    Divider(),
                    ...((quiz['answers'] ?? []) as List).map((answer) => 
                      ListTile(
                        title: Text(answer['question_text']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Answer: ${answer['student_response']}'),
                            Text(
                              'Score: ${answer['ai_score']?.toStringAsFixed(1) ?? 'N/A'}/10',
                              style: TextStyle(
                                color: (answer['ai_score'] ?? 0) >= 7 
                                    ? Colors.green 
                                    : Colors.red,
                              ),
                            ),
                            Text('Feedback: ${answer['ai_feedback']}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => _showOverrideDialog(answer),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
        title: Text('Teacher History'),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: _exportToPDF,
            tooltip: 'Export to PDF',
          ),
          IconButton(
            icon: Icon(Icons.table_chart),
            onPressed: _exportToCSV,
            tooltip: 'Export to CSV',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchTeacherHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                  ),
                )
              : SingleChildScrollView(
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          constraints: BoxConstraints(maxWidth: 800),
                          child: Card(
                            margin: EdgeInsets.all(16),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Class Performance Overview',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(color: Colors.blue.shade900),
                                  ),
                                  _buildClassPerformanceChart(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _buildFilters(),
                        _buildQuizList(),
                      ],
                    ),
                  ),
                ),
    );
  }
}