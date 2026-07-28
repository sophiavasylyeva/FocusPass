import 'package:cloud_firestore/cloud_firestore.dart';

const Map<String, int> kTierMinutes = {
  'XS': 5,
  'S': 15,
  'M': 30,
  'L': 45,
  'XL': 60,
};

const Map<String, String> kTierLabel = {
  'XS': 'Tiny win',
  'S': 'Quick win',
  'M': 'Solid effort',
  'L': 'Big task',
  'XL': 'Huge effort',
};

class ProductiveTaskPreset {
  final String id;
  final String title;
  final String emoji;
  final String tier;
  final String category;

  const ProductiveTaskPreset({
    required this.id,
    required this.title,
    required this.emoji,
    required this.tier,
    required this.category,
  });
}

const List<ProductiveTaskPreset> kProductivePresets = [
  // XS – 5 min
  ProductiveTaskPreset(
    id: 'p1',
    title: 'Make your bed',
    emoji: '🛏️',
    tier: 'XS',
    category: 'Home',
  ),
  ProductiveTaskPreset(
    id: 'p2',
    title: 'Feed the pet',
    emoji: '🐶',
    tier: 'XS',
    category: 'Home',
  ),
  ProductiveTaskPreset(
    id: 'p3',
    title: 'Set the table',
    emoji: '🍽️',
    tier: 'XS',
    category: 'Home',
  ),
  ProductiveTaskPreset(
    id: 'p4',
    title: 'Water the plants',
    emoji: '🪴',
    tier: 'XS',
    category: 'Home',
  ),
  // S – 15 min
  ProductiveTaskPreset(
    id: 'p5',
    title: 'Put away laundry',
    emoji: '🧺',
    tier: 'S',
    category: 'Home',
  ),
  ProductiveTaskPreset(
    id: 'p6',
    title: '10 min stretching',
    emoji: '🧘',
    tier: 'S',
    category: 'Self-care',
  ),
  ProductiveTaskPreset(
    id: 'p7',
    title: 'Walk the dog',
    emoji: '🐕',
    tier: 'S',
    category: 'Outdoors',
  ),
  // M – 30 min
  ProductiveTaskPreset(
    id: 'p8',
    title: 'Wash the dishes',
    emoji: '🧽',
    tier: 'M',
    category: 'Home',
  ),
  ProductiveTaskPreset(
    id: 'p9',
    title: 'Clean your room',
    emoji: '🧹',
    tier: 'M',
    category: 'Home',
  ),
  ProductiveTaskPreset(
    id: 'p10',
    title: 'Read a book',
    emoji: '📖',
    tier: 'M',
    category: 'Learning',
  ),
  ProductiveTaskPreset(
    id: 'p11',
    title: 'Practice instrument',
    emoji: '🎹',
    tier: 'M',
    category: 'Learning',
  ),
  ProductiveTaskPreset(
    id: 'p12',
    title: 'Help cook dinner',
    emoji: '🍳',
    tier: 'M',
    category: 'Family',
  ),
  // L – 45 min
  ProductiveTaskPreset(
    id: 'p13',
    title: 'Yardwork',
    emoji: '🍂',
    tier: 'L',
    category: 'Outdoors',
  ),
  ProductiveTaskPreset(
    id: 'p14',
    title: 'Deep clean bathroom',
    emoji: '🛁',
    tier: 'L',
    category: 'Home',
  ),
  ProductiveTaskPreset(
    id: 'p15',
    title: 'Bake with grandma',
    emoji: '🍪',
    tier: 'L',
    category: 'Family',
  ),
  ProductiveTaskPreset(
    id: 'p16',
    title: 'Help a sibling study',
    emoji: '✏️',
    tier: 'L',
    category: 'Family',
  ),
  ProductiveTaskPreset(
    id: 'p17',
    title: 'Organize a closet',
    emoji: '🗂️',
    tier: 'L',
    category: 'Home',
  ),
  // XL – 60 min
  ProductiveTaskPreset(
    id: 'p18',
    title: 'Wash the car',
    emoji: '🚗',
    tier: 'XL',
    category: 'Outdoors',
  ),
  ProductiveTaskPreset(
    id: 'p19',
    title: 'Big yard project',
    emoji: '🌳',
    tier: 'XL',
    category: 'Outdoors',
  ),
  ProductiveTaskPreset(
    id: 'p20',
    title: 'Volunteer in community',
    emoji: '🤝',
    tier: 'XL',
    category: 'Family',
  ),
  ProductiveTaskPreset(
    id: 'p21',
    title: 'Reorganize whole room',
    emoji: '📦',
    tier: 'XL',
    category: 'Home',
  ),
];

class ProductiveTask {
  final String id;
  // Identity: parentUid + childId are the ONLY fields that should be used
  // to determine ownership of this task. childName is display metadata
  // only (kept for existing UI text and for legacy records written before
  // childId existed — see ProductiveTaskService for the read/write rules).
  final String parentUid;
  final String childId;
  final String childName;
  final String title;
  final String emoji;
  final String tier;
  final String category;
  final int proposedMinutes;
  final int? awardedMinutes;
  final bool isCustom;
  final String? note;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime submittedAt;
  final DateTime? resolvedAt;

  const ProductiveTask({
    required this.id,
    required this.parentUid,
    this.childId = '',
    required this.childName,
    required this.title,
    required this.emoji,
    required this.tier,
    required this.category,
    required this.proposedMinutes,
    this.awardedMinutes,
    required this.isCustom,
    this.note,
    required this.status,
    required this.submittedAt,
    this.resolvedAt,
  });

  factory ProductiveTask.fromMap(String id, Map<String, dynamic> map) {
    return ProductiveTask(
      id: id,
      parentUid: map['parentUid'] ?? '',
      // Legacy documents written before this migration won't have childId —
      // default to '' rather than guessing (see EducationalTask.fromMap for
      // the same convention).
      childId: map['childId'] ?? '',
      childName: map['childName'] ?? '',
      title: map['title'] ?? '',
      emoji: map['emoji'] ?? '🌱',
      tier: map['tier'] ?? 'S',
      category: map['category'] ?? 'Home',
      proposedMinutes: (map['proposedMinutes'] as num?)?.toInt() ?? 15,
      awardedMinutes: (map['awardedMinutes'] as num?)?.toInt(),
      isCustom: map['isCustom'] ?? false,
      note: map['note'],
      status: map['status'] ?? 'pending',
      submittedAt:
          (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'parentUid': parentUid,
      'childId': childId,
      'childName': childName,
      'title': title,
      'emoji': emoji,
      'tier': tier,
      'category': category,
      'proposedMinutes': proposedMinutes,
      if (awardedMinutes != null) 'awardedMinutes': awardedMinutes,
      'isCustom': isCustom,
      if (note != null && note!.isNotEmpty) 'note': note,
      'status': status,
      'submittedAt': FieldValue.serverTimestamp(),
      if (resolvedAt != null) 'resolvedAt': resolvedAt,
    };
  }

  String formatMinutes(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }
}
