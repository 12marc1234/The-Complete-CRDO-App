# 🚀 CRDO App Deployment Guide

## 📋 Pre-Deployment Checklist

### ✅ App Status: 95% Ready for TestFlight

**What's Working:**
- ✅ All core features functional
- ✅ Threading issues fixed
- ✅ UI/UX polished and modern
- ✅ Real backend integration ready
- ✅ Authentication system implemented
- ✅ Data persistence working
- ✅ Recent runs scrolling fixed
- ✅ Most recent runs at top

**Remaining 5%:**
- 🔄 Real Supabase backend deployment
- 🔄 Production URL configuration
- 🔄 Final testing with real backend

---

## 🎯 Step 1: Supabase Setup (5 minutes)

### 1.1 Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Click "New Project"
3. Choose your organization
4. Enter project name: `CRDO-App`
5. Set database password (save this!)
6. Choose region (closest to your users)
7. Click "Create new project"

### 1.2 Get Project URLs
1. In your Supabase dashboard, go to Settings → API
2. Copy these URLs:
   - **Project URL**: `https://your-project-ref.supabase.co`
   - **API Key**: `your-anon-key`

### 1.3 Update App Configuration
1. Open `CRDO-Frontend/CRDO/BackendConfig.swift`
2. Replace the placeholder URLs:
   ```swift
   static let productionBaseURL = "https://your-project-ref.supabase.co/functions/v1"
   static let productionWebSocketURL = "wss://your-project-ref.supabase.co"
   ```
3. Change environment to production:
   ```swift
   static let currentEnvironment: Environment = .production
   ```

---

## 🎯 Step 2: Deploy Backend (10 minutes)

### 2.1 Install Supabase CLI
```bash
npm install -g supabase
```

### 2.2 Login to Supabase
```bash
supabase login
```

### 2.3 Link Project
```bash
cd CRDO-Backend
supabase link --project-ref YOUR_PROJECT_REF
```

### 2.4 Deploy Functions
```bash
supabase functions deploy
```

### 2.5 Push Database Schema
```bash
supabase db push
```

---

## 🎯 Step 3: Test Real Backend (15 minutes)

### 3.1 Test Authentication
- [ ] Test user registration
- [ ] Test user login
- [ ] Test logout
- [ ] Test guest mode

### 3.2 Test Core Features
- [ ] Test workout creation
- [ ] Test data persistence
- [ ] Test route tracking
- [ ] Test achievements
- [ ] Test gems system

### 3.3 Test on Physical Device
- [ ] Test on your iPhone
- [ ] Test location services
- [ ] Test background tracking

---

## 🎯 Step 4: App Store Connect Setup (5 minutes)

### 4.1 Create App Record
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps" → "+" → "New App"
3. Fill in details:
   - **Platform**: iOS
   - **Name**: CRDO
   - **Bundle ID**: `com.marcuslee.CRDO`
   - **SKU**: `CRDO001`
   - **User Access**: Full Access

### 4.2 App Information
1. **App Name**: CRDO
2. **Subtitle**: Run, Track, Achieve
3. **Keywords**: running, fitness, tracking, achievements
4. **Description**: 
   ```
   CRDO is your ultimate running companion. Track your runs, earn achievements, and build your running city. Features include:
   
   • GPS route tracking with detailed maps
   • Achievement system with unlockable rewards
   • Running streak tracking
   • Gem rewards for completing runs
   • Beautiful city-building progress
   • Social features with friends
   • Metric/Imperial unit support
   ```

---

## 🎯 Step 5: Build for TestFlight (5 minutes)

### 5.1 Archive App
1. In Xcode, select "Any iOS Device" as target
2. Product → Archive
3. Wait for archive to complete

### 5.2 Upload to App Store Connect
1. In Organizer, select your archive
2. Click "Distribute App"
3. Choose "App Store Connect"
4. Follow the upload process

### 5.3 Submit for TestFlight
1. In App Store Connect, go to TestFlight tab
2. Add internal testers (yourself)
3. Submit for Beta App Review (if needed)

---

## 🎯 Step 6: Production Deployment (Optional)

### 6.1 App Store Submission
1. Complete all app metadata
2. Add screenshots and app preview
3. Submit for App Review
4. Wait for approval (1-7 days)

### 6.2 Marketing Materials
- [ ] App icon (1024x1024)
- [ ] Screenshots for all device sizes
- [ ] App preview video (optional)
- [ ] Privacy policy
- [ ] Terms of service

---

## 🚨 Troubleshooting

### Common Issues:

**1. Build Errors**
```bash
# Clean build folder
Product → Clean Build Folder
# Reset derived data
Window → Projects → Click arrow next to derived data
```

**2. Supabase Connection Issues**
```bash
# Check if functions are deployed
supabase functions list
# Redeploy if needed
supabase functions deploy
```

**3. Location Services Not Working**
- Ensure location permissions are granted
- Test on physical device (not simulator)
- Check Info.plist has location usage descriptions

**4. TestFlight Upload Issues**
- Ensure bundle identifier matches App Store Connect
- Check signing certificates
- Verify app version and build numbers

---

## 📊 Monitoring & Analytics

### 1. Supabase Dashboard
- Monitor function calls
- Check database performance
- Review authentication logs

### 2. App Store Connect
- Track TestFlight usage
- Monitor crash reports
- Review user feedback

### 3. Performance Monitoring
- Add crash reporting (Crashlytics)
- Monitor app performance
- Track user engagement

---

## 🎉 Success Metrics

**Ready for TestFlight when:**
- [ ] All features working with real backend
- [ ] No critical crashes
- [ ] Location services working
- [ ] Data persistence confirmed
- [ ] UI/UX polished
- [ ] Performance acceptable

**Ready for App Store when:**
- [ ] TestFlight feedback positive
- [ ] All metadata complete
- [ ] Screenshots and preview ready
- [ ] Privacy policy and terms added
- [ ] App review guidelines met

---

## ⚡ Quick Commands

```bash
# Deploy everything
cd CRDO-Backend
supabase functions deploy
supabase db push

# Build for TestFlight
cd ../CRDO-Frontend
xcodebuild -project CRDO.xcodeproj -scheme CRDO -configuration Release -archivePath CRDO.xcarchive archive

# Upload to TestFlight
xcodebuild -exportArchive -archivePath CRDO.xcarchive -exportOptionsPlist exportOptions.plist -exportPath ./build
```

**Estimated Time to TestFlight: 30 minutes**
**Estimated Time to App Store: 1-2 weeks** 