import '../models/models.dart';

/// 模拟数据生成器
class MockData {
  static const String mockUserId = 'user_001';

  // 模拟题目数据
  static List<Question> getQuestions() {
    final now = DateTime.now();
    return [
      // 数学 - 二次函数
      Question(
        id: 'q1',
        subject: Subject.math,
        knowledgePointId: 'kp1',
        knowledgePointName: '二次函数',
        type: QuestionType.choice,
        difficulty: Difficulty.easy,
        content: '已知二次函数 y = x² - 4x + 3，求该函数的最小值。',
        options: ['-1', '0', '1', '3'],
        answer: 'A',
        explanation: '二次函数 y = x² - 4x + 3 可以配方为 y = (x-2)² - 1，因此顶点坐标为 (2, -1)，最小值为 -1。',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      Question(
        id: 'q2',
        subject: Subject.math,
        knowledgePointId: 'kp1',
        knowledgePointName: '二次函数',
        type: QuestionType.choice,
        difficulty: Difficulty.easy,
        content: '若二次函数 y = ax² + bx + c 的图像经过点 (1, 0)、(3, 0)，则其对称轴为？',
        options: ['x = 1', 'x = 2', 'x = 3', 'x = 4'],
        answer: 'B',
        explanation: '由于函数图像经过 (1, 0) 和 (3, 0) 两点，这两点是函数的零点，对称轴为 x = (1+3)/2 = 2。',
        createdAt: now.subtract(const Duration(days: 9)),
      ),
      Question(
        id: 'q3',
        subject: Subject.math,
        knowledgePointId: 'kp1',
        knowledgePointName: '二次函数',
        type: QuestionType.choice,
        difficulty: Difficulty.veryEasy,
        content: '已知二次函数 y = -2x² + 8x - 5，该函数的开口方向是？',
        options: ['向上', '向下', '向左', '向右'],
        answer: 'B',
        explanation: '二次函数的开口方向由二次项系数决定。当 a < 0 时开口向下，此题中 a = -2 < 0，所以开口向下。',
        createdAt: now.subtract(const Duration(days: 8)),
      ),

      // 数学 - 三角函数
      Question(
        id: 'q4',
        subject: Subject.math,
        knowledgePointId: 'kp2',
        knowledgePointName: '三角函数',
        type: QuestionType.choice,
        difficulty: Difficulty.easy,
        content: '已知 sinα = 3/5，α 为锐角，则 cosα = ？',
        options: ['3/5', '4/5', '5/3', '5/4'],
        answer: 'B',
        explanation: '根据勾股定理 sin²α + cos²α = 1，已知 sinα = 3/5，所以 cos²α = 1 - (3/5)² = 16/25，因为 α 为锐角，所以 cosα = 4/5。',
        createdAt: now.subtract(const Duration(days: 7)),
      ),
      Question(
        id: 'q5',
        subject: Subject.math,
        knowledgePointId: 'kp2',
        knowledgePointName: '三角函数',
        type: QuestionType.choice,
        difficulty: Difficulty.veryEasy,
        content: '在直角三角形中，若一个锐角为 30°，则其正弦值为？',
        options: ['1/2', '√3/2', '√2/2', '1'],
        answer: 'A',
        explanation: '这是特殊角的三角函数值。sin30° = 1/2，这是需要记住的基本值。',
        createdAt: now.subtract(const Duration(days: 6)),
      ),

      // 物理 - 牛顿第二定律
      Question(
        id: 'q6',
        subject: Subject.physics,
        knowledgePointId: 'kp3',
        knowledgePointName: '牛顿第二定律',
        type: QuestionType.choice,
        difficulty: Difficulty.easy,
        content: '一个质量为 2kg 的物体，受到 10N 的合力作用，其加速度为？',
        options: ['2 m/s²', '5 m/s²', '10 m/s²', '20 m/s²'],
        answer: 'B',
        explanation: '根据牛顿第二定律 F = ma，已知 F = 10N，m = 2kg，所以 a = F/m = 10/2 = 5 m/s²。',
        createdAt: now.subtract(const Duration(days: 5)),
      ),

      // 英语 - 定语从句
      Question(
        id: 'q7',
        subject: Subject.english,
        knowledgePointId: 'kp4',
        knowledgePointName: '定语从句',
        type: QuestionType.choice,
        difficulty: Difficulty.easy,
        content: 'The book ___ I bought yesterday is very interesting.',
        options: ['which', 'who', 'where', 'when'],
        answer: 'A',
        explanation: '先行词是 the book（物），关系代词在从句中作宾语，应该用 which。也可以省略关系代词。',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      Question(
        id: 'q8',
        subject: Subject.english,
        knowledgePointId: 'kp4',
        knowledgePointName: '定语从句',
        type: QuestionType.choice,
        difficulty: Difficulty.easy,
        content: 'The teacher ___ teaches us English is very kind.',
        options: ['who', 'which', 'where', 'whose'],
        answer: 'A',
        explanation: '先行词是 the teacher（人），关系代词在从句中作主语，应该用 who。',
        createdAt: now.subtract(const Duration(days: 3)),
      ),

      // 化学 - 氧化还原反应
      Question(
        id: 'q9',
        subject: Subject.chemistry,
        knowledgePointId: 'kp5',
        knowledgePointName: '氧化还原反应',
        type: QuestionType.choice,
        difficulty: Difficulty.medium,
        content: '在反应 2Fe³⁺ + Cu = 2Fe²⁺ + Cu²⁺ 中，氧化剂是？',
        options: ['Fe³⁺', 'Cu', 'Fe²⁺', 'Cu²⁺'],
        answer: 'A',
        explanation: 'Fe³⁺ 得到电子变为 Fe²⁺，发生还原反应，因此 Fe³⁺ 是氧化剂。Cu 失去电子变为 Cu²⁺，发生氧化反应，Cu 是还原剂。',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Question(
        id: 'q10',
        subject: Subject.chemistry,
        knowledgePointId: 'kp5',
        knowledgePointName: '氧化还原反应',
        type: QuestionType.choice,
        difficulty: Difficulty.easy,
        content: '在氧化还原反应中，失去电子的物质是？',
        options: ['氧化剂', '还原剂', '生成物', '催化剂'],
        answer: 'B',
        explanation: '失去电子的物质被氧化，它本身是还原剂。得到电子的物质被还原，它本身是氧化剂。',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  // 模拟错题记录
  static List<MistakeRecord> getMistakeRecords() {
    final now = DateTime.now();
    return [
      MistakeRecord(
        id: 'm1',
        userId: mockUserId,
        questionId: 'q1',
        subject: Subject.math,
        knowledgePointId: 'kp1',
        knowledgePointName: '二次函数',
        errorReason: ErrorReason.conceptUnclear,
        note: '配方法不熟练',
        userAnswer: 'B',
        masteryStatus: MasteryStatus.practicing,
        reviewCount: 2,
        correctCount: 1,
        originalImageUrls: ['mock_img_1.jpg'],
        createdAt: now.subtract(const Duration(days: 1)),
        lastReviewAt: now.subtract(const Duration(hours: 2)),
      ),
      MistakeRecord(
        id: 'm2',
        userId: mockUserId,
        questionId: 'q6',
        subject: Subject.physics,
        knowledgePointId: 'kp3',
        knowledgePointName: '牛顿第二定律',
        errorReason: ErrorReason.calculationError,
        userAnswer: 'A',
        masteryStatus: MasteryStatus.mastered,
        reviewCount: 3,
        correctCount: 3,
        createdAt: now.subtract(const Duration(days: 2)),
        lastReviewAt: now.subtract(const Duration(days: 1)),
        masteredAt: now.subtract(const Duration(days: 1)),
      ),
      MistakeRecord(
        id: 'm3',
        userId: mockUserId,
        questionId: 'q4',
        subject: Subject.math,
        knowledgePointId: 'kp2',
        knowledgePointName: '三角函数',
        errorReason: ErrorReason.unfamiliar,
        note: '勾股定理公式记错了',
        userAnswer: 'A',
        masteryStatus: MasteryStatus.notStarted,
        reviewCount: 0,
        correctCount: 0,
        originalImageUrls: ['mock_img_3.jpg'],
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      MistakeRecord(
        id: 'm4',
        userId: mockUserId,
        questionId: 'q7',
        subject: Subject.english,
        knowledgePointId: 'kp4',
        knowledgePointName: '定语从句',
        errorReason: ErrorReason.conceptUnclear,
        userAnswer: 'B',
        masteryStatus: MasteryStatus.practicing,
        reviewCount: 1,
        correctCount: 0,
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
      MistakeRecord(
        id: 'm5',
        userId: mockUserId,
        questionId: 'q9',
        subject: Subject.chemistry,
        knowledgePointId: 'kp5',
        knowledgePointName: '氧化还原反应',
        errorReason: ErrorReason.conceptUnclear,
        note: '氧化剂和还原剂总是搞混',
        userAnswer: 'B',
        masteryStatus: MasteryStatus.notStarted,
        reviewCount: 0,
        correctCount: 0,
        originalImageUrls: ['mock_img_5.jpg'],
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
    ];
  }

  // 模拟知识点数据
  static List<KnowledgePoint> getKnowledgePoints() {
    final now = DateTime.now();
    return [
      KnowledgePoint(
        id: 'kp1',
        subject: Subject.math,
        name: '二次函数',
        level: 1,
        mistakeCount: 5,
        masteredCount: 2,
        reviewCount: 8,
        correctCount: 5,
        firstMistakeAt: now.subtract(const Duration(days: 10)),
        lastMistakeAt: now.subtract(const Duration(days: 1)),
        lastReviewAt: now.subtract(const Duration(hours: 2)),
      ),
      KnowledgePoint(
        id: 'kp2',
        subject: Subject.math,
        name: '三角函数',
        level: 1,
        mistakeCount: 3,
        masteredCount: 2,
        reviewCount: 5,
        correctCount: 3,
        firstMistakeAt: now.subtract(const Duration(days: 7)),
        lastMistakeAt: now.subtract(const Duration(days: 3)),
        lastReviewAt: now.subtract(const Duration(days: 2)),
      ),
      KnowledgePoint(
        id: 'kp3',
        subject: Subject.physics,
        name: '牛顿第二定律',
        level: 1,
        mistakeCount: 2,
        masteredCount: 2,
        reviewCount: 6,
        correctCount: 5,
        firstMistakeAt: now.subtract(const Duration(days: 5)),
        lastMistakeAt: now.subtract(const Duration(days: 2)),
        lastReviewAt: now.subtract(const Duration(days: 1)),
      ),
      KnowledgePoint(
        id: 'kp4',
        subject: Subject.english,
        name: '定语从句',
        level: 1,
        mistakeCount: 4,
        masteredCount: 2,
        reviewCount: 4,
        correctCount: 2,
        firstMistakeAt: now.subtract(const Duration(days: 4)),
        lastMistakeAt: now.subtract(const Duration(hours: 12)),
        lastReviewAt: now.subtract(const Duration(hours: 6)),
      ),
      KnowledgePoint(
        id: 'kp5',
        subject: Subject.chemistry,
        name: '氧化还原反应',
        level: 1,
        mistakeCount: 6,
        masteredCount: 2,
        reviewCount: 7,
        correctCount: 3,
        firstMistakeAt: now.subtract(const Duration(days: 8)),
        lastMistakeAt: now.subtract(const Duration(hours: 8)),
        lastReviewAt: now.subtract(const Duration(hours: 4)),
      ),
      KnowledgePoint(
        id: 'kp6',
        subject: Subject.math,
        name: '一元二次方程',
        level: 1,
        mistakeCount: 2,
        masteredCount: 2,
        reviewCount: 4,
        correctCount: 3,
        firstMistakeAt: now.subtract(const Duration(days: 6)),
        lastMistakeAt: now.subtract(const Duration(days: 5)),
        lastReviewAt: now.subtract(const Duration(days: 3)),
      ),
      KnowledgePoint(
        id: 'kp7',
        subject: Subject.physics,
        name: '动能定理',
        level: 1,
        mistakeCount: 3,
        masteredCount: 1,
        reviewCount: 4,
        correctCount: 2,
        firstMistakeAt: now.subtract(const Duration(days: 6)),
        lastMistakeAt: now.subtract(const Duration(days: 4)),
        lastReviewAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  // 模拟用户档案
  static UserProfile getUserProfile() {
    return UserProfile(
      id: mockUserId,
      name: '小明',
      avatar: null,
      email: 'xiaoming@example.com',
      grade: 9, // 初三
      focusSubjects: ['math', 'physics', 'chemistry'],
      totalMistakes: 28,
      masteredMistakes: 15,
      totalPracticeSessions: 45,
      continuousDays: 7,
      createdAt: DateTime.now().subtract(const Duration(days: 21)),
      lastActiveAt: DateTime.now(),
    );
  }

  // 模拟练习会话
  static List<PracticeSession> getPracticeSessions() {
    final now = DateTime.now();
    return [
      PracticeSession(
        id: 's1',
        userId: mockUserId,
        type: PracticeType.dailyReview,
        title: '智能复盘',
        subtitle: '基于遗忘规律智能出题',
        questionIds: ['q1', 'q2', 'q4', 'q5', 'q6', 'q7', 'q9', 'q10'],
        results: [
          QuestionResult(
            questionId: 'q1',
            userAnswer: 'A',
            isCorrect: true,
            timeSpent: 45,
            answeredAt: now.subtract(const Duration(hours: 2)),
          ),
          QuestionResult(
            questionId: 'q2',
            userAnswer: 'B',
            isCorrect: true,
            timeSpent: 60,
            answeredAt: now.subtract(const Duration(hours: 2)),
          ),
          QuestionResult(
            questionId: 'q4',
            userAnswer: 'A',
            isCorrect: false,
            timeSpent: 90,
            answeredAt: now.subtract(const Duration(hours: 1, minutes: 58)),
          ),
        ],
        startedAt: now.subtract(const Duration(hours: 2)),
        isCompleted: false,
      ),
      PracticeSession(
        id: 's2',
        userId: mockUserId,
        type: PracticeType.knowledgePointDrill,
        subject: Subject.math,
        knowledgePointId: 'kp1',
        title: '二次函数 · 举一反三',
        subtitle: '基于该知识点的错题生成',
        questionIds: ['q1', 'q2', 'q3'],
        results: [
          QuestionResult(
            questionId: 'q1',
            userAnswer: 'A',
            isCorrect: true,
            timeSpent: 50,
            answeredAt: now.subtract(const Duration(days: 1)),
          ),
          QuestionResult(
            questionId: 'q2',
            userAnswer: 'B',
            isCorrect: true,
            timeSpent: 55,
            answeredAt: now.subtract(const Duration(days: 1)),
          ),
          QuestionResult(
            questionId: 'q3',
            userAnswer: 'B',
            isCorrect: true,
            timeSpent: 40,
            answeredAt: now.subtract(const Duration(days: 1)),
          ),
        ],
        startedAt: now.subtract(const Duration(days: 1)),
        completedAt: now.subtract(const Duration(days: 1)),
        isCompleted: true,
        aiEncouragement: '太棒了！全部正确！你已经掌握了二次函数的基础知识。',
      ),
    ];
  }

  // 生成智能复盘练习会话
  static PracticeSession generateDailyReviewSession() {
    final questionIds = ['q1', 'q2', 'q4', 'q5', 'q6', 'q7', 'q9', 'q10'];
    
    return PracticeSession(
      id: 'session_daily_${DateTime.now().millisecondsSinceEpoch}',
      userId: mockUserId,
      type: PracticeType.dailyReview,
      questionIds: questionIds,
      title: '智能复盘',
      subtitle: '基于遗忘规律智能出题',
      startedAt: DateTime.now(),
    );
  }

  // 根据知识点生成练习会话
  static PracticeSession generateKnowledgePointSession(KnowledgePoint knowledgePoint) {
    List<String> questionIds;
    
    switch (knowledgePoint.name) {
      case '二次函数':
        questionIds = ['q1', 'q2', 'q3'];
        break;
      case '三角函数':
        questionIds = ['q4', 'q5'];
        break;
      case '牛顿第二定律':
        questionIds = ['q6'];
        break;
      case '定语从句':
        questionIds = ['q7', 'q8'];
        break;
      case '氧化还原反应':
        questionIds = ['q9', 'q10'];
        break;
      default:
        questionIds = ['q1', 'q2', 'q3'];
    }
    
    return PracticeSession(
      id: 'session_kp_${DateTime.now().millisecondsSinceEpoch}',
      userId: mockUserId,
      type: PracticeType.knowledgePointDrill,
      subject: knowledgePoint.subject,
      knowledgePointId: knowledgePoint.id,
      questionIds: questionIds,
      title: '${knowledgePoint.name} · 举一反三',
      subtitle: '基于该知识点的错题生成',
      startedAt: DateTime.now(),
    );
  }

  // 根据错题生成练习会话
  static PracticeSession generateMistakeDrillSession(MistakeRecord mistake) {
    // 根据错题的知识点生成相关题目
    List<String> questionIds;
    
    switch (mistake.knowledgePointName) {
      case '二次函数':
        questionIds = ['q2', 'q3'];
        break;
      case '三角函数':
        questionIds = ['q4', 'q5'];
        break;
      case '牛顿第二定律':
        questionIds = ['q6'];
        break;
      case '定语从句':
        questionIds = ['q7', 'q8'];
        break;
      case '氧化还原反应':
        questionIds = ['q9', 'q10'];
        break;
      default:
        questionIds = ['q1', 'q2'];
    }
    
    return PracticeSession(
      id: 'session_mistake_${DateTime.now().millisecondsSinceEpoch}',
      userId: mockUserId,
      type: PracticeType.mistakeDrill,
      subject: mistake.subject,
      knowledgePointId: mistake.knowledgePointId,
      questionIds: questionIds,
      title: '${mistake.knowledgePointName} · 变式练习',
      subtitle: '基于你的错题生成',
      startedAt: DateTime.now(),
    );
  }

  // 获取统计数据
  static Map<String, dynamic> getStats() {
    return {
      'totalMistakes': 28, // 累计错题数
      'totalReviews': 45, // 累计复盘次数
      'completionRate': 78, // 举一反三完成率(%)
      'weekMistakes': 12, // 本周错题数
      'continuousDays': 7, // 连续复盘天数
      'usageDays': 21, // 使用天数
    };
  }

  // 获取过去一周的数据（用于图表展示）
  static List<Map<String, dynamic>> getWeeklyChartData() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> data = [];
    
    // 更真实的模拟数据：错题数和练习题数
    final mistakeCounts = [3.0, 4.0, 2.0, 5.0, 3.0, 6.0, 4.0];
    final practiceCounts = [8.0, 10.0, 6.0, 12.0, 9.0, 11.0, 10.0];
    
    // 生成过去7天的数据（从6天前到今天）
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayName = _getDayName(date.weekday);
      
      data.add({
        'day': dayName,
        'date': date,
        'mistakeCount': mistakeCounts[6 - i],
        'practiceCount': practiceCounts[6 - i],
        'isToday': i == 0,
      });
    }
    
    return data;
  }
  
  // 获取星期几的中文名称
  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return '周一';
      case 2: return '周二';
      case 3: return '周三';
      case 4: return '周四';
      case 5: return '周五';
      case 6: return '周六';
      case 7: return '周日';
      default: return '';
    }
  }

  // 获取本周报告数据
  static WeeklyReport getWeeklyReport() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    
    return WeeklyReport(
      id: 'wr_${now.millisecondsSinceEpoch}',
      userId: mockUserId,
      weekStart: weekStart,
      weekEnd: weekEnd,
      totalMistakes: 12,
      totalReviews: 25,
      totalPracticeSessions: 8,
      practiceCompletionRate: 0.78,
      overallAccuracy: 0.72,
      topMistakePoints: [
        KnowledgePointStats(
          knowledgePointId: 'kp5',
          knowledgePointName: '氧化还原反应',
          subject: Subject.chemistry,
          mistakeCount: 6,
          accuracy: 0.43,
        ),
        KnowledgePointStats(
          knowledgePointId: 'kp1',
          knowledgePointName: '二次函数',
          subject: Subject.math,
          mistakeCount: 5,
          accuracy: 0.63,
        ),
        KnowledgePointStats(
          knowledgePointId: 'kp4',
          knowledgePointName: '定语从句',
          subject: Subject.english,
          mistakeCount: 4,
          accuracy: 0.50,
        ),
      ],
      errorReasonDistribution: [
        ErrorReasonStats(reason: ErrorReason.conceptUnclear, count: 5, percentage: 0.42),
        ErrorReasonStats(reason: ErrorReason.calculationError, count: 3, percentage: 0.25),
        ErrorReasonStats(reason: ErrorReason.unfamiliar, count: 2, percentage: 0.17),
        ErrorReasonStats(reason: ErrorReason.careless, count: 2, percentage: 0.16),
      ],
      aiSummary: '本周你在化学的氧化还原反应上遇到了较多困难，建议重点复习氧化剂和还原剂的判断方法。数学的二次函数掌握情况有所提升，继续保持！',
      suggestions: [
        '重点复习：氧化还原反应的概念和判断',
        '巩固练习：二次函数的配方法',
        '多做练习：定语从句的关系代词选择',
      ],
      generatedAt: now,
    );
  }
}
