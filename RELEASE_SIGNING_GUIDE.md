# Android Release Signing Setup Guide

## Overview
This guide will help you create a keystore and configure your app for Play Store release.

## Step 1: Create Your Keystore

### Option A: Using the Provided Script (Easiest)
1. Open Command Prompt in the project root folder
2. Run: `create_keystore.bat`
3. Answer the questions when prompted:
   - **Keystore password**: Choose a strong password (you'll need this!)
   - **Key password**: Can be the same as keystore password
   - **First and last name**: Your name or company name
   - **Organizational unit**: Your team/department (e.g., "Development")
   - **Organization**: Your company/organization name
   - **City**: Your city
   - **State**: Your state/province
   - **Country code**: Two-letter country code (e.g., "US", "FR", "DZ")

### Option B: Manual Command
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## Step 2: Secure Your Keystore

**CRITICAL**: After creating the keystore:

1. **Move the keystore file** to a secure location OUTSIDE your project:
   ```
   Recommended: C:\Users\YourName\keystores\qurani-upload-keystore.jks
   ```

2. **Backup the keystore**:
   - Copy to USB drive
   - Store in cloud storage (encrypted)
   - **NEVER lose this file** - you can't update your app without it!

3. **Save your passwords** in a password manager (LastPass, 1Password, etc.)

## Step 3: Create key.properties File

1. In the `android` folder, create a file named `key.properties`
2. Add this content (replace with YOUR values):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:/Users/YourName/keystores/qurani-upload-keystore.jks
```

**Example**:
```properties
storePassword=MySecurePassword123!
keyPassword=MySecurePassword123!
keyAlias=upload
storeFile=C:/Users/Adam/keystores/qurani-upload-keystore.jks
```

**IMPORTANT**: 
- Use forward slashes `/` in the path, not backslashes `\`
- This file is already in `.gitignore` - it will NOT be committed to Git

## Step 4: Verify Configuration

Run this command to test your release build:
```bash
flutter build appbundle --release
```

If successful, you'll see:
```
✓ Built build/app/outputs/bundle/release/app-release.aab
```

## Step 5: What You'll Upload to Play Store

The file to upload: `build/app/outputs/bundle/release/app-release.aab`

## Troubleshooting

### Error: "Keystore file not found"
- Check the `storeFile` path in `key.properties`
- Use forward slashes `/` not backslashes `\`
- Use absolute path (full path from C:/)

### Error: "Incorrect password"
- Double-check passwords in `key.properties`
- Passwords are case-sensitive

### Error: "Failed to read key"
- Ensure `keyAlias` is exactly "upload" (lowercase)

## Security Checklist

- [ ] Keystore file is stored OUTSIDE the project folder
- [ ] Keystore file is backed up in 2+ locations
- [ ] Passwords are saved in password manager
- [ ] `key.properties` is NOT committed to Git (check `.gitignore`)
- [ ] Never share keystore or passwords with anyone

## Important Notes

1. **One keystore per app**: Use the same keystore for all future updates
2. **Can't recover**: If you lose the keystore, you can't update your app
3. **Keep it secret**: Never commit keystore files to version control
4. **Validity**: Your keystore is valid for 10,000 days (~27 years)

## Next Steps After Setup

1. Build release bundle: `flutter build appbundle --release`
2. Test the .aab file thoroughly
3. Upload to Play Store Console
4. Complete store listing (screenshots, description, etc.)
5. Submit for review

---

**Need Help?** If you encounter issues, check:
- Flutter documentation: https://docs.flutter.dev/deployment/android
- Play Console help: https://support.google.com/googleplay/android-developer
