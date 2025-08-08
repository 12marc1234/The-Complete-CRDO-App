# Quick TestFlight Upload Guide

## 🚀 Step-by-Step Process

### 1. Deploy Backend (5 minutes)
```bash
cd CRDO-Backend
./DEPLOY_TO_PRODUCTION.sh YOUR_PROJECT_REF
```

### 2. Update App Configuration (2 minutes)
1. Open `CRDO-Frontend/CRDO/BackendConfig.swift`
2. Replace placeholder URLs with your real Supabase URLs
3. Change `currentEnvironment` to `.production`

### 3. Test on Device (10 minutes)
1. Build and run on your iPhone
2. Test sign-up/sign-in
3. Test core features (runs, friends, city)
4. Verify data persistence

### 4. Archive and Upload (5 minutes)

#### Option A: Xcode GUI
1. Open Xcode
2. Select "Any iOS Device" as target
3. Product → Archive
4. Click "Distribute App"
5. Select "App Store Connect"
6. Upload

#### Option B: Command Line
```bash
cd CRDO-Frontend

# Archive the app
xcodebuild -project CRDO.xcodeproj -scheme CRDO -configuration Release -archivePath CRDO.xcarchive archive

# Export for App Store
xcodebuild -exportArchive -archivePath CRDO.xcarchive -exportPath ./build -exportOptionsPlist exportOptions.plist

# Upload to App Store Connect
xcrun altool --upload-app --type ios --file "./build/CRDO.ipa" --username "your-apple-id" --password "app-specific-password"
```

### 5. TestFlight Setup (5 minutes)
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Create new app if needed
3. Upload build
4. Add testers
5. Submit for review

## ⚡ Total Time: ~30 minutes

## 🎯 Success Checklist
- [ ] Backend deployed and working
- [ ] App builds successfully
- [ ] All features tested on device
- [ ] Archive created successfully
- [ ] Uploaded to App Store Connect
- [ ] TestFlight build processing
- [ ] Testers added and notified

## 🚨 Common Issues
- **Build fails**: Check code signing settings
- **Upload fails**: Verify Apple ID credentials
- **App crashes**: Test on device before uploading
- **Backend errors**: Check Supabase project configuration

## 📞 Need Help?
- Check the comprehensive `TESTFLIGHT_DEPLOYMENT.md` for detailed steps
- Review `COMPREHENSIVE_BUG_FIXES.md` for known issues
- Test thoroughly before uploading 