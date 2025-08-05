# CRDO Integration Testing Guide

## 🎯 **Testing Overview**

This guide will help you test the complete integration between the CRDO iOS app and the Supabase backend.

## 📱 **iOS Simulator Testing**

### **Current Status: ✅ APP IS RUNNING**
- The CRDO app is currently running in the iPhone 16 simulator
- Backend is running on `http://127.0.0.1:54321`
- All API endpoints are available

### **How to Test in Simulator:**

1. **Authentication Testing:**
   - Open the app in simulator
   - Try to sign up with a new email
   - Try to login with existing credentials
   - Check if authentication tokens are stored

2. **Running Features:**
   - Start a new run
   - Check if run data is sent to backend
   - End the run and verify data upload
   - Check if stats are updated

3. **Offline Mode:**
   - Turn off network in simulator
   - Try to start/end a run
   - Verify data is stored locally
   - Reconnect and check sync

## 🔧 **Backend API Testing**

### **Test Commands:**

```bash
# 1. Test Health Endpoint
curl http://127.0.0.1:54321/functions/v1/health

# 2. Test Signup
curl -X POST http://127.0.0.1:54321/functions/v1/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# 3. Test Login
curl -X POST http://127.0.0.1:54321/functions/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# 4. Test Start Run (with auth token)
curl -X POST http://127.0.0.1:54321/functions/v1/startRun \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# 5. Test Finish Run
curl -X POST http://127.0.0.1:54321/functions/v1/finishRun \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"runId":"RUN_ID","distance":3.2,"duration":1200,"averageSpeed":9.6,"peakSpeed":12.0}'
```

## 📊 **What to Look For**

### **✅ Success Indicators:**

1. **Authentication:**
   - User can sign up/login
   - Tokens are stored locally
   - Session persists between app launches

2. **Running Features:**
   - Run data uploads to backend
   - Stats are updated in real-time
   - Offline data syncs when reconnected

3. **UI Integration:**
   - Network status indicator shows correct state
   - Loading states work properly
   - Error messages are displayed appropriately

### **❌ Common Issues:**

1. **Authentication Failures:**
   - Check if Supabase is running
   - Verify email format
   - Check network connectivity

2. **API Errors:**
   - Verify token format in requests
   - Check CORS headers
   - Ensure proper JSON formatting

3. **UI Issues:**
   - Check if Combine cancellables are properly managed
   - Verify @StateObject vs @State usage
   - Ensure proper error handling

## 🐛 **Debugging Tips**

### **iOS App Debugging:**
```swift
// Add to DataManager for debugging
print("🔗 Network Request: \(endpoint.path)")
print("📱 Response: \(response)")

// Add to NetworkService for debugging
print("🌐 Making request to: \(url)")
print("📤 Request body: \(String(data: body ?? Data(), encoding: .utf8) ?? "")")
```

### **Backend Debugging:**
```bash
# Check Supabase logs
supabase logs

# Check function logs
supabase functions logs startRun
```

## 🚀 **Next Steps**

1. **Test Complete User Flow:**
   - Sign up → Login → Start Run → End Run → View Stats

2. **Test Edge Cases:**
   - Network failures
   - Invalid data
   - Token expiration

3. **Performance Testing:**
   - Multiple concurrent requests
   - Large data uploads
   - Memory usage

## 📝 **Test Results Template**

```
Date: _________
Tester: _________

✅ Authentication:
- [ ] Sign up works
- [ ] Login works  
- [ ] Token persistence works

✅ Running Features:
- [ ] Start run works
- [ ] End run works
- [ ] Data uploads to backend
- [ ] Stats update correctly

✅ Offline Mode:
- [ ] App works offline
- [ ] Data syncs when reconnected
- [ ] No data loss

✅ UI/UX:
- [ ] Loading states work
- [ ] Error messages clear
- [ ] Network indicator accurate

Issues Found: _________
Next Actions: _________
```

## 🎉 **Success Criteria**

The integration is successful when:
1. ✅ App builds without errors
2. ✅ App runs in simulator
3. ✅ Authentication works end-to-end
4. ✅ Run data uploads to backend
5. ✅ Offline functionality works
6. ✅ UI responds appropriately to network state

**Current Status: ✅ READY FOR TESTING** 