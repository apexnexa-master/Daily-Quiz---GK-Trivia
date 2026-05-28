# AdMob Setup Guide for GK Quiz App

## Step 1: Create AdMob Account

1. Go to [Google AdMob](https://admob.google.com)
2. Sign in with your Google account
3. Complete account setup (verify phone number, link AdSense)
4. Wait 24-48 hours for account approval

---

## Step 2: Create Ad Units in AdMob

### 2.1 Create Banner Ad Unit
1. In AdMob dashboard → **Apps** → Select your app (or create new)
2. **Ad Units** → **Add Ad Unit**
3. Select **Banner**
4. Name: `Home Screen Banner`
5. Click **Create** → Copy the Ad Unit ID (starts with `ca-app-pub-...`)

### 2.2 Create Interstitial Ad Unit
1. **Ad Units** → **Add Ad Unit**
2. Select **Interstitial**
3. Name: `Quiz Result Interstitial`
4. Click **Create** → Copy the Ad Unit ID

### 2.3 Create Rewarded Ad Unit
1. **Ad Units** → **Add Ad Unit**
2. Select **Rewarded**
3. Name: `Explanation Reward`
4. Set reward: "Unlock Explanation" (user gets explanation after watching)
5. Click **Create** → Copy the Ad Unit ID

---

## Step 3: Get Your App ID

1. In AdMob → **Apps** → Your app
2. Copy the **App ID** (starts with `ca-app-pub-...`)

---

## Step 4: Update App Constants

Open `lib/core/constants/app_constants.dart` and replace the TEST IDs with real ones:

```dart
// ── AdMob Unit IDs ────────────────────────────────────────
static String get admobAppId {
  if (Platform.isAndroid) {
    return 'ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx'; // YOUR REAL APP ID
  }
  return 'ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx'; // iOS
}

static String get bannerAdUnitId {
  if (Platform.isAndroid) {
    return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx'; // YOUR REAL BANNER ID
  }
  return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
}

static String get interstitialAdUnitId {
  if (Platform.isAndroid) {
    return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx'; // YOUR REAL INTERSTITIAL ID
  }
  return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
}

static String get rewardedAdUnitId {
  if (Platform.isAndroid) {
    return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx'; // YOUR REAL REWARDED ID
  }
  return 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
}
```

---

## Step 5: Add AdMob to Android

### 5.1 Update AndroidManifest.xml
```xml
<manifest>
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx"/>
</manifest>
```

### 5.2 Update build.gradle (app level)
```gradle
android {
    defaultConfig {
        multiDexEnabled true
    }
}
```

---

## Step 6: Test Ads (Important!)

Before publishing, test with test ads:

```dart
// In test mode, use these test IDs:
static String get bannerAdUnitId {
  return 'ca-app-pub-3940256099942544/6300978111'; // Test banner
}
// ... same for others
```

**Test Devices:**
- Go to AdMob → **Settings** → **Test devices**
- Add your device ID (see Logcat when running app)
- Or use: `MobileAds.setTestDeviceIds(['YOUR_DEVICE_ID'])`

---

## Ad Placement Strategy

| Screen | Ad Type | Best Practice |
|--------|---------|---------------|
| Home | Banner | Persistent bottom banner |
| Quiz | None | Don't show - hurts UX |
| Result | Interstitial | Show after 3 attempts max |
| Profile | Banner | Top or bottom |
| Leaderboard | Banner | Bottom |

---

## Revenue Estimates (India)

| Ad Type | CPM (approx) |
|---------|--------------|
| Banner | ₹10-30 per 1000 views |
| Interstitial | ₹30-60 per 1000 views |
| Rewarded | ₹40-80 per 1000 views |

**Example:** 10,000 active users × 5 quiz/day = 50,000 impressions/day × ₹30 CPM = ~₹1,500/day

---

## Pro Version (Remove Ads)

Users can purchase "Pro" to remove all ads:
- Store the `isPro` flag in Firestore user document
- Check in AdService before showing any ad
- Use in-app purchases or link to web payment

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Ads not showing | Check App ID in AndroidManifest |
| Empty ad units | Wait 24h after creating units |
| Test ads only | Replace test IDs with real ones |
| Build fails | Ensure `google_mobile_ads` in pubspec.yaml |

---

## Quick Checklist

- [ ] Create AdMob account
- [ ] Create 3 ad units (banner, interstitial, rewarded)
- [ ] Get App ID from AdMob
- [ ] Update `app_constants.dart` with real IDs
- [ ] Update `AndroidManifest.xml` with App ID
- [ ] Test with real ads (not just test ads)
- [ ] Build release APK
- [ ] Publish to Play Store
