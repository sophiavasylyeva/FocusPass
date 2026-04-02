import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/educational_task.dart';
import '../models/educational_question.dart';
import 'notification_service.dart';
import 'unified_screen_time_service.dart';

class EducationalTaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<EducationalTask>> fetchTasks(String childName) async {
    try {
      final querySnapshot = await _firestore
          .collection('educational_tasks')
          .where('childName', isEqualTo: childName)
          .get();

      return querySnapshot.docs
          .map((doc) => EducationalTask.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching tasks: $e');
      return [];
    }
  }

  Future<void> assignTask(EducationalTask task) async {
    try {
      await _firestore
          .collection('educational_tasks')
          .doc(task.id)
          .set(task.toMap());
    } catch (e) {
      print('❌ Error assigning task: $e');
    }
  }

  Future<bool> completeTask(EducationalTask task) async {
    try {
      print('EducationalTaskService: Completing task ${task.id} for ${task.childName}');
      
      final updatedTask = task.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );

      await _firestore
          .collection('educational_tasks')
          .doc(task.id)
          .update(updatedTask.toMap());
      
      print('EducationalTaskService: Task ${task.id} marked as completed in database');

      // Check if this completes a set of 5 tasks
      final childName = task.childName;
      final tasks = await fetchTasks(childName);
      final today = DateTime.now();
      
      final completedTasksToday = tasks.where((t) {
        return t.isCompleted && 
               t.completedAt != null &&
               t.completedAt!.day == today.day &&
               t.completedAt!.month == today.month &&
               t.completedAt!.year == today.year;
      }).toList();

      print('EducationalTaskService: Child $childName has completed ${completedTasksToday.length} tasks today');
      print('EducationalTaskService: Completed task IDs: ${completedTasksToday.map((t) => t.id).toList()}');
      print('EducationalTaskService: Total tasks found: ${tasks.length}');

      // Show appropriate notification and handle task generation
      if (completedTasksToday.length == 5) {
        // Completed exactly 5 tasks - NOW they earn exactly 15 minutes!
        print('EducationalTaskService: Completed exactly 5 tasks - 15 minutes earned!');
        
        // Grant exactly 15 minutes of screen time through the unified service
        try {
          await UnifiedScreenTimeService.addEarnedTime(15.0);
          print('EducationalTaskService: Added exactly 15 minutes to earned time');
        } catch (e) {
          print('EducationalTaskService: Error adding earned time: $e');
        }
        
        // Temporarily disabled automatic task generation to debug task overlap
        // await _generateNextTaskSet(childName);
        print('EducationalTaskService: Automatic next task generation disabled for debugging');
        
        return true; // Indicate that 5 tasks were completed
      } else {
        // Completed individual task - NO screen time yet
        final tasksNeeded = 5 - completedTasksToday.length;
        final completedInCurrentSet = completedTasksToday.length;
        print('EducationalTaskService: Individual task completed ($completedInCurrentSet/5) - no screen time granted yet');
        
        return false; // Indicate that 5 tasks were not completed yet
      }
    } catch (e) {
      print('❌ Error completing task: $e');
      return false;
    }
  }

  Future<void> checkTasksAndNotify(String childName) async {
    final tasks = await fetchTasks(childName);

    final pendingTasks = tasks.where((t) => !t.isCompleted);

    if (pendingTasks.isNotEmpty) {
      print('EducationalTaskService: ${pendingTasks.length} tasks pending for $childName');
    }
  }

  Future<bool> hasPendingTasks(String childName) async {
    final tasks = await fetchTasks(childName);
    final today = DateTime.now();
    
    // Check if there are any pending tasks for today
    final todayPendingTasks = tasks.where((task) => 
      task.assignedAt.day == today.day &&
      task.assignedAt.month == today.month &&
      task.assignedAt.year == today.year &&
      !task.isCompleted
    ).toList();
    
    print('EducationalTaskService: hasPendingTasks - Found ${todayPendingTasks.length} pending tasks for today');
    return todayPendingTasks.isNotEmpty;
  }

  /// Clear all tasks for a child (for testing purposes)
  Future<void> clearAllTasks(String childName) async {
    try {
      final querySnapshot = await _firestore
          .collection('educational_tasks')
          .where('childName', isEqualTo: childName)
          .get();

      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      print('🗑️ Cleared ${querySnapshot.docs.length} tasks for $childName');
    } catch (e) {
      print('❌ Error clearing tasks: $e');
    }
  }

  Future<void> clearTodaysPendingTasks(String childName) async {
    try {
      final today = DateTime.now();
      final querySnapshot = await _firestore
          .collection('educational_tasks')
          .where('childName', isEqualTo: childName)
          .where('isCompleted', isEqualTo: false)
          .get();

      int deleted = 0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final assignedAt = (data['assignedAt'] as dynamic)?.toDate() as DateTime?;
        if (assignedAt != null &&
            assignedAt.year == today.year &&
            assignedAt.month == today.month &&
            assignedAt.day == today.day) {
          await doc.reference.delete();
          deleted++;
        }
      }
      print('🗑️ Cleared $deleted pending tasks for today ($childName)');
    } catch (e) {
      print('❌ Error clearing today\'s pending tasks: $e');
    }
  }

  Future<void> generateDailyTasks(String childName, List<String> subjects, String ageRange) async {
    final existingTasks = await fetchTasks(childName);
    final today = DateTime.now();
    
    print('🔄 generateDailyTasks: Checking for existing tasks...');
    print('🔄 generateDailyTasks: Found ${existingTasks.length} existing tasks');
    print('🔄 generateDailyTasks: Child name: $childName');
    print('🔄 generateDailyTasks: Subjects received: $subjects');
    print('🔄 generateDailyTasks: Age range: $ageRange');
    
    // Check if we already have 5 pending tasks for today
    final todayPendingTasks = existingTasks.where((task) => 
      task.assignedAt.day == today.day &&
      task.assignedAt.month == today.month &&
      task.assignedAt.year == today.year &&
      !task.isCompleted  // Only count uncompleted tasks
    ).toList();

    print('🔄 generateDailyTasks: Found ${todayPendingTasks.length} pending tasks for today');

    if (todayPendingTasks.length >= 5) {
      print('🔄 generateDailyTasks: Already have ${todayPendingTasks.length} pending tasks for today, skipping generation');
      return; // Already have enough pending tasks for today
    }

    // Generate exactly 5 individual tasks (each with 1 question)
    final tasksToGenerate = 5 - todayPendingTasks.length;
    print('🔄 generateDailyTasks: Generating $tasksToGenerate new tasks');
    print('🔄 generateDailyTasks: Available subjects for task generation: $subjects');
    
    for (int i = 0; i < tasksToGenerate; i++) {
      // Cycle through subjects to ensure variety
      final subject = subjects[i % subjects.length];
      print('🔄 generateDailyTasks: Task ${i + 1} - Using subject: $subject (index: ${i % subjects.length} from ${subjects.length} subjects)');
      final question = await _getUnusedQuestionForSubject(childName, subject, ageRange);
      
      final task = EducationalTask(
        id: '${childName}_question_${today.millisecondsSinceEpoch}_$i',
        childName: childName,
        subject: subject,
        questions: [question],
        assignedAt: today,
        screenTimeRewardMinutes: 0,
      );

      print('🔄 generateDailyTasks: Creating task ${i + 1}/5 for $subject (Question: ${question.id})');
      await assignTask(task);
    }
    print('🔄 generateDailyTasks: Task generation completed - 5 individual tasks created');
  }

  EducationalQuestion _generateSingleQuestionForSubject(String subject, String ageRange, int questionIndex) {
    final allQuestions = _generateQuestionsForSubject(subject, ageRange);
    final adjustedIndex = (questionIndex + DateTime.now().millisecond) % allQuestions.length;
    return allQuestions[adjustedIndex];
  }

  Future<EducationalQuestion> _getUnusedQuestionForSubject(String childName, String subject, String ageRange) async {
    final allQuestions = _generateQuestionsForSubject(subject, ageRange);
    final usedQuestionIds = await _getUsedQuestionIds(childName, subject);
    
    var unusedQuestions = allQuestions.where((q) => !usedQuestionIds.contains(q.id)).toList();
    
    if (unusedQuestions.isEmpty) {
      await _resetUsedQuestions(childName, subject);
      unusedQuestions = allQuestions;
    }
    
    final randomIndex = DateTime.now().millisecond % unusedQuestions.length;
    final selectedQuestion = unusedQuestions[randomIndex];
    
    await _markQuestionAsUsed(childName, subject, selectedQuestion.id);
    
    return selectedQuestion;
  }

  Future<Set<String>> _getUsedQuestionIds(String childName, String subject) async {
    try {
      final doc = await _firestore
          .collection('used_questions')
          .doc('${childName}_$subject')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['usedIds'] != null) {
          return Set<String>.from(data['usedIds'] as List);
        }
      }
      return {};
    } catch (e) {
      print('Error getting used question IDs: $e');
      return {};
    }
  }

  Future<void> _markQuestionAsUsed(String childName, String subject, String questionId) async {
    try {
      await _firestore
          .collection('used_questions')
          .doc('${childName}_$subject')
          .set({
            'childName': childName,
            'subject': subject,
            'usedIds': FieldValue.arrayUnion([questionId]),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error marking question as used: $e');
    }
  }

  Future<void> _resetUsedQuestions(String childName, String subject) async {
    try {
      await _firestore
          .collection('used_questions')
          .doc('${childName}_$subject')
          .delete();
      print('Reset used questions for $childName in $subject - all questions available again');
    } catch (e) {
      print('Error resetting used questions: $e');
    }
  }

  /// Generate a similar question for retry when child gets answer wrong
  Future<EducationalQuestion> generateSimilarQuestion(String subject, String ageRange, int questionIndex, {String? childName}) async {
    if (childName != null) {
      return await _getUnusedQuestionForSubject(childName, subject, ageRange);
    }
    
    final allQuestions = _generateQuestionsForSubject(subject, ageRange);
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final randomIndex = (questionIndex + currentTime + subject.hashCode) % allQuestions.length;
    
    print('EducationalTaskService: Generated similar $subject question (index $randomIndex of ${allQuestions.length})');
    return allQuestions[randomIndex];
  }

  List<EducationalQuestion> _generateQuestionsForSubject(String subject, String ageRange) {
    switch (subject.toLowerCase()) {
      case 'math':
        return _generateMathQuestions(ageRange);
      case 'english':
        return _generateEnglishQuestions(ageRange);
      case 'science':
        return _generateScienceQuestions(ageRange);
      case 'history':
        return _generateHistoryQuestions(ageRange);
      case 'art':
        return _generateArtQuestions(ageRange);
      case 'coding':
        return _generateCodingQuestions(ageRange);
      case 'geography':
        return _generateGeographyQuestions(ageRange);
      default:
        return _generateGeneralKnowledgeQuestions(ageRange);
    }
  }

  List<EducationalQuestion> _generateMathQuestions(String ageRange) {
    // For 14-16 age group (high school level)
    if (ageRange == '14-16') {
      return [
        EducationalQuestion(
          id: 'math_1',
          question: 'What is the value of x in the equation: 2x + 8 = 24?',
          options: ['6', '8', '10', '12'],
          correctAnswerIndex: 1,
          subject: 'Math',
          difficulty: 'medium',
          explanation: '2x + 8 = 24, so 2x = 16, therefore x = 8',
        ),
        EducationalQuestion(
          id: 'math_2',
          question: 'What is the area of a circle with radius 5 units? (Use π ≈ 3.14)',
          options: ['78.5 sq units', '31.4 sq units', '15.7 sq units', '62.8 sq units'],
          correctAnswerIndex: 0,
          subject: 'Math',
          difficulty: 'medium',
          explanation: 'Area = πr² = 3.14 × 5² = 3.14 × 25 = 78.5 sq units',
        ),
        EducationalQuestion(
          id: 'math_3',
          question: 'Simplify: 3(x + 4) - 2x',
          options: ['x + 12', '5x + 12', 'x + 4', '3x + 2'],
          correctAnswerIndex: 0,
          subject: 'Math',
          difficulty: 'medium',
          explanation: '3(x + 4) - 2x = 3x + 12 - 2x = x + 12',
        ),
        EducationalQuestion(
          id: 'math_4',
          question: 'What is the slope of a line passing through points (2, 3) and (4, 7)?',
          options: ['2', '1', '4', '0.5'],
          correctAnswerIndex: 0,
          subject: 'Math',
          difficulty: 'medium',
          explanation: 'Slope = (y₂ - y₁)/(x₂ - x₁) = (7 - 3)/(4 - 2) = 4/2 = 2',
        ),
        EducationalQuestion(
          id: 'math_5',
          question: 'If f(x) = 2x + 3, what is f(5)?',
          options: ['10', '13', '8', '11'],
          correctAnswerIndex: 1,
          subject: 'Math',
          difficulty: 'easy',
          explanation: 'f(5) = 2(5) + 3 = 10 + 3 = 13',
        ),
        EducationalQuestion(
          id: 'math_6',
          question: 'What is the square root of 144?',
          options: ['10', '11', '12', '14'],
          correctAnswerIndex: 2,
          subject: 'Math',
          difficulty: 'easy',
          explanation: '√144 = 12 because 12 × 12 = 144',
        ),
        EducationalQuestion(
          id: 'math_7',
          question: 'Solve for x: 3x - 7 = 14',
          options: ['5', '6', '7', '8'],
          correctAnswerIndex: 2,
          subject: 'Math',
          difficulty: 'medium',
          explanation: '3x - 7 = 14, so 3x = 21, therefore x = 7',
        ),
        EducationalQuestion(
          id: 'math_8',
          question: 'What is 15% of 200?',
          options: ['25', '30', '35', '40'],
          correctAnswerIndex: 1,
          subject: 'Math',
          difficulty: 'easy',
          explanation: '15% of 200 = 0.15 × 200 = 30',
        ),
        EducationalQuestion(
          id: 'math_9',
          question: 'What is the volume of a cube with side length 4?',
          options: ['16', '32', '64', '48'],
          correctAnswerIndex: 2,
          subject: 'Math',
          difficulty: 'medium',
          explanation: 'Volume of a cube = side³ = 4³ = 64',
        ),
        EducationalQuestion(
          id: 'math_10',
          question: 'What is the value of 2³ × 3²?',
          options: ['72', '64', '81', '54'],
          correctAnswerIndex: 0,
          subject: 'Math',
          difficulty: 'medium',
          explanation: '2³ × 3² = 8 × 9 = 72',
        ),
      ];
    }
    
    // Default questions for other age groups
    return [
      EducationalQuestion(
        id: 'math_basic_1',
        question: 'What is 12 × 8?',
        options: ['84', '96', '104', '88'],
        correctAnswerIndex: 1,
        subject: 'Math',
        difficulty: 'easy',
        explanation: '12 × 8 = 96',
      ),
      EducationalQuestion(
        id: 'math_basic_2',
        question: 'What is 144 ÷ 12?',
        options: ['11', '12', '13', '10'],
        correctAnswerIndex: 1,
        subject: 'Math',
        difficulty: 'easy',
        explanation: '144 ÷ 12 = 12',
      ),
      EducationalQuestion(
        id: 'math_basic_3',
        question: 'What is 25% of 80?',
        options: ['15', '20', '25', '30'],
        correctAnswerIndex: 1,
        subject: 'Math',
        difficulty: 'easy',
        explanation: '25% of 80 = 0.25 × 80 = 20',
      ),
      EducationalQuestion(
        id: 'math_basic_4',
        question: 'What is the perimeter of a rectangle with length 8 and width 5?',
        options: ['26', '40', '13', '24'],
        correctAnswerIndex: 0,
        subject: 'Math',
        difficulty: 'easy',
        explanation: 'Perimeter = 2(length + width) = 2(8 + 5) = 2(13) = 26',
      ),
      EducationalQuestion(
        id: 'math_basic_5',
        question: 'What is 7²?',
        options: ['14', '49', '21', '42'],
        correctAnswerIndex: 1,
        subject: 'Math',
        difficulty: 'easy',
        explanation: '7² = 7 × 7 = 49',
      ),
    ];
  }

  List<EducationalQuestion> _generateEnglishQuestions(String ageRange) {
    // For 14-16 age group
    if (ageRange == '14-16') {
      return [
        EducationalQuestion(
          id: 'english_1',
          question: 'Which of the following is a metaphor?',
          options: [
            'The wind whispered through the trees',
            'Time is money',
            'The car screeched to a halt',
            'She runs like the wind'
          ],
          correctAnswerIndex: 1,
          subject: 'English',
          difficulty: 'medium',
          explanation: 'A metaphor directly compares two things without using "like" or "as". "Time is money" is a metaphor.',
        ),
        EducationalQuestion(
          id: 'english_2',
          question: 'What is the past participle of "break"?',
          options: ['broke', 'broken', 'breaking', 'breaks'],
          correctAnswerIndex: 1,
          subject: 'English',
          difficulty: 'easy',
          explanation: 'The past participle of "break" is "broken" (have/has broken).',
        ),
        EducationalQuestion(
          id: 'english_3',
          question: 'Which sentence uses correct grammar?',
          options: [
            'Me and him went to the store',
            'Him and I went to the store', 
            'He and I went to the store',
            'I and he went to the store'
          ],
          correctAnswerIndex: 2,
          subject: 'English',
          difficulty: 'medium',
          explanation: 'The correct form is "He and I" as the compound subject.',
        ),
        EducationalQuestion(
          id: 'english_4',
          question: 'What type of literary device is "The stars danced in the sky"?',
          options: ['Metaphor', 'Simile', 'Personification', 'Alliteration'],
          correctAnswerIndex: 2,
          subject: 'English',
          difficulty: 'medium',
          explanation: 'Personification gives human characteristics to non-human things. Stars cannot actually dance.',
        ),
        EducationalQuestion(
          id: 'english_5',
          question: 'Which word is an adverb in: "She quickly finished her homework"?',
          options: ['She', 'quickly', 'finished', 'homework'],
          correctAnswerIndex: 1,
          subject: 'English',
          difficulty: 'easy',
          explanation: 'Adverbs modify verbs and often end in -ly. "Quickly" modifies how she finished.',
        ),
      ];
    }
    
    // Default questions
    return [
      EducationalQuestion(
        id: 'english_basic_1',
        question: 'Which word is a noun?',
        options: ['quickly', 'beautiful', 'house', 'run'],
        correctAnswerIndex: 2,
        subject: 'English',
        difficulty: 'easy',
        explanation: 'A noun is a person, place, or thing. "House" is a thing, so it\'s a noun.',
      ),
      EducationalQuestion(
        id: 'english_basic_2',
        question: 'What is the plural of "child"?',
        options: ['childs', 'children', 'childes', 'child'],
        correctAnswerIndex: 1,
        subject: 'English',
        difficulty: 'easy',
        explanation: 'The plural of "child" is "children", an irregular plural form.',
      ),
      EducationalQuestion(
        id: 'english_basic_3',
        question: 'Which sentence is a question?',
        options: ['Go to the store', 'What time is it', 'I like pizza', 'Close the door'],
        correctAnswerIndex: 1,
        subject: 'English',
        difficulty: 'easy',
        explanation: 'Questions ask for information and typically start with question words like "what".',
      ),
      EducationalQuestion(
        id: 'english_basic_4',
        question: 'Which word rhymes with "cat"?',
        options: ['dog', 'bat', 'fish', 'bird'],
        correctAnswerIndex: 1,
        subject: 'English',
        difficulty: 'easy',
        explanation: '"Bat" rhymes with "cat" - both end with the same sound.',
      ),
      EducationalQuestion(
        id: 'english_basic_5',
        question: 'What punctuation mark ends a statement?',
        options: ['!', '?', '.', ','],
        correctAnswerIndex: 2,
        subject: 'English',
        difficulty: 'easy',
        explanation: 'A period (.) ends a statement or declarative sentence.',
      ),
    ];
  }

  List<EducationalQuestion> _generateScienceQuestions(String ageRange) {
    return [
      EducationalQuestion(
        id: 'science_1',
        question: 'What is the chemical symbol for water?',
        options: ['H₂O', 'CO₂', 'NaCl', 'O₂'],
        correctAnswerIndex: 0,
        subject: 'Science',
        difficulty: 'easy',
        explanation: 'Water is composed of 2 hydrogen atoms and 1 oxygen atom: H₂O',
      ),
      EducationalQuestion(
        id: 'science_2',
        question: 'Which planet is closest to the Sun?',
        options: ['Venus', 'Earth', 'Mercury', 'Mars'],
        correctAnswerIndex: 2,
        subject: 'Science',
        difficulty: 'easy',
        explanation: 'Mercury is the closest planet to the Sun in our solar system.',
      ),
      EducationalQuestion(
        id: 'science_3',
        question: 'What gas do plants absorb during photosynthesis?',
        options: ['Oxygen', 'Nitrogen', 'Carbon dioxide', 'Hydrogen'],
        correctAnswerIndex: 2,
        subject: 'Science',
        difficulty: 'easy',
        explanation: 'Plants absorb carbon dioxide (CO₂) from the air during photosynthesis.',
      ),
      EducationalQuestion(
        id: 'science_4',
        question: 'How many bones are there in an adult human body?',
        options: ['206', '208', '210', '204'],
        correctAnswerIndex: 0,
        subject: 'Science',
        difficulty: 'medium',
        explanation: 'An adult human body has 206 bones.',
      ),
      EducationalQuestion(
        id: 'science_5',
        question: 'What is the force that pulls objects toward Earth?',
        options: ['Magnetism', 'Friction', 'Gravity', 'Electricity'],
        correctAnswerIndex: 2,
        subject: 'Science',
        difficulty: 'easy',
        explanation: 'Gravity is the force that attracts objects toward the center of Earth.',
      ),
      EducationalQuestion(
        id: 'science_6',
        question: 'What is the largest organ in the human body?',
        options: ['Heart', 'Liver', 'Skin', 'Brain'],
        correctAnswerIndex: 2,
        subject: 'Science',
        difficulty: 'medium',
        explanation: 'The skin is the largest organ, covering about 20 square feet in adults.',
      ),
      EducationalQuestion(
        id: 'science_7',
        question: 'What type of animal is a dolphin?',
        options: ['Fish', 'Reptile', 'Mammal', 'Amphibian'],
        correctAnswerIndex: 2,
        subject: 'Science',
        difficulty: 'easy',
        explanation: 'Dolphins are mammals - they breathe air, are warm-blooded, and nurse their young.',
      ),
      EducationalQuestion(
        id: 'science_8',
        question: 'What is the boiling point of water at sea level?',
        options: ['90°C', '100°C', '110°C', '212°C'],
        correctAnswerIndex: 1,
        subject: 'Science',
        difficulty: 'easy',
        explanation: 'Water boils at 100°C (212°F) at sea level atmospheric pressure.',
      ),
      EducationalQuestion(
        id: 'science_9',
        question: 'Which blood cells help fight infection?',
        options: ['Red blood cells', 'White blood cells', 'Platelets', 'Plasma'],
        correctAnswerIndex: 1,
        subject: 'Science',
        difficulty: 'medium',
        explanation: 'White blood cells are part of the immune system and help fight infections.',
      ),
      EducationalQuestion(
        id: 'science_10',
        question: 'What is the speed of light approximately?',
        options: ['300,000 km/s', '150,000 km/s', '500,000 km/s', '1,000,000 km/s'],
        correctAnswerIndex: 0,
        subject: 'Science',
        difficulty: 'hard',
        explanation: 'Light travels at approximately 300,000 kilometers per second in a vacuum.',
      ),
    ];
  }

  List<EducationalQuestion> _generateHistoryQuestions(String ageRange) {
    return [
      EducationalQuestion(
        id: 'history_1',
        question: 'In which year did World War II end?',
        options: ['1944', '1945', '1946', '1947'],
        correctAnswerIndex: 1,
        subject: 'History',
        difficulty: 'medium',
        explanation: 'World War II ended in 1945 with the surrender of Japan.',
      ),
      EducationalQuestion(
        id: 'history_2',
        question: 'Who was the first President of the United States?',
        options: ['Thomas Jefferson', 'George Washington', 'John Adams', 'Benjamin Franklin'],
        correctAnswerIndex: 1,
        subject: 'History',
        difficulty: 'easy',
        explanation: 'George Washington was the first President of the United States (1789-1797).',
      ),
      EducationalQuestion(
        id: 'history_3',
        question: 'Which ancient civilization built the pyramids of Giza?',
        options: ['Romans', 'Greeks', 'Egyptians', 'Babylonians'],
        correctAnswerIndex: 2,
        subject: 'History',
        difficulty: 'easy',
        explanation: 'The ancient Egyptians built the famous pyramids of Giza around 2580-2510 BCE.',
      ),
      EducationalQuestion(
        id: 'history_4',
        question: 'In which year did the Berlin Wall fall?',
        options: ['1987', '1989', '1991', '1993'],
        correctAnswerIndex: 1,
        subject: 'History',
        difficulty: 'medium',
        explanation: 'The Berlin Wall fell in 1989, marking the end of the Cold War era.',
      ),
      EducationalQuestion(
        id: 'history_5',
        question: 'Which explorer is credited with discovering the Americas in 1492?',
        options: ['Vasco da Gama', 'Christopher Columbus', 'Ferdinand Magellan', 'Marco Polo'],
        correctAnswerIndex: 1,
        subject: 'History',
        difficulty: 'easy',
        explanation: 'Christopher Columbus reached the Americas in 1492 while seeking a western route to Asia.',
      ),
      EducationalQuestion(
        id: 'history_6',
        question: 'What was the name of the ship that carried the Pilgrims to America in 1620?',
        options: ['Santa Maria', 'Mayflower', 'Endeavour', 'Victoria'],
        correctAnswerIndex: 1,
        subject: 'History',
        difficulty: 'medium',
        explanation: 'The Mayflower carried 102 Pilgrims from England to Plymouth, Massachusetts in 1620.',
      ),
      EducationalQuestion(
        id: 'history_7',
        question: 'Who wrote the Declaration of Independence?',
        options: ['George Washington', 'Benjamin Franklin', 'Thomas Jefferson', 'John Adams'],
        correctAnswerIndex: 2,
        subject: 'History',
        difficulty: 'medium',
        explanation: 'Thomas Jefferson was the primary author of the Declaration of Independence in 1776.',
      ),
      EducationalQuestion(
        id: 'history_8',
        question: 'Which empire was ruled by Julius Caesar?',
        options: ['Greek Empire', 'Roman Empire', 'Persian Empire', 'Ottoman Empire'],
        correctAnswerIndex: 1,
        subject: 'History',
        difficulty: 'easy',
        explanation: 'Julius Caesar was a Roman military leader who became dictator of the Roman Empire.',
      ),
      EducationalQuestion(
        id: 'history_9',
        question: 'In which year did the Titanic sink?',
        options: ['1910', '1912', '1914', '1916'],
        correctAnswerIndex: 1,
        subject: 'History',
        difficulty: 'medium',
        explanation: 'The Titanic sank on April 15, 1912 after hitting an iceberg during its maiden voyage.',
      ),
      EducationalQuestion(
        id: 'history_10',
        question: 'Who was the first person to walk on the Moon?',
        options: ['Buzz Aldrin', 'Neil Armstrong', 'John Glenn', 'Yuri Gagarin'],
        correctAnswerIndex: 1,
        subject: 'History',
        difficulty: 'easy',
        explanation: 'Neil Armstrong became the first person to walk on the Moon on July 20, 1969.',
      ),
    ];
  }

  List<EducationalQuestion> _generateGeneralKnowledgeQuestions(String ageRange) {
    return [
      EducationalQuestion(
        id: 'general_1',
        question: 'What is the capital of France?',
        options: ['London', 'Berlin', 'Paris', 'Madrid'],
        correctAnswerIndex: 2,
        subject: 'General Knowledge',
        difficulty: 'easy',
        explanation: 'Paris is the capital city of France.',
      ),
      EducationalQuestion(
        id: 'general_2',
        question: 'Which continent is known as the "Dark Continent"?',
        options: ['Asia', 'Africa', 'South America', 'Australia'],
        correctAnswerIndex: 1,
        subject: 'General Knowledge',
        difficulty: 'medium',
        explanation: 'Africa was historically referred to as the "Dark Continent" by European explorers.',
      ),
      EducationalQuestion(
        id: 'general_3',
        question: 'What is the largest mammal in the world?',
        options: ['African Elephant', 'Blue Whale', 'Giraffe', 'Hippopotamus'],
        correctAnswerIndex: 1,
        subject: 'General Knowledge',
        difficulty: 'easy',
        explanation: 'The Blue Whale is the largest mammal and largest animal ever known to exist.',
      ),
      EducationalQuestion(
        id: 'general_4',
        question: 'How many continents are there?',
        options: ['5', '6', '7', '8'],
        correctAnswerIndex: 2,
        subject: 'General Knowledge',
        difficulty: 'easy',
        explanation: 'There are 7 continents: Asia, Africa, North America, South America, Antarctica, Europe, and Australia.',
      ),
      EducationalQuestion(
        id: 'general_5',
        question: 'What is the longest river in the world?',
        options: ['Amazon River', 'Nile River', 'Mississippi River', 'Yangtze River'],
        correctAnswerIndex: 1,
        subject: 'General Knowledge',
        difficulty: 'medium',
        explanation: 'The Nile River in Africa is generally considered the longest river in the world at about 6,650 kilometers.',
      ),
    ];
  }

  List<EducationalQuestion> _generateArtQuestions(String ageRange) {
    return [
      EducationalQuestion(
        id: 'art_1',
        question: 'Who painted the Mona Lisa?',
        options: ['Michelangelo', 'Leonardo da Vinci', 'Vincent van Gogh', 'Pablo Picasso'],
        correctAnswerIndex: 1,
        subject: 'Art',
        difficulty: 'easy',
        explanation: 'Leonardo da Vinci painted the Mona Lisa between 1503 and 1519.',
      ),
      EducationalQuestion(
        id: 'art_2',
        question: 'What are the three primary colors in painting?',
        options: ['Red, Green, Blue', 'Red, Yellow, Blue', 'Orange, Green, Purple', 'Cyan, Magenta, Yellow'],
        correctAnswerIndex: 1,
        subject: 'Art',
        difficulty: 'easy',
        explanation: 'In traditional color theory for painting, the primary colors are red, yellow, and blue.',
      ),
      EducationalQuestion(
        id: 'art_3',
        question: 'What art movement was Pablo Picasso a co-founder of?',
        options: ['Impressionism', 'Cubism', 'Surrealism', 'Pop Art'],
        correctAnswerIndex: 1,
        subject: 'Art',
        difficulty: 'medium',
        explanation: 'Picasso co-founded Cubism along with Georges Braque in the early 20th century.',
      ),
      EducationalQuestion(
        id: 'art_4',
        question: 'Which famous painting depicts melting clocks?',
        options: ['The Starry Night', 'The Scream', 'The Persistence of Memory', 'Guernica'],
        correctAnswerIndex: 2,
        subject: 'Art',
        difficulty: 'medium',
        explanation: 'The Persistence of Memory by Salvador Dalí (1931) is famous for its melting clocks.',
      ),
      EducationalQuestion(
        id: 'art_5',
        question: 'What is the technique of creating images using small dots of color?',
        options: ['Impressionism', 'Pointillism', 'Expressionism', 'Cubism'],
        correctAnswerIndex: 1,
        subject: 'Art',
        difficulty: 'medium',
        explanation: 'Pointillism uses tiny dots of pure color to create an image when viewed from a distance.',
      ),
      EducationalQuestion(
        id: 'art_6',
        question: 'Who painted "The Starry Night"?',
        options: ['Claude Monet', 'Vincent van Gogh', 'Salvador Dalí', 'Edvard Munch'],
        correctAnswerIndex: 1,
        subject: 'Art',
        difficulty: 'easy',
        explanation: 'Vincent van Gogh painted The Starry Night in 1889 while at an asylum in Saint-Rémy-de-Provence.',
      ),
      EducationalQuestion(
        id: 'art_7',
        question: 'What is a sculpture made from clay before it is fired called?',
        options: ['Ceramic', 'Greenware', 'Bisque', 'Stoneware'],
        correctAnswerIndex: 1,
        subject: 'Art',
        difficulty: 'medium',
        explanation: 'Greenware is unfired clay that has dried but not yet been kiln-fired.',
      ),
      EducationalQuestion(
        id: 'art_8',
        question: 'Which color is created by mixing red and blue?',
        options: ['Orange', 'Green', 'Purple', 'Brown'],
        correctAnswerIndex: 2,
        subject: 'Art',
        difficulty: 'easy',
        explanation: 'Mixing red and blue creates purple (or violet).',
      ),
      EducationalQuestion(
        id: 'art_9',
        question: 'What famous building was designed by architect Frank Lloyd Wright?',
        options: ['Empire State Building', 'Fallingwater', 'Sydney Opera House', 'Eiffel Tower'],
        correctAnswerIndex: 1,
        subject: 'Art',
        difficulty: 'medium',
        explanation: 'Fallingwater in Pennsylvania was designed by Frank Lloyd Wright in 1935.',
      ),
      EducationalQuestion(
        id: 'art_10',
        question: 'What is the art technique of scratching through a layer of wet paint?',
        options: ['Glazing', 'Impasto', 'Sgraffito', 'Stippling'],
        correctAnswerIndex: 2,
        subject: 'Art',
        difficulty: 'hard',
        explanation: 'Sgraffito involves scratching through wet paint or plaster to reveal a layer beneath.',
      ),
    ];
  }

  List<EducationalQuestion> _generateCodingQuestions(String ageRange) {
    return [
      EducationalQuestion(
        id: 'coding_1',
        question: 'What does HTML stand for?',
        options: ['Hyper Text Markup Language', 'High Tech Modern Language', 'Home Tool Markup Language', 'Hyperlinks Text Mark Language'],
        correctAnswerIndex: 0,
        subject: 'Coding',
        difficulty: 'easy',
        explanation: 'HTML stands for Hyper Text Markup Language, used to structure web content.',
      ),
      EducationalQuestion(
        id: 'coding_2',
        question: 'Which symbol is used to start a comment in Python?',
        options: ['//', '/*', '#', '--'],
        correctAnswerIndex: 2,
        subject: 'Coding',
        difficulty: 'easy',
        explanation: 'In Python, the hash symbol (#) is used to start a single-line comment.',
      ),
      EducationalQuestion(
        id: 'coding_3',
        question: 'What is the output of: print(5 + 3 * 2)?',
        options: ['16', '11', '13', '10'],
        correctAnswerIndex: 1,
        subject: 'Coding',
        difficulty: 'easy',
        explanation: 'Following order of operations: 3 * 2 = 6, then 5 + 6 = 11.',
      ),
      EducationalQuestion(
        id: 'coding_4',
        question: 'What data type stores true or false values?',
        options: ['String', 'Integer', 'Boolean', 'Float'],
        correctAnswerIndex: 2,
        subject: 'Coding',
        difficulty: 'easy',
        explanation: 'Boolean data type stores only two values: true or false.',
      ),
      EducationalQuestion(
        id: 'coding_5',
        question: 'What does CSS stand for?',
        options: ['Computer Style Sheets', 'Cascading Style Sheets', 'Creative Style System', 'Colorful Style Sheets'],
        correctAnswerIndex: 1,
        subject: 'Coding',
        difficulty: 'easy',
        explanation: 'CSS stands for Cascading Style Sheets, used to style web pages.',
      ),
      EducationalQuestion(
        id: 'coding_6',
        question: 'What is a loop used for in programming?',
        options: ['To store data', 'To repeat code multiple times', 'To create variables', 'To print text'],
        correctAnswerIndex: 1,
        subject: 'Coding',
        difficulty: 'easy',
        explanation: 'A loop allows you to repeat a block of code multiple times.',
      ),
      EducationalQuestion(
        id: 'coding_7',
        question: 'What is the result of 10 % 3 (modulo operation)?',
        options: ['3', '1', '0', '10'],
        correctAnswerIndex: 1,
        subject: 'Coding',
        difficulty: 'medium',
        explanation: '10 % 3 gives the remainder when 10 is divided by 3, which is 1.',
      ),
      EducationalQuestion(
        id: 'coding_8',
        question: 'Which of these is NOT a programming language?',
        options: ['Python', 'Java', 'HTML', 'JavaScript'],
        correctAnswerIndex: 2,
        subject: 'Coding',
        difficulty: 'medium',
        explanation: 'HTML is a markup language, not a programming language. It structures content but does not have programming logic.',
      ),
      EducationalQuestion(
        id: 'coding_9',
        question: 'What is an array?',
        options: ['A single variable', 'A collection of values stored together', 'A type of loop', 'A mathematical operator'],
        correctAnswerIndex: 1,
        subject: 'Coding',
        difficulty: 'easy',
        explanation: 'An array is a data structure that stores multiple values in a single variable.',
      ),
      EducationalQuestion(
        id: 'coding_10',
        question: 'What does the == operator check?',
        options: ['Assignment', 'Equality', 'Greater than', 'Less than'],
        correctAnswerIndex: 1,
        subject: 'Coding',
        difficulty: 'easy',
        explanation: 'The == operator checks if two values are equal.',
      ),
    ];
  }

  List<EducationalQuestion> _generateGeographyQuestions(String ageRange) {
    return [
      EducationalQuestion(
        id: 'geography_1',
        question: 'What is the largest country in the world by area?',
        options: ['China', 'United States', 'Canada', 'Russia'],
        correctAnswerIndex: 3,
        subject: 'Geography',
        difficulty: 'easy',
        explanation: 'Russia is the largest country in the world, spanning over 17 million square kilometers.',
      ),
      EducationalQuestion(
        id: 'geography_2',
        question: 'Which ocean is the largest?',
        options: ['Atlantic Ocean', 'Indian Ocean', 'Pacific Ocean', 'Arctic Ocean'],
        correctAnswerIndex: 2,
        subject: 'Geography',
        difficulty: 'easy',
        explanation: 'The Pacific Ocean is the largest and deepest ocean on Earth.',
      ),
      EducationalQuestion(
        id: 'geography_3',
        question: 'What is the capital of Australia?',
        options: ['Sydney', 'Melbourne', 'Canberra', 'Perth'],
        correctAnswerIndex: 2,
        subject: 'Geography',
        difficulty: 'medium',
        explanation: 'Canberra is the capital of Australia, not Sydney as many people think.',
      ),
      EducationalQuestion(
        id: 'geography_4',
        question: 'What is the longest mountain range in the world?',
        options: ['Himalayas', 'Rocky Mountains', 'Andes', 'Alps'],
        correctAnswerIndex: 2,
        subject: 'Geography',
        difficulty: 'medium',
        explanation: 'The Andes mountain range in South America is the longest, stretching about 7,000 km.',
      ),
      EducationalQuestion(
        id: 'geography_5',
        question: 'Which desert is the largest hot desert in the world?',
        options: ['Gobi Desert', 'Sahara Desert', 'Arabian Desert', 'Kalahari Desert'],
        correctAnswerIndex: 1,
        subject: 'Geography',
        difficulty: 'easy',
        explanation: 'The Sahara Desert in Africa is the largest hot desert in the world.',
      ),
      EducationalQuestion(
        id: 'geography_6',
        question: 'What country has the most people?',
        options: ['United States', 'India', 'China', 'Indonesia'],
        correctAnswerIndex: 1,
        subject: 'Geography',
        difficulty: 'medium',
        explanation: 'As of recent data, India has surpassed China as the most populous country.',
      ),
      EducationalQuestion(
        id: 'geography_7',
        question: 'What river flows through Egypt?',
        options: ['Amazon', 'Mississippi', 'Nile', 'Ganges'],
        correctAnswerIndex: 2,
        subject: 'Geography',
        difficulty: 'easy',
        explanation: 'The Nile River flows through Egypt and is crucial to the country\'s history and agriculture.',
      ),
      EducationalQuestion(
        id: 'geography_8',
        question: 'Which continent has the most countries?',
        options: ['Asia', 'Europe', 'Africa', 'South America'],
        correctAnswerIndex: 2,
        subject: 'Geography',
        difficulty: 'medium',
        explanation: 'Africa has 54 countries, more than any other continent.',
      ),
      EducationalQuestion(
        id: 'geography_9',
        question: 'What is the smallest country in the world?',
        options: ['Monaco', 'Vatican City', 'San Marino', 'Liechtenstein'],
        correctAnswerIndex: 1,
        subject: 'Geography',
        difficulty: 'medium',
        explanation: 'Vatican City is the smallest country in the world at about 0.44 square kilometers.',
      ),
      EducationalQuestion(
        id: 'geography_10',
        question: 'What body of water separates Africa and Europe?',
        options: ['Mediterranean Sea', 'Red Sea', 'Black Sea', 'Adriatic Sea'],
        correctAnswerIndex: 0,
        subject: 'Geography',
        difficulty: 'easy',
        explanation: 'The Mediterranean Sea separates Africa from Europe.',
      ),
    ];
  }

  /// Generate the next set of 5 tasks after completing a set
  Future<void> _generateNextTaskSet(String childName) async {
    try {
      final childQuery = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('name', isEqualTo: childName)
          .get();
      
      if (childQuery.docs.isEmpty) return;
      
      final childData = childQuery.docs.first.data();
      final subjects = List<String>.from(childData['subjectsOfInterest'] ?? ['Math', 'English', 'Science']);
      final ageRange = childData['ageRange'] ?? '14-16';
      
      final today = DateTime.now();
      for (int i = 0; i < 5; i++) {
        final subject = subjects[i % subjects.length];
        final question = await _getUnusedQuestionForSubject(childName, subject, ageRange);
        
        final task = EducationalTask(
          id: '${childName}_next_${today.millisecondsSinceEpoch}_$i',
          childName: childName,
          subject: subject,
          questions: [question],
          assignedAt: today,
          screenTimeRewardMinutes: 0,
        );

        await assignTask(task);
      }
      
      print('EducationalTaskService: Generated 5 new tasks for $childName (with unused questions)');
      
    } catch (e) {
      print('EducationalTaskService: Error generating next task set: $e');
    }
  }
}

