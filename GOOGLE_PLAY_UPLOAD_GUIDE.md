# Google Play Console Upload Guide - WalkWise v1.0.0+2

## Pre-Upload Checklist

### ✅ Completed
- [x] AD_ID permission added to AndroidManifest.xml
- [x] Version bumped to 1.0.0+2
- [x] Release AAB built (`flutter build appbundle --release`)
- [x] Feature graphic created (`feature_graphic_paris.png`)
- [x] Foreground service demo video created (`foreground_service_demo.mp4`)

### 📋 Files Ready
- **Release AAB:** `build/app/outputs/bundle/release/app-release.aab`
- **Feature Graphic:** `assets/images/feature_graphic_paris.png` (1024x500px)
- **Foreground Service Video:** `assets/movie/foreground_service_demo.mp4` (20 seconds)
- **Release Notes:** `APP_STORE_RELEASE_NOTES_v1.0.0.md`
- **Short Description:** `APP_STORE_SHORT_NOTES_v1.0.0.md`

---

## Step-by-Step Upload Process

### 1. Navigate to Closed Testing Release

1. Go to Google Play Console: https://play.google.com/console
2. Select **WalkWise** app
3. In left sidebar: **Test and release** → **Testing** → **Closed testing**
4. Click **Create new release** (or edit existing draft)

### 2. Upload the AAB File

1. In the **Create release** section:
   - Click **Upload** under "App bundles and APKs"
   - Select: `build/app/outputs/bundle/release/app-release.aab`
   - Wait for upload to complete (may take a few minutes)
   - Verify it shows: **Version 1.0.0 (2)**

### 3. Add Release Notes

1. Scroll to **Release notes** section
2. Select language: **English (United States)**
3. Copy content from `APP_STORE_RELEASE_NOTES_v1.0.0.md`:
   ```
   Welcome to WalkWise! Your personal guide to exploring cities on foot.

   Discover amazing locations while you walk:
   • Choose from multiple cities and venues
   • Follow guided walking tours with step-by-step navigation
   • Learn interesting facts about each location as you walk
   • Track your progress with real-time step counting
   • View beautiful location images when you arrive
   • Complete tours at your own pace

   Smart features:
   • Automatic step tracking powered by the Are We There Yet Engine
   • Resume your tour anytime - your progress is saved
   • Interactive route maps to see your journey
   • Fun facts delivered during your walk to keep you engaged

   WalkWise makes exploring new cities fun, active, and educational. Start your walking adventure today!
   ```

### 4. Verify Store Listing (if needed)

1. Go to **Grow users** → **Store presence** → **Store listings**
2. Verify these are set:
   - **App name:** WalkWise
   - **Short description:** (from `APP_STORE_SHORT_NOTES_v1.0.0.md`)
   - **Full description:** (from `APP_STORE_RELEASE_NOTES_v1.0.0.md`)
   - **App icon:** 512x512px (should already be uploaded)
   - **Feature graphic:** Upload `assets/images/feature_graphic_paris.png` if not already done
   - **Category:** Travel & Local / Health & Fitness
   - **Privacy Policy URL:** `https://gowalkwise.com/privacy-policy/`
   - **Support URL:** `https://gowalkwise.com/support`

### 5. Complete Foreground Service Declaration

1. Go to **Test and release** → **App content**
2. Click **Foreground service permissions**
3. Under **Health** section:
   - ✅ Check: "Health data sync, step counter, exercise tracker"
   - **Video link:** Upload `assets/movie/foreground_service_demo.mp4` to YouTube (public or unlisted, no ads)
   - Enter the YouTube URL in the video link field
4. Click **Save**

### 6. Verify Advertising ID Declaration

1. Go to **Test and release** → **App content**
2. Click **Advertising ID**
3. Verify it says: **"Uses advertising ID"** (should match your manifest now)
4. If it says "Doesn't use advertising ID", click **Update declaration** and select "Uses advertising ID"

### 7. Review and Submit

1. Go back to **Closed testing** → **Create release**
2. Scroll to **Review release** section
3. Check for any errors or warnings:
   - ✅ AD_ID permission error should be gone
   - ✅ All required fields should be complete
4. Click **Review release**
5. On the review page:
   - Verify all information is correct
   - Check that version shows: **1.0.0 (2)**
   - Click **Start rollout to Closed testing**

---

## Common Issues & Solutions

### Issue: "AD_ID permission missing" error
**Solution:** ✅ Already fixed - permission added to manifest

### Issue: "Feature graphic too small"
**Solution:** 
- Verify file is exactly 1024x500px
- Try re-uploading `feature_graphic_paris.png`
- Clear browser cache and try again

### Issue: "Version code must be higher"
**Solution:** ✅ Already fixed - bumped to build 2

### Issue: "Foreground service video required"
**Solution:**
- Upload video to YouTube (public or unlisted)
- Make sure ads are disabled
- Make sure video is not age-restricted
- Enter the full YouTube URL (e.g., `https://www.youtube.com/watch?v=...`)

### Issue: "Store listing incomplete"
**Solution:**
- Go to **Store listings** and fill in all required fields
- Make sure feature graphic is uploaded
- Verify privacy policy and support URLs are accessible

---

## Quick Reference: File Locations

```
walkwise/
├── build/app/outputs/bundle/release/app-release.aab  ← Upload this
├── assets/images/feature_graphic_paris.png          ← Feature graphic
├── assets/movie/foreground_service_demo.mp4          ← Upload to YouTube first
├── APP_STORE_RELEASE_NOTES_v1.0.0.md                ← Release notes source
└── APP_STORE_SHORT_NOTES_v1.0.0.md                  ← Short description source
```

---

## After Upload

1. **Wait for processing:** Google Play processes the AAB (usually 10-30 minutes)
2. **Check for errors:** Review any warnings or errors in the release page
3. **Add testers:** If this is closed testing, add testers to your test track
4. **Monitor:** Check the release status in the "Test and release" section

---

## Next Steps After Successful Upload

- [ ] Verify app works correctly in closed testing
- [ ] Collect feedback from testers
- [ ] Fix any critical issues
- [ ] Prepare for production release when ready

---

**Need Help?** When you return, I can help you:
- Navigate any specific errors you encounter
- Update any store listing information
- Troubleshoot upload issues
- Prepare for production release

