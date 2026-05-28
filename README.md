# Daily GK Quiz App 🎯
> Production-ready Flutter + Firebase quiz app for Indian competitive exam aspirants
> Target: SSC, UPSC, WBPSC, WBP, Bank PO — Bengali-first, AdMob monetized

---

## 📁 Project Structure

```
gk_quiz_app/
├── lib/
│   ├── core/
│   │   ├── constants/       app_constants.dart — AdMob IDs, collection names
│   │   ├── services/        auth, quiz, ad, notification services
│   │   ├── theme/           Material 3 light/dark + Bengali font
│   │   └── utils/           offline manager, date utils
│   ├── data/
│   │   └── models/          All Firestore models (User, Quiz, Question, Attempt...)
│   ├── presentation/
│   │   ├── screens/         Home, Quiz, Result, Login, Leaderboard, Profile
│   │   ├── widgets/         StreakCard, QuizCtaCard, LeaderboardPreview, BannerAd
│   │   └── providers/       All Riverpod providers
│   ├── routes/              AppRouter
│   └── main.dart
├── functions/
│   └── src/index.ts         5 Cloud Functions (TypeScript)
├── firestore.rules           Security rules
├── firestore.indexes.json    Composite indexes
└── firebase.json
```

---

## 🚀 STEP-BY-STEP SETUP

### Step 1 — Firebase Project

```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Create project at https://console.firebase.google.com
# Enable: Authentication, Firestore, Cloud Functions, Cloud Messaging, Analytics

# Connect Flutter app
dart pub global activate flutterfire_cli
flutterfire configure
# → Generates lib/firebase_options.dart automatically
```

### Step 2 — Flutter Dependencies

```bash
flutter pub get
```

### Step 3 — Enable Firebase Services in Console

1. **Authentication** → Enable Google + Anonymous providers
2. **Firestore** → Create database (production mode)
3. **Cloud Messaging** → No extra config needed (flutterfire handles it)
4. **Analytics** → Auto-enabled

### Step 4 — Deploy Firestore Rules + Indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

### Step 5 — Deploy Cloud Functions

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

### Step 6 — AdMob Setup

1. Go to https://admob.google.com → Create app
2. Create 3 ad units: Banner, Interstitial, Rewarded
3. Replace test IDs in `lib/core/constants/app_constants.dart`:
   ```dart
   // Replace these with your real IDs:
   static String get bannerAdUnitId => 'ca-app-pub-XXXXXXXX/XXXXXXXXXX';
   static String get interstitialAdUnitId => 'ca-app-pub-XXXXXXXX/XXXXXXXXXX';
   static String get rewardedAdUnitId => 'ca-app-pub-XXXXXXXX/XXXXXXXXXX';
   ```

### Step 7 — App Links Setup (for Challenge feature)

Host `assetlinks.json` at `https://yourdomain.com/.well-known/assetlinks.json`:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.yourname.gkquiz",
    "sha256_cert_fingerprints": ["YOUR_SHA256_HERE"]
  }
}]
```

Get SHA256: `keytool -list -v -keystore ~/.android/debug.keystore`

Update `AndroidManifest.xml` → replace `gkquiz.yourapp.com` with your domain.

### Step 8 — Build APK

```bash
# Debug APK (for testing)
flutter build apk --debug

# Release APK (for Play Store)
flutter build apk --release

# App Bundle (recommended for Play Store)
flutter build appbundle --release
```

---

## 💰 Monetization Setup

| Format | Trigger | Expected CPM (India) |
|--------|---------|---------------------|
| Banner | Home + Leaderboard | ₹8–15 per 1000 impressions |
| Interstitial | After result screen (max 3/session) | ₹20–40 per 1000 shows |
| Rewarded Video | "Watch to unlock explanation" | ₹40–80 per 1000 views |
| Pro subscription | ₹49–99/month via in_app_purchase | Direct revenue |

**Revenue estimate at 10K DAU:**
- 10K users × 1 interstitial/day × ₹30 CPM = ₹300/day
- 10K users × 0.3 rewarded views/day × ₹60 CPM = ₹180/day
- Banner impressions: ~₹120/day
- **Total: ~₹600/day = ₹18,000/month at 10K DAU**

---

## 🔥 Firestore Cost Optimization

```
Target: keep reads under 50K/day for 10K users (free tier)

Strategy:
  - Hive cache: quiz cached after first fetch → 0 reads on re-open
  - SDK cache: Firestore local cache → 0 network reads for repeat queries
  - Per-user reads/day (after first visit): ~7 reads
  - 10K × 7 = 70K reads/day → add Hive caching → ~40K ✓

Collections that are heavy:
  - leaderboard (limit: 50 docs)   → add .limit(50) always
  - questions (10 per quiz)        → cached in Hive after first load
```

---

## 📲 Google Play Store Checklist

- [ ] Replace all test AdMob IDs with production IDs
- [ ] Set `debugShowCheckedModeBanner: false` ✓ (already done)
- [ ] Add `google-services.json` (from Firebase console)
- [ ] Create signing keystore: `keytool -genkey -v -keystore key.jks`
- [ ] Add to `android/key.properties`
- [ ] Privacy Policy URL (required for AdMob)
- [ ] App screenshots (Bengali UI is a USP — show in store listing)
- [ ] Target: SSC, WBPSC, UPSC, Bank keywords in Play Store description

---

## 🌐 Language Support

| Code | Language | Font |
|------|----------|------|
| `bn` | Bengali (default) | NotoSansBengali |
| `hi` | Hindi | NotoSans |
| `en` | English | NotoSans |

All question text, options, and explanations are stored per-locale in Firestore.
Language selection is persisted in SharedPreferences and survives app restarts.

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

Key things to test:
- `StreakNotifier` — day continuity and reset logic
- `QuizSessionNotifier` — answer selection and submission
- `QuizService.fetchTodayQuiz` — cache-first with mock Hive
- `AdService.showInterstitial` — frequency cap (max 3/session)

---

## 📈 Scaling to 100K DAU

When you hit 50K+ users:
1. Upgrade Firebase to **Blaze plan** (pay-as-you-go)
2. Add Firestore **pagination** to leaderboard (currently limited to 50)
3. Move leaderboard to **Redis/Cloud Cache** for real-time ranking
4. Add **question CMS** (Strapi or Contentful) so a non-dev can add questions
5. Consider **regional sharding**: separate Firestore collections per state

---

## ⚠️ Before Launch Checklist

- [ ] Replace AdMob test IDs → production IDs
- [ ] Replace `gkquiz.yourapp.com` → your real domain in AndroidManifest
- [ ] Update `AppConstants.appPackage` with your real package name
- [ ] Add `google-services.json` from Firebase console
- [ ] Deploy Cloud Functions
- [ ] Set Firebase Functions config: `firebase functions:config:set app.deep_link_domain="yourdomain.com"`
- [ ] Add real questions to Firestore (the mock generator in Cloud Functions is placeholder)
- [ ] Test on low-end Android device (Redmi, Realme) — your target users
- [ ] Test offline mode (airplane mode)
- [ ] Test Bengali rendering on device (not just emulator)
