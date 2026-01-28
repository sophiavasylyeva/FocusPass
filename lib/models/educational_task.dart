import 'educational_question.dart';

class EducationalTask {
  final String id;
  final String childName;
  final String subject;
  final List<EducationalQuestion> questions;
  final DateTime assignedAt;
  final DateTime? completedAt;
  final bool isCompleted;
  final int screenTimeRewardMinutes;
  final Map<String, bool> questionAnswers; // question_id -> is_correct

  EducationalTask({
    required this.id,
    required this.childName,
    required this.subject,
    required this.questions,
    required this.assignedAt,
    this.completedAt,
    this.isCompleted = false,
    this.screenTimeRewardMinutes = 15,
    this.questionAnswers = const {},
  });

  factory EducationalTask.fromMap(Map<String, dynamic> map) {
    return EducationalTask(
      id: map['id'] ?? '',
      childName: map['childName'] ?? '',
      subject: map['subject'] ?? '',
      questions: (map['questions'] as List<dynamic>?)
          ?.map((q) => EducationalQuestion.fromMap(q))
          .toList() ?? [],
      assignedAt: DateTime.parse(map['assignedAt']),
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
      isCompleted: map['isCompleted'] ?? false,
      screenTimeRewardMinutes: map['screenTimeRewardMinutes'] ?? 15,
      questionAnswers: Map<String, bool>.from(map['questionAnswers'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childName': childName,
      'subject': subject,
      'questions': questions.map((q) => q.toMap()).toList(),
      'assignedAt': assignedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isCompleted': isCompleted,
      'screenTimeRewardMinutes': screenTimeRewardMinutes,
      'questionAnswers': questionAnswers,
    };
  }

  EducationalTask copyWith({
    String? id,
    String? childName,
    String? subject,
    List<EducationalQuestion>? questions,
    DateTime? assignedAt,
    DateTime? completedAt,
    bool? isCompleted,
    int? screenTimeRewardMinutes,
    Map<String, bool>? questionAnswers,
  }) {
    return EducationalTask(
      id: id ?? this.id,
      childName: childName ?? this.childName,
      subject: subject ?? this.subject,
      questions: questions ?? this.questions,
      assignedAt: assignedAt ?? this.assignedAt,
      completedAt: completedAt ?? this.completedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      screenTimeRewardMinutes: screenTimeRewardMinutes ?? this.screenTimeRewardMinutes,
      questionAnswers: questionAnswers ?? this.questionAnswers,
    );
  }

  bool get hasAnsweredAllQuestions {
    return questions.every((q) => questionAnswers.containsKey(q.id));
  }

  int get correctAnswersCount {
    return questionAnswers.values.where((isCorrect) => isCorrect).length;
  }

  double get scorePercentage {
    if (questions.isEmpty) return 0.0;
    return (correctAnswersCount / questions.length) * 100;
  }
}
