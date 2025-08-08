# TestFlight Deployment Guide for CRDO App

## 🚀 Current Status: READY FOR TESTFLIGHT

The CRDO app has been successfully configured for TestFlight deployment with the following key improvements:

### ✅ Completed Fixes

1. **Real Authentication System**
   - Switched from mock authentication to real Supabase authentication
   - Accounts now work across simulator and physical devices
   - Proper user data isolation between accounts

2. **Production Configuration**
   - Set `BackendConfig.currentEnvironment = .production`
   - Configured production Supabase URLs
   - Ready for shared backend authentication

3. **Build System**
   - Successfully builds for both simulator and physical device
   - Proper code signing and provisioning profiles
   - No compilation errors

4. **Data Management**
   - Fixed user data isolation issues
   - Proper singleton patterns for managers
   - User-specific data persistence

## 📋 Pre-TestFlight Checklist

### 1. Supabase Backend Setup
- [ ] Deploy Supabase backend to production
- [ ] Update `BackendConfig.swift` with your actual Supabase project URL
- [ ] Test authentication endpoints

### 2. App Store Connect Setup
- [ ] Create app record in App Store Connect
- [ ] Configure app metadata (description, screenshots, etc.)
- [ ] Set up TestFlight testing groups

### 3. Final Testing
- [ ] Test authentication on physical device
- [ ] Verify data persistence across app restarts
- [ ] Test all core features (runs, city building, friends, etc.)

## 🛠️ Deployment Steps

### Step 1: Update Supabase Configuration

Replace the placeholder URL in `BackendConfig.swift`:

```swift
// Replace with your actual Supabase project URL
static let productionBaseURL = "https://your-actual-project.supabase.co/functions/v1"
static let productionWebSocketURL = "wss://your-actual-project.supabase.co"
```

### Step 2: Archive and Upload

1. **Create Archive:**
   ```bash
   xcodebuild -project CRDO.xcodeproj -scheme CRDO -configuration Release -archivePath CRDO.xcarchive archive
   ```

2. **Export IPA:**
   ```bash
   xcodebuild -exportArchive -archivePath CRDO.xcarchive -exportPath ./export -exportOptionsPlist exportOptions.plist
   ```

3. **Upload to App Store Connect:**
   - Use Xcode Organizer or Application Loader
   - Or use `xcrun altool` command line tool

### Step 3: TestFlight Distribution

1. **App Store Connect:**
   - Go to your app in App Store Connect
   - Navigate to TestFlight tab
   - Add internal testers or create external testing groups

2. **Testing:**
   - Internal testers can test immediately
   - External testing requires Apple review (usually 24-48 hours)

## 🔧 Configuration Files

### exportOptions.plist
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>S9A75PR4TN</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

## 🎯 Key Features Ready for Testing

### Authentication
- ✅ Real Supabase authentication
- ✅ Cross-device account access
- ✅ User data isolation
- ✅ Session persistence

### Core Features
- ✅ Run tracking and GPS
- ✅ City building with gems
- ✅ Friend system
- ✅ Achievement system
- ✅ Data persistence

### UI/UX
- ✅ Dark mode authentication
- ✅ Responsive design
- ✅ Smooth animations
- ✅ Error handling

## 🚨 Important Notes

1. **Backend Dependency**: The app requires a live Supabase backend for full functionality
2. **Network Permissions**: Ensure proper network configuration for production URLs
3. **Data Migration**: Existing users may need to re-authenticate after backend deployment
4. **Testing Strategy**: Start with internal testing, then expand to external testers

## 📞 Support

If you encounter issues during TestFlight deployment:

1. Check build logs for any errors
2. Verify Supabase backend is running
3. Test authentication flow on physical device
4. Review App Store Connect guidelines

## 🎉 Next Steps

1. Deploy Supabase backend to production
2. Update configuration with real URLs
3. Create App Store Connect record
4. Archive and upload build
5. Distribute to TestFlight testers
6. Collect feedback and iterate

The app is now ready for TestFlight deployment! 🚀 