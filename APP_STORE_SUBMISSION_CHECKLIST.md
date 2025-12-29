# WalkWise App Store Submission Checklist

[Add a button to the app to view instructions]

## Critical Issues to Address Before Submission

### ✅ **CRITICAL: Android Release Signing**

**Status:** ✅ **VERIFIED** - Release signing is working correctly

**Configuration Verified:**
- ✅ `key.properties` file exists with correct configuration
- ✅ Keystore file exists at `android/app/walkwise-release-key.keystore`
- ✅ `build.gradle.kts` is configured to use release signing
- ✅ **APK signature verified** - Shows release certificate (CN=John Cannon, OU=WalkWise, O=Games Afoot LLC)
- ✅ **NOT using debug keys** - Certificate confirmed as release keystore

**Verification Completed:**
```bash
# Signature verification shows:
Signer #1 certificate DN: CN=John Cannon, OU=WalkWise, O=Games Afoot LLC, L=Johnson City, ST=Tennessee, C=US
Signer #1 certificate SHA-256 digest: a280639af0dd42ff068c644bcda139b7a32de2cfa3bc2021a6b27da7d8a1b075
```

**Note:** The keystore file and passwords are stored securely. Keep backups of the keystore file in a safe location!

---

## App Identifiers (✅ Correct)

### Bundle IDs / Application IDs
- **WalkWise Android:** `com.gowalkwise.walkwise` ✅
- **WalkWise iOS:** `com.gowalkwise.walkwise` ✅
- **Agatha Android:** `com.GoAgatha.agatha` ✅
- **Agatha iOS:** `com.johncannon.agatha` ✅

**Status:** ✅ All identifiers are unique and won't conflict

---

## Firebase Configuration

### Current Setup
- **Firebase Project:** `agatha-923ce` (shared with Agatha)
- **Status:** ✅ This is **FINE** - you can have multiple apps in one Firebase project
- **WalkWise Firebase Apps:**
  - Android: `1:1090917056755:android:dddf347e7b538db65fb786`
  - iOS: `1:1090917056755:ios:42f2523069013b735fb786`

### Important Notes:
- ✅ Both apps can share the same Firebase project
- ✅ Data is separated by app (different bundle IDs)
- ✅ Firebase console shows both apps under the same project
- ⚠️ Make sure Firebase rules allow both apps to access their respective data
- ⚠️ Consider if you want separate Firebase projects later (not required now)
[I believe this is good as is.]

---

## App Store Accounts

### Apple App Store Connect
- **Developer Account:** Use same account as Agatha (GamesAfoot)
- **App Name:** "WalkWise" (check availability)
- **Bundle ID:** `com.gowalkwise.walkwise` - **MUST be registered in App Store Connect first**
- **Action Required:** Create new app listing in App Store Connect with this bundle ID

### Google Play Console
- **Developer Account:** Use same account as Agatha (GamesAfoot)
- **App Name:** "WalkWise" (check availability)
- **Package Name:** `com.gowalkwise.walkwise` - **MUST match exactly**
- **Action Required:** Create new app in Google Play Console

---

## Required Assets & Information

### App Icons
- ✅ Launcher icon configured in `pubspec.yaml`
- ⚠️ Verify icon looks good at all sizes
- **iOS:** Need 1024x1024 icon for App Store
- **Android:** Adaptive icon configured
[Use WalkWise-Green-logo.png found in assets/images]

### Screenshots
- **Required for both stores:**
  - iPhone screenshots (multiple sizes)  [Done]
  - iPad screenshots (if supporting iPad)  [No iPad support]
  - Android phone screenshots  [Done]
  - Android tablet screenshots (if supporting tablets)  [No tablet support]
- **Recommended:** 5-8 screenshots showing key features
[Screenshots are available]

### App Store Listing Information

