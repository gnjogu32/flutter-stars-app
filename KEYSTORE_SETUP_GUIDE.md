# Android Release Signing Setup Guide

## Step-by-Step Keystore Generation

### Step 1: Generate Your Release Keystore

Open PowerShell in your project root and run:

```powershell
keytool -genkey -v -keystore android/starpage-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias starpage
```

You'll be prompted for:
```
Enter keystore password: [ENTER A STRONG PASSWORD - WRITE IT DOWN!]
Re-enter new password: [CONFIRM PASSWORD]
What is your first and last name? [Starpage Creator]
What is the name of your organizational unit? [Social Media]
What is the name of your organization? [Starpage Inc.]
What is the name of your City or Locality? [Your City]
What is the name of your State or Province? [Your State]
What is the two-letter country code for this unit? [US]
Is CN=Starpage Creator, OU=Social Media, O=Starpage Inc., L=Your City, ST=Your State, C=US correct? [yes]
```

⚠️ **IMPORTANT: Write down these passwords and save them securely!**

### Step 2: Verify Keystore was Created

```powershell
Test-Path android/starpage-keystore.jks
# Should output: True
```

### Step 3: Set Environment Variables

#### Option A: Temporary (Current PowerShell Session Only)

```powershell
$env:KEYSTORE_PASSWORD = "your_keystore_password_from_step_1"
$env:KEY_PASSWORD = "your_key_password_from_step_1"

# Verify they're set
Write-Host "Keystore Password: $env:KEYSTORE_PASSWORD"
Write-Host "Key Password: $env:KEY_PASSWORD"
```

#### Option B: Permanent (Recommended for Builds)

1. **Open System Environment Variables:**
   - Press `Win + R`
   - Type: `sysdm.cpl`
   - Press Enter
   
2. **Add Environment Variables:**
   - Click "Environment Variables" button
   - Under "User variables for [YourUsername]", click "New"
   - **Variable name:** `KEYSTORE_PASSWORD`
   - **Variable value:** `your_keystore_password`
   - Click OK

3. **Add Second Variable:**
   - Click "New" again
   - **Variable name:** `KEY_PASSWORD`
   - **Variable value:** `your_key_password`
   - Click OK

4. **Restart PowerShell** for changes to take effect

5. **Verify:**
   ```powershell
   $env:KEYSTORE_PASSWORD
   $env:KEY_PASSWORD
   ```

### Step 4: Update build.gradle.kts

File: `android/app/build.gradle.kts`

Find the `signingConfigs` block and update the release configuration:

```kotlin
signingConfigs {
    release {
        storeFile = file("../starpage-keystore.jks")
        storePassword = System.getenv("KEYSTORE_PASSWORD")
        keyAlias = "starpage"
        keyPassword = System.getenv("KEY_PASSWORD")
    }
}
```

⚠️ If you see this, uncomment it first:
```kotlin
// storeFile = file("../starpage-keystore.jks")
// storePassword = System.getenv("KEYSTORE_PASSWORD")
// keyAlias = "starpage"
// keyPassword = System.getenv("KEY_PASSWORD")
```

### Step 5: Verify Signing Configuration

Run this command to test the signing:

```powershell
flutter build apk --release
```

If successful, you'll see:
```
Built build/app/outputs/flutter-release.apk (XX.X MB)
```

---

## Troubleshooting Keystore Issues

### Issue: "Cannot find keystore file"

```powershell
# Check file exists
Test-Path android/starpage-keystore.jks

# If not found, regenerate:
keytool -genkey -v -keystore android/starpage-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias starpage
```

### Issue: "Keystore password incorrect"

The keystore file becomes corrupted. Regenerate:

```powershell
# Remove old keystore
Remove-Item android/starpage-keystore.jks

# Generate new one
keytool -genkey -v -keystore android/starpage-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias starpage
```

**WARNING:** You'll need to upload a new app to Google Play. You cannot update an existing app with a different keystore.

### Issue: "Environment variables not recognized"

```powershell
# Force refresh environment variables
$env:KEYSTORE_PASSWORD = "your_password"
$env:KEY_PASSWORD = "your_password"

# Verify
Get-ChildItem env:KEYSTORE_PASSWORD
Get-ChildItem env:KEY_PASSWORD
```

### Issue: "Signing config reference missing in buildTypes"

Check that your release buildType has:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        minifyEnabled = true
        shrinkResources = true
        // ... rest of config
    }
}
```

---

## Keystore Information & Recovery

### View Your Keystore Details

```powershell
# List all keys in keystore
keytool -list -v -keystore android/starpage-keystore.jks -alias starpage

# You'll need to enter keystore password when prompted
```

### Backup Your Keystore

Create a secure backup:

```powershell
# Copy to external drive or cloud storage
Copy-Item android/starpage-keystore.jks "D:\Backups\starpage-keystore.jks"
```

⚠️ **CRITICAL:** Store backup in a secure location. If you lose this file, you cannot update your app on Google Play.

### Export Certificate Fingerprint (for OAuth/Firebase)

```powershell
keytool -list -v -keystore android/starpage-keystore.jks -alias starpage
```

Look for these values (needed for Firebase/Google Sign-In):
- **SHA1:** Used for Firebase setup
- **SHA-256:** Used for some APIs
- **MD5:** Legacy, generally not needed

Example output:
```
Signature algorithm name: SHA256withRSA
Subject Public Key Info:
    Public Key Algorithm: 2048-bit RSA key
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----

SHA1: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12
SHA-256: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56
```

---

## Security Best Practices

### Do's ✓
- ✓ Store keystore passwords securely (password manager)
- ✓ Backup keystore to encrypted external storage
- ✓ Use strong passwords (15+ characters)
- ✓ Keep keystore file private
- ✓ Use environment variables (never hardcode passwords)

### Don'ts ✗
- ✗ Commit `starpage-keystore.jks` to git
- ✗ Share keystore password with anyone
- ✗ Hardcode password in build.gradle.kts
- ✗ Store password in plain text files
- ✗ Lose the keystore file

### Add to .gitignore

Ensure these are in your `.gitignore`:

```gitignore
# Keystores
*.jks
*.keystore
android/*.jks
android/*.keystore

# Gradle build
build/
.gradle/

# IDE
.idea/
*.iml

# Environment variables (if you create a local config file)
.env
local.properties
```

---

## One-Time Setup Checklist

- [ ] Generate keystore with `keytool`
- [ ] Write down and secure passwords
- [ ] Copy keystore to `android/` directory
- [ ] Set permanent environment variables (Windows System Properties)
- [ ] Update `android/app/build.gradle.kts` with signing config
- [ ] Test build with `flutter build apk --release`
- [ ] Backup keystore securely
- [ ] Verify `.gitignore` includes `*.jks`

After this, you won't need to repeat the setup. Just set env variables and build!

---

## Build Commands After Setup

Once keystore is configured, building is simple:

```powershell
# Build APK
flutter build apk --release

# Build App Bundle (for Google Play)
flutter build appbundle --release

# Clean and rebuild
flutter clean
flutter pub get
flutter build appbundle --release

# Specify version
flutter build appbundle --release --build-name=1.0.1 --build-number=2
```

The signing happens automatically with environment variables set.
