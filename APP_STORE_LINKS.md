# WalkWise App Store Links

## Google Play Store Links

### Production (Live)
```
https://play.google.com/store/apps/details?id=com.gowalkwise.walkwise
```

### Testing Track (if needed)
```
https://play.google.com/apps/testing/com.gowalkwise.walkwise
```

**Package Name:** `com.gowalkwise.walkwise`

---

## Apple App Store Links

### Production (Live) - Format
```
https://apps.apple.com/app/id[APP_ID]
```

**OR** (with app name):
```
https://apps.apple.com/us/app/walkwise/id[APP_ID]
```

**Bundle ID:** `com.gowalkwise.walkwise`

**Note:** You'll need to get the App Store ID number from App Store Connect after Apple approves the app. The ID will be in the URL when you view your app in App Store Connect, or you can find it in the App Information section.

**How to find your App Store ID:**
1. Go to App Store Connect
2. Select your WalkWise app
3. Go to **App Information**
4. The App ID will be displayed (it's a numeric ID like `6752580602`)

---

## For Get-The-App Page

### Google Play Store Button
```html
<a href="https://play.google.com/store/apps/details?id=com.gowalkwise.walkwise" 
   class="download-btn android-btn" 
   target="_blank" 
   rel="noopener noreferrer">
    Download from Google Play
</a>
```

### Apple App Store Button (Update after approval)
```html
<a href="https://apps.apple.com/app/id[APP_ID]" 
   class="download-btn ios-btn" 
   id="walkwise-ios-link">
    Download on the App Store
</a>
```

**Replace `[APP_ID]` with your actual App Store ID once Apple approves the app.**

---

## Quick Reference

| Platform | Package/Bundle ID | Link Format |
|----------|------------------|--------------|
| **Google Play** | `com.gowalkwise.walkwise` | `https://play.google.com/store/apps/details?id=com.gowalkwise.walkwise` |
| **App Store** | `com.gowalkwise.walkwise` | `https://apps.apple.com/app/id[APP_ID]` (get ID from App Store Connect) |

---

## Next Steps

1. ✅ **Google Play:** Link is ready - app is approved
2. ⏳ **App Store:** Wait for Apple approval, then:
   - Get the App Store ID from App Store Connect
   - Update the link in your get-the-app page
   - Replace `[APP_ID]` in the link above

---

## Example: Agatha's Links (for reference)

- **Google Play:** `https://play.google.com/apps/testing/com.GoAgatha.agatha` (testing)
- **App Store:** `https://apps.apple.com/app/id6752580602`

You can use these as a template for WalkWise's links once you have the App Store ID.

