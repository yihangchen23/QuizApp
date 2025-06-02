import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiz_app/main.dart';

class QuizModulePage extends StatefulWidget {
  final String studentId;
  final String quizId;
  final String quizTitle;

  const QuizModulePage({
    required this.studentId,
    required this.quizId,
    required this.quizTitle,
    Key? key,
  }) : super(key: key);

  @override
  State<QuizModulePage> createState() => _QuizModulePageState();
}

class _QuizModulePageState extends State<QuizModulePage> {
  bool _isLoading = true;
  List<dynamic> _questions = [];
  Map<String, TextEditingController> _answerControllers = {};
  bool _submitting = false;
  Map<String, dynamic> _aiResults = {}; // questionId -> {score, feedback}

  @override
  void initState() {
    super.initState();
    _fetchQuizQuestions();
  }

  Future<void> _fetchQuizQuestions() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final questionsRes = await Supabase.instance.client
          .from('questions')
          .select()
          .eq('quiz_id', widget.quizId)
          .order('created_at', ascending: true);

      setState(() {
        _questions = questionsRes;
        for (var q in _questions) {
          _answerControllers[q['id']] = TextEditingController();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        QuizApp.errorSnackBar(context, 'Failed to load quiz questions.');
        _isLoading = false;
      });
    }
  }

  Future<void> _submitQuiz() async {
    setState(() {
      _submitting = true;
    });

    // 1. Create quiz_attempt
    final attemptRes = await Supabase.instance.client.from('quiz_attempts').insert([
      {
        'student_id': widget.studentId,
        'quiz_id': widget.quizId,
        'started_at': DateTime.now().toIso8601String(),
        'completed_at': DateTime.now().toIso8601String(),
      }
    ]).select().single();

    if (attemptRes == null || attemptRes['id'] == null) {
      setState(() {
        QuizApp.errorSnackBar(context, 'Failed to submit quiz.');
        _submitting = false;
      });
      return;
    }
    final attemptId = attemptRes['id'];

    // 2. For each question, submit answer and get AI grade
    for (final q in _questions) {
      final questionId = q['id'];
      final studentResponse = _answerControllers[questionId]?.text.trim() ?? '';
      if (studentResponse.isEmpty) continue;

      final aiResult = await _gradeWithAI(
        question: q['question_text'],
        expected: q['expected_answer'],
        studentResponse: studentResponse,
      );

      _aiResults[questionId] = aiResult;

      await Supabase.instance.client.from('answers').insert([
        {
          'student_id': widget.studentId,
          'quiz_attempt_id': attemptId,
          'question_id': questionId,
          'student_response': studentResponse,
          'ai_score': aiResult['score'],
          'ai_feedback': aiResult['feedback'],
          'flagged_for_review': aiResult['flagged'],
          'answered_at': DateTime.now().toIso8601String(),
        }
      ]);
    }

    setState(() {
      _submitting = false;
    });

    _showResultsDialog();
  }

  Future<Map<String, dynamic>> _gradeWithAI({
    required String question,
    required String expected,
    required String studentResponse,
  }) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer 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',
      'Content-Type': 'application/json',
      'HTTP-Referer': '<YOUR_SITE_URL>',
      'X-Title': '<YOUR_SITE_NAME>',
    };
    final prompt =
        'Please format your answer in one line in the format of ["your feedback for the student answer","your rating of the students answer between 0(Wrong Answer)-10(Right Answer with proper explanation"].... Question is "$question"... Expected Answer is "$expected"... Student Response is "$studentResponse"';

    try {
      final body = jsonEncode({
        'model': 'google/gemma-3n-e4b-it:free',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String content = data['choices'][0]['message']['content'];
        // Parse: ["feedback", "score"]
        final match = RegExp(r'\["(.+?)","?([0-9.]+)"?\]').firstMatch(content);
        if (match != null) {
          return {
            'feedback': match.group(1) ?? '',
            'score': double.tryParse(match.group(2) ?? '0') ?? 0,
            'flagged': false,
          };
        }
        return {'feedback': 'AI returned faulty formatting: $content', 'score': 0, 'flagged': true};
      } else {
        return {'feedback': 'AI grading failed.', 'score': 0, 'flagged': true};
      }
    } catch (e) {
      return {'feedback': 'AI error: $e', 'score': 0, 'flagged': true};
    }
  }

  void _showResultsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.lime[50],
        title: Text('Quiz Submitted!', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 350,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _questions.length,
            itemBuilder: (context, idx) {
              final q = _questions[idx];
              final ai = _aiResults[q['id']];
              return Card(
                color: Colors.white,
                child: ListTile(
                  title: Text(q['question_text']),
                  subtitle: ai == null
                      ? Text('Not answered.')
                      : Text(
                          'AI Score: ${ai['score']}/10\nFeedback: ${ai['feedback']}',
                          style: TextStyle(
                            color: (ai['score']) >= 7 ? Colors.lightGreen : Colors.red,
                          ),
                        ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text('Close', style: TextStyle(color: Colors.black)),
            onPressed: () {
              Navigator.of(context).pop(); //pop to quiz_module
              Navigator.of(context).pop('completed'); //pop to student_class
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var c in _answerControllers.values) {
      c.dispose();
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
              child: Container(
                constraints: BoxConstraints(maxWidth: 600),
                child: Card(
                  color: Colors.lightGreen,
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.quizTitle}',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 30),
                        ),
                        SizedBox(height: 18),
                        ..._questions.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final q = entry.value;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Q${idx + 1}: ${q['question_text']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.lime.shade900,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  TextField(
                                    controller: _answerControllers[q['id']],
                                    decoration: InputDecoration(
                                      labelText: 'Your Answer',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      prefixIcon: Icon(Icons.edit, color: Colors.lime.shade700),
                                    ),
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        SizedBox(height: 20),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : _submitQuiz,
                            icon: _submitting
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(Icons.send, color: Colors.lime.shade900),
                            label: Text(_submitting ? 'Submitting...' : 'Submit Quiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.lime.shade900),),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              backgroundColor: Colors.lime.shade500,
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