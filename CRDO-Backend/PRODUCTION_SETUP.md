# Production Setup Guide

## 1. Supabase Project Setup

### Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Create a new project
3. Note your project URL (e.g., `https://your-project-ref.supabase.co`)

### Update Frontend Configuration
1. Open `CRDO-Frontend/CRDO/BackendConfig.swift`
2. Replace the placeholder URLs with your real Supabase URLs:
   ```swift
   static let productionBaseURL = "https://your-project-ref.supabase.co/functions/v1"
   static let productionWebSocketURL = "wss://your-project-ref.supabase.co"
   ```
3. Change the environment to production:
   ```swift
   static let currentEnvironment: Environment = .production
   ```

## 2. Deploy Backend Functions

### Install Supabase CLI
```bash
npm install -g supabase
```

### Login to Supabase
```bash
supabase login
```

### Link Your Project
```bash
cd CRDO-Backend
supabase link --project-ref your-project-ref
```

### Deploy Functions
```bash
supabase functions deploy
```

## 3. Database Setup

### Run Migrations
```bash
supabase db push
```

### Verify Database Schema
Check that all tables are created:
- users
- workouts
- achievements
- friends
- etc.

## 4. Environment Variables

### Set Required Environment Variables
In your Supabase project dashboard:
1. Go to Settings > API
2. Set up any required environment variables for your functions

## 5. Testing Production

### Test Authentication
1. Build and run the app
2. Try creating a new account
3. Test login/logout functionality
4. Verify data persistence across app restarts

### Test Core Features
1. Start a run
2. Complete a run
3. Check that data is saved to Supabase
4. Verify achievements and stats are working

## 6. App Store Preparation

### Update Bundle Identifier
1. Open Xcode project
2. Change bundle identifier to your production identifier
3. Update team and signing settings

### Update App Icon and Metadata
1. Add your app icon
2. Update app name and description
3. Add privacy policy and terms of service

### Test on Physical Device
1. Test on your iPhone
2. Verify all features work correctly
3. Check performance and battery usage

## 7. Common Issues

### Authentication Issues
- Verify Supabase project URL is correct
- Check that functions are deployed
- Ensure database tables exist

### Data Persistence Issues
- Verify user data isolation
- Check that guest mode works correctly
- Ensure data is properly saved to Supabase

### Network Issues
- Test with different network conditions
- Verify timeout settings
- Check error handling

## 8. Monitoring

### Set Up Logging
- Configure Supabase logging
- Monitor function performance
- Track user analytics

### Error Tracking
- Set up crash reporting
- Monitor API errors
- Track user feedback

## 9. Security Checklist

- [ ] Row Level Security (RLS) enabled
- [ ] API keys properly secured
- [ ] User authentication working
- [ ] Data isolation between users
- [ ] Guest mode properly isolated
- [ ] No sensitive data in client code

## 10. Performance Optimization

- [ ] Optimize database queries
- [ ] Implement caching where appropriate
- [ ] Minimize network requests
- [ ] Optimize app size
- [ ] Test on slower devices 