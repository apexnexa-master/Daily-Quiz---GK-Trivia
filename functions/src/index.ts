// functions/src/index.ts
// PHASE 2: CLOUD FUNCTIONS (TypeScript)
//
// Deploy: cd functions && npm install && firebase deploy --only functions
//
// Required env vars (set via: firebase functions:config:set):
//   news.api_key = "your_newsapi_key"
//   app.deep_link_domain = "gkquiz.yourapp.com"

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';

admin.initializeApp();
const db = admin.firestore();

// ─── Helpers ──────────────────────────────────────────────────
const getISTDate = (): string => {
  const now = new Date();
  // IST = UTC+5:30
  const ist = new Date(now.getTime() + (5.5 * 60 * 60 * 1000));
  return ist.toISOString().split('T')[0]; // 'YYYY-MM-DD'
};

const getWeekId = (date: string): string => {
  const d = new Date(date);
  const jan1 = new Date(d.getFullYear(), 0, 1);
  const week = Math.ceil((((d.getTime() - jan1.getTime()) / 86400000) + jan1.getDay() + 1) / 7);
  return `${d.getFullYear()}-W${String(week).padStart(2, '0')}`;
};

const EXAM_MODES = ['GENERAL', 'WBPSC', 'SSC', 'UPSC', 'BANK'];

// ══════════════════════════════════════════════════════════════
// 1. DAILY QUIZ GENERATOR
//    Cron: every day at 6:30 AM IST (1:00 AM UTC)
//    Creates quiz + 10 questions for each exam mode.
//    In production: replace mock questions with your CMS or AI API.
// ══════════════════════════════════════════════════════════════
export const dailyQuizGenerator = functions
  .region('asia-south1') // Mumbai — lowest latency for India
  .pubsub
  .schedule('0 1 * * *') // 6:30 AM IST = 1:00 AM UTC
  .timeZone('Asia/Kolkata')
  .onRun(async (_context) => {
    const today = getISTDate();
    const batch = db.batch();

    // Mark yesterday's quizzes as expired
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yDate = yesterday.toISOString().split('T')[0];

    for (const mode of EXAM_MODES) {
      const oldRef = db.collection('quizzes').doc(`${yDate}_${mode}`);
      batch.update(oldRef, { status: 'expired' });
    }
    await batch.commit();

    // Create today's quizzes for all exam modes
    for (const mode of EXAM_MODES) {
      await createQuizForMode(today, mode);
    }

    // Send FCM to all users
    await sendDailyNotification(today);

    functions.logger.info(`Daily quiz created for ${today}`);
    return null;
  });

async function createQuizForMode(date: string, examMode: string): Promise<void> {
  const quizId = `${date}_${examMode}`;
  const expiresAt = new Date(`${date}T01:00:00Z`); // expires next 6:30 AM IST
  expiresAt.setDate(expiresAt.getDate() + 1);

  await db.collection('quizzes').doc(quizId).set({
    quiz_id: quizId,
    date,
    exam_mode: examMode,
    status: 'active',
    question_count: 10,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
    total_attempts: 0,
  });

  // Add 10 questions as subcollection
  // In production: fetch from your question CMS or call an AI API
  const questions = generateMockQuestions(date, examMode);
  const qBatch = db.batch();
  questions.forEach((q, i) => {
    const ref = db.collection('quizzes').doc(quizId)
      .collection('questions').doc(`q${String(i + 1).padStart(2, '0')}`);
    qBatch.set(ref, { ...q, order: i + 1 });
  });
  await qBatch.commit();
}

// Mock question generator — replace with real CMS/AI in production
function generateMockQuestions(date: string, _examMode: string): object[] {
  // This returns static demo questions. In production:
  // - Connect to your question bank CMS (Google Sheets, Strapi, etc.)
  // - Or call OpenAI/Gemini API with today's news headlines
  return [
    {
      text: {
        en: `Which article of the Indian Constitution deals with Right to Equality? (${date})`,
        hi: 'भारतीय संविधान का कौन सा अनुच्छेद समानता के अधिकार से संबंधित है?',
        bn: 'ভারতীয় সংবিধানের কোন অনুচ্ছেদে সমতার অধিকার রয়েছে?',
      },
      options: {
        en: ['Article 12', 'Article 14', 'Article 19', 'Article 21'],
        hi: ['अनुच्छेद 12', 'अनुच्छेद 14', 'अनुच्छेद 19', 'अनुच्छेद 21'],
        bn: ['অনুচ্ছেদ ১২', 'অনুচ্ছেদ ১৪', 'অনুচ্ছেদ ১৯', 'অনুচ্ছেদ ২১'],
      },
      correct_index: 1,
      explanation: {
        en: 'Article 14 guarantees equality before the law and equal protection of laws.',
        hi: 'अनुच्छेद 14 कानून के समक्ष समानता और कानूनों की समान सुरक्षा की गारंटी देता है।',
        bn: 'অনুচ্ছেদ ১৪ আইনের সামনে সাম্য এবং আইনের সমান সুরক্ষার নিশ্চয়তা দেয়।',
      },
      category: 'polity',
      difficulty: 'easy',
      exam_tags: ['UPSC', 'WBPSC', 'SSC'],
    },
    // Add 9 more questions similarly...
  ];
}

async function sendDailyNotification(date: string): Promise<void> {
  const message: admin.messaging.Message = {
    notification: {
      title: '🎯 আজকের কুইজ প্রস্তুত! / Today\'s Quiz is Live!',
      body: `${date} — এখনই শুরু করুন / Start now!`,
    },
    data: { type: 'daily_quiz', date },
    topic: 'daily_quiz', // All users subscribed to this topic
    android: {
      priority: 'high',
      notification: {
        channelId: 'daily_quiz_channel',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
  };
  await admin.messaging().send(message);
}

// ══════════════════════════════════════════════════════════════
// 2. SUBMIT ATTEMPT
//    Called from Flutter app via Cloud Functions callable.
//    Validates answers, calculates score, writes attempt + leaderboard.
// ══════════════════════════════════════════════════════════════
export const submitAttempt = functions
  .region('asia-south1')
  .https
  .onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }

    const { quizId, answers, timeTaken } = data as {
      quizId: string;
      answers: number[];
      timeTaken: number;
    };

    const uid = context.auth.uid;

    // Check if already attempted
    const existingAttempts = await db
      .collection('users').doc(uid)
      .collection('attempts')
      .where('quiz_id', '==', quizId)
      .limit(1)
      .get();

    if (!existingAttempts.empty) {
      throw new functions.https.HttpsError('already-exists', 'Quiz already attempted');
    }

    // Fetch questions to calculate score
    const questionsSnap = await db
      .collection('quizzes').doc(quizId)
      .collection('questions')
      .orderBy('order')
      .get();

    let score = 0;
    questionsSnap.docs.forEach((doc, i) => {
      if (answers[i] === doc.data().correct_index) score++;
    });

    const quizDate = quizId.split('_')[0];
    const examMode = quizId.split('_')[1] || 'GENERAL';
    const weekId = getWeekId(quizDate);
    const attemptId = uuidv4();

    const attemptData = {
      uid,
      quiz_id: quizId,
      quiz_date: quizDate,
      exam_mode: examMode,
      answers,
      score,
      time_taken: timeTaken,
      submitted_at: admin.firestore.FieldValue.serverTimestamp(),
      week_id: weekId,
    };

    // Write attempt + update quiz counter + leaderboard (all in parallel)
    await Promise.all([
      db.collection('users').doc(uid)
        .collection('attempts').doc(attemptId).set(attemptData),

      db.collection('quizzes').doc(quizId).update({
        total_attempts: admin.firestore.FieldValue.increment(1),
      }),

      updateUserStats(uid, score),
      updateLeaderboardEntry(uid, quizDate, weekId, examMode, score, timeTaken),
      updateStreakInternal(uid, quizDate),
    ]);

    return { attemptId, score, weekId };
  });

// ══════════════════════════════════════════════════════════════
// 3. LEADERBOARD UPDATER (internal helper + exported function)
//    Updates /leaderboard/{date}_{uid} — optimized for queries:
//    - Daily: orderBy(quiz_date).orderBy(score, desc).orderBy(time_taken)
//    - Weekly: orderBy(week_id).orderBy(score, desc).orderBy(time_taken)
// ══════════════════════════════════════════════════════════════
async function updateLeaderboardEntry(
  uid: string,
  quizDate: string,
  weekId: string,
  examMode: string,
  score: number,
  timeTaken: number
): Promise<void> {
  const userSnap = await db.collection('users').doc(uid).get();
  const userData = userSnap.data() || {};

  await db.collection('leaderboard').doc(`${quizDate}_${uid}`).set({
    uid,
    display_name: userData.display_name || 'Anonymous',
    photo_url: userData.photo_url || null,
    score,
    time_taken: timeTaken,
    quiz_date: quizDate,
    week_id: weekId,
    exam_mode: examMode,
    submitted_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// Exported for manual triggers if needed
export const updateLeaderboard = functions
  .region('asia-south1')
  .firestore
  .document('users/{uid}/attempts/{attemptId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const { uid } = context.params;
    await updateLeaderboardEntry(
      uid, data.quiz_date, data.week_id,
      data.exam_mode, data.score, data.time_taken
    );
  });

// ══════════════════════════════════════════════════════════════
// 4. STREAK UPDATER
//    Logic:
//    - Same day → no change (already counted)
//    - Yesterday → increment streak
//    - Older → reset to 1
// ══════════════════════════════════════════════════════════════
async function updateStreakInternal(uid: string, quizDate: string): Promise<void> {
  const streakRef = db.collection('users').doc(uid)
    .collection('streak').doc('current');
  const streakSnap = await streakRef.get();

  const yesterday = new Date(quizDate);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = yesterday.toISOString().split('T')[0];

  if (!streakSnap.exists) {
    await streakRef.set({
      current_streak: 1,
      longest_streak: 1,
      last_attempt_date: quizDate,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }

  const streak = streakSnap.data()!;
  const lastDate = streak.last_attempt_date;

  if (lastDate === quizDate) return; // Already counted today

  const newStreak = lastDate === yesterdayStr
    ? streak.current_streak + 1  // Consecutive day
    : 1;                          // Missed — reset

  const longest = Math.max(newStreak, streak.longest_streak || 0);

  await streakRef.update({
    current_streak: newStreak,
    longest_streak: longest,
    last_attempt_date: quizDate,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

export const updateStreak = functions
  .region('asia-south1')
  .https
  .onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '');
    await updateStreakInternal(context.auth.uid, data.quizDate);
    return { success: true };
  });

async function updateUserStats(uid: string, score: number): Promise<void> {
  await db.collection('users').doc(uid).update({
    total_score: admin.firestore.FieldValue.increment(score),
    total_attempts: admin.firestore.FieldValue.increment(1),
    last_seen: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// ══════════════════════════════════════════════════════════════
// 5. CHALLENGE GENERATOR
//    Creates a challenge doc + returns an App Links deep link.
//    Uses Android App Links (NOT deprecated Firebase Dynamic Links).
//    Setup: add assetlinks.json to your web hosting root.
// ══════════════════════════════════════════════════════════════
export const generateChallenge = functions
  .region('asia-south1')
  .https
  .onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '');

    const { quizId, challengerScore, challengerTime } = data;
    const uid = context.auth.uid;

    const userSnap = await db.collection('users').doc(uid).get();
    const userName = userSnap.data()?.display_name || 'A friend';

    const challengeId = uuidv4();
    const domain = functions.config().app?.deep_link_domain || 'gkquiz.yourapp.com';

    // App Links format: https://yourdomain.com/challenge/{id}
    // Android picks this up if assetlinks.json is configured.
    const deepLink = `https://${domain}/challenge/${challengeId}`;

    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 24);

    await db.collection('challenges').doc(challengeId).set({
      challenge_id: challengeId,
      quiz_id: quizId,
      created_by_uid: uid,
      created_by_name: userName,
      challenger_score: challengerScore,
      challenger_time: challengerTime,
      deep_link: deepLink,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
      accepted_by: [],
      status: 'open',
    });

    return { challengeId, deepLink };
  });