#### Apple App Store Connect:
- **App Name:** WalkWise (30 characters max)
- **Subtitle:** "Guided Walking Tours" (30 characters max)
- **Description:** Use content from `APP_STORE_RELEASE_NOTES_v1.0.0.md`
- **Keywords:** walking, tours, fitness, exploration, cities, guided tours
- **Category:** Travel / Health & Fitness
- **Privacy Policy URL:** `https://gowalkwise.com/privacy-policy/` ✅
- **Support URL:** `https://gowalkwise.com/support` ⚠️ **NEEDED**  [Done]
- **Marketing URL:** Optional  [Use main website gowalkwise.com]

#### Google Play Console:
- **App Name:** WalkWise (50 characters max)
- **Short Description:** 80 characters max
- **Full Description:** Use content from `APP_STORE_RELEASE_NOTES_v1.0.0.md`
- **Category:** Travel & Local / Health & Fitness
- **Privacy Policy URL:** `https://gowalkwise.com/privacy-policy/` ✅
- **Support URL:** `https://gowalkwise.com/support` ⚠️ **NEEDED**  [Done]

---

## Privacy Policy

### ✅ **COMPLETED**

**Status:** ✅ Privacy policy created and uploaded

**Location:** `https://gowalkwise.com/privacy-policy/`

**Requirements:**
- ✅ Publicly accessible URL
- ✅ Explains what data is collected (Firebase Auth, step tracking, tour progress)
- ✅ Explains how data is used
- ✅ Explains data sharing (Firebase)
- ✅ Explains user rights

**Remaining Tasks:**
- [ ] Add privacy policy link to create account pages (website)
- [ ] Add privacy policy link in the app (settings or onboarding)
[Need to verify all the appropriate account management services are available via the app using the gamesafoot.co website]
---

## Permissions & Capabilities

### iOS Permissions (Info.plist)
✅ Already configured:
- `NSHealthShareUsageDescription` - Step tracking
- `NSHealthUpdateUsageDescription` - Step tracking
- `NSMotionUsageDescription` - Motion sensors

### Android Permissions (AndroidManifest.xml)
✅ Already configured:
- `ACTIVITY_RECOGNITION` - Step tracking
- `READ_STEPS` - Health Connect
- `FOREGROUND_SERVICE` - Background step tracking
- `POST_NOTIFICATIONS` - Notifications

### iOS Capabilities
✅ HealthKit enabled in `Runner.entitlements`

---

## Version Information

### Current Version
- **Version:** 1.0.0
- **Build Number:** 1
- **Status:** ✅ Correct and consistent

---

## Testing Checklist

Before submission, verify:
- [x] App builds in release mode (Android)
- [x] App builds in release mode (iOS)
- [ ] Release signing works (Android)
- [x] Firebase authentication works
- [x] Step tracking works
- [x] Tour navigation works
- [x] Location images load
- [x] Fun facts display
- [x] Tour resumption works
- [x] No crashes in release builds
- [x] Permissions request properly
- [x] App works on both platforms

---

## App Store Review Considerations

### Apple App Store
- **Review Time:** Typically 24-48 hours
- **Common Rejection Reasons:**
  - Missing privacy policy
  - Incomplete app functionality
  - Missing required metadata
  - App crashes during review
  - Incomplete permission descriptions

### Google Play
- **Review Time:** Typically 1-7 days
- **Common Rejection Reasons:**
  - Missing privacy policy
  - Incomplete app functionality
  - Policy violations
  - Missing required metadata

---

## Firebase Rules Check

### ⚠️ Verify Firestore Security Rules

Since both apps share Firebase project, ensure rules allow:
- WalkWise users to access their own data
- Agatha users to access their own data
- No cross-app data access

**Check:** `agatha/firebase/firestore.rules` (or walkwise equivalent)
[Done]

---

## Pre-Submission Steps

