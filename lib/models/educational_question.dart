class EducationalQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String subject;
  final String difficulty;
  final String explanation;

  EducationalQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.subject,
    required this.difficulty,
    required this.explanation,
  });

  factory EducationalQuestion.fromMap(Map<String, dynamic> map) {
    return EducationalQuestion(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctAnswerIndex: map['correctAnswerIndex'] ?? 0,
      subject: map['subject'] ?? '',
      difficulty: map['difficulty'] ?? 'easy',
      explanation: map['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'subject': subject,
      'difficulty': difficulty,
      'explanation': explanation,
    };
  }
}
