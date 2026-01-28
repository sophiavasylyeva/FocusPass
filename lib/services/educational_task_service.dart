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
      final question = _generateSingleQuestionForSubject(subject, ageRange, i);
      
      final task = EducationalTask(
        id: '${childName}_question_${today.millisecondsSinceEpoch}_$i',
        childName: childName,
        subject: subject,
        questions: [question], // Each task contains exactly 1 question
        assignedAt: today,
        screenTimeRewardMinutes: 0, // Individual tasks give 0 minutes - only completing 5 gives 15 minutes
      );

      print('🔄 generateDailyTasks: Creating task ${i + 1}/5 for $subject');
      await assignTask(task);
    }
    print('🔄 generateDailyTasks: Task generation completed - 5 individual tasks created');
  }

  EducationalQuestion _generateSingleQuestionForSubject(String subject, String ageRange, int questionIndex) {
    final allQuestions = _generateQuestionsForSubject(subject, ageRange);
    // Add some randomization to avoid predictable patterns
    final adjustedIndex = (questionIndex + DateTime.now().millisecond) % allQuestions.length;
    return allQuestions[adjustedIndex];
  }

  /// Generate a similar question for retry when child gets answer wrong
  Future<EducationalQuestion> generateSimilarQuestion(String subject, String ageRange, int questionIndex) async {
    final allQuestions = _generateQuestionsForSubject(subject, ageRange);
    
    // Use a different randomization approach to get a different question
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

  /// Generate the next set of 5 tasks after completing a set
  Future<void> _generateNextTaskSet(String childName) async {
    try {
      // Get child's preferences
      final childQuery = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('name', isEqualTo: childName)
          .get();
      
      if (childQuery.docs.isEmpty) return;
      
      final childData = childQuery.docs.first.data();
      final subjects = List<String>.from(childData['subjectsOfInterest'] ?? ['Math', 'English', 'Science']);
      final ageRange = childData['ageRange'] ?? '14-16';
      
      // Generate 5 new tasks immediately
      final today = DateTime.now();
      for (int i = 0; i < 5; i++) {
        final subject = subjects[i % subjects.length];
        final question = _generateSingleQuestionForSubject(subject, ageRange, i);
        
        final task = EducationalTask(
          id: '${childName}_next_${today.millisecondsSinceEpoch}_$i',
          childName: childName,
          subject: subject,
          questions: [question],
          assignedAt: today,
          screenTimeRewardMinutes: 0, // Individual tasks give 0 minutes - only completing 5 gives 15 minutes
        );

        await assignTask(task);
      }
      
      print('EducationalTaskService: Generated 5 new tasks for $childName to earn next 15-minute session');
      
    } catch (e) {
      print('EducationalTaskService: Error generating next task set: $e');
    }
  }
}