### 1. Android Release Build
```bash
cd walkwise
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### 2. iOS Release Build
```bash
cd walkwise/ios
# Open in Xcode, archive, and create .ipa
# Or use: flutter build ipa --release
```

### 3. Test Release Builds
- Install release builds on physical devices
- Test all critical functionality
- Verify no debug code/logging in release

### 4. Prepare Store Assets
- Screenshots
- App icons
- Privacy policy URL
- Support contact information

---

## Post-Submission

### After Submission:
1. Monitor App Store Connect / Google Play Console for review status
2. Respond promptly to any review questions
3. Be ready to provide additional information if requested
4. Monitor crash reports (Firebase Crashlytics if enabled)

---

## Important Notes

### Preserving Agatha
- ✅ Different bundle IDs ensure no conflicts
- ✅ Same Firebase project is fine (data separated by app)
- ✅ Same developer account is fine
- ⚠️ Make sure Firebase rules don't accidentally break Agatha  [Done]
- ⚠️ Test Agatha still works after WalkWise submission  [Done]

### Using Same GamesAfoot Account
- ✅ This is the correct approach
- ✅ Both apps will appear under same developer account
- ✅ Users can see both apps from same developer
- ✅ Easier to manage updates and support

---

## Quick Reference

| Item | WalkWise | Agatha | Status |
|------|----------|--------|--------|
| Android Package | `com.gowalkwise.walkwise` | `com.GoAgatha.agatha` | ✅ Unique |
| iOS Bundle ID | `com.gowalkwise.walkwise` | `com.johncannon.agatha` | ✅ Unique |
| Firebase Project | `agatha-923ce` | `agatha-923ce` | ✅ Shared OK |
| Release Signing | ⚠️ Setup started | ✅ Configured | ⚠️ **COMPLETE SETUP** |
| Version | 1.0.0+1 | 1.1.1+46 | ✅ Correct |
| Privacy Policy | ✅ `gowalkwise.com/privacy-policy/` | ✅ Has URL | ✅ Complete |
| Support URL | ⚠️ Need page | ✅ Has page | ⚠️ **NEEDED** |  [DONE]
| Support Email | ⚠️ Need address | ✅ Has address | ⚠️ **NEEDED** |  [DONE]
| Instructions Page | ⚠️ Need page | ✅ Has page | ⚠️ **NEEDED** |  [Done]

---

## Website & Support Requirements

### ⚠️ **REQUIRED for App Store Submission**

**Support Email:**
- [x] Create `support@gowalkwise.com` email address
- [x] Set up email forwarding or mailbox
- [x] Test email delivery

**Support Page:**
- [x] Create `gowalkwise.com/support` page with contact form
- [x] Include support email address on page
- [x] Make page accessible and functional
- [x] Test form submission

**Privacy Policy Links:**
- [x] Add privacy policy link to create account pages (website)
- [x] Add privacy policy link in app (settings + login)
- [ ] Verify links work correctly

**Player Instructions:**
- [x] Create player instructions page on website (e.g., `gowalkwise.com/instructions`)
- [x] Include how to play, getting started guide, FAQs
- [x] Add link to instructions page in app (settings + login)
- [x] Ensure instructions are clear and comprehensive

**Terms of Service:**
- [x] Create Terms of Service page on website (e.g., `gowalkwise.com/terms-of-service/`)
- [x] Add Terms of Service link in app (settings + login)

**Account Management Links (Login):**
- [x] Create Account → `gamesafoot.co/create-account`
- [x] Forgot Password → in-app password reset email (Firebase)

---

## Next Steps (Priority Order)

1. **🔴 CRITICAL:** Set up Android release signing  [Done but not tested yet]
2. **🔴 CRITICAL:** Create support email and support page  [Done]
3. **🟡 IMPORTANT:** Add privacy policy links (website and app)  [Done]
4. **🟡 IMPORTANT:** Create player instructions page and link in app  [Done]
5. **🟡 IMPORTANT:** Register bundle ID in App Store Connect  [Coming up]
6. **🟡 IMPORTANT:** Create app listing in Google Play Console  [Coming up]
7. **🟡 IMPORTANT:** Prepare screenshots and assets  [Done]
8. **🟢 NICE TO HAVE:** Test release builds thoroughly  [Done]
9. **🟢 NICE TO HAVE:** Verify Firebase rules  [Done]

---

**Last Updated:** Based on current codebase state  
**Version:** 1.0.0  
**Build:** 1

