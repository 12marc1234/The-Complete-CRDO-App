# CRDO Backend Integration Setup

This guide will help you set up the integration between the CRDO iOS app and the Supabase backend.

## Prerequisites

1. **Supabase CLI** - Install from https://supabase.com/docs/guides/cli
2. **Docker Desktop** - Required for local development
3. **Node.js** - For local development

## Setup Steps

### 1. Start Local Supabase

Navigate to the backend directory and start the local Supabase instance:

```bash
cd ../CRDO-Backend-main
supabase start
```

This will start:
- Local PostgreSQL database on port 54322
- Supabase API on port 54321
- Edge Functions on port 54321/functions/v1

### 2. Update Backend Configuration

In `CRDO/BackendConfig.swift`, update the development URL:

```swift
static let developmentBaseURL = "http://127.0.0.1:54321/functions/v1"
```

### 3. Test Backend Health

You can test if the backend is running by making a health check request:

```bash
curl http://127.0.0.1:54321/functions/v1/health
```

### 4. Test Authentication

Test the signup endpoint:

```bash
curl -X POST http://127.0.0.1:54321/functions/v1/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

### 5. Update iOS App Configuration

1. **Network Service**: The `NetworkService.swift` is already configured to work with the Supabase endpoints
2. **Data Manager**: The `DataManager.swift` handles authentication and data synchronization
3. **Authentication**: The `AuthenticationView` now uses Supabase authentication

### 6. Test the Integration

1. Build and run the iOS app
2. Try to sign up with a new account
3. Test the running functionality
4. Check that data is being saved to the local Supabase database

## API Endpoints

The app now uses these Supabase Edge Functions:

- **POST** `/signup` - Create new user account
- **POST** `/login` - Authenticate user
- **POST** `/logout` - Sign out user
- **POST** `/startRun` - Start a new running session
- **POST** `/finishRun` - Complete a running session
- **GET** `/getUserStats` - Get user statistics
- **GET** `/getDashboard` - Get dashboard data
- **POST** `/sendFriendRequest` - Send friend request
- **POST** `/respondToFriendRequest` - Accept/reject friend request
- **GET** `/getFriends` - Get friends list
- **POST** `/speedValidation` - Validate run data
- **GET** `/health` - Health check

## Data Flow

1. **User Registration/Login**: Uses Supabase authentication
2. **Run Tracking**: 
   - Start run → Creates run record in database
   - Finish run → Updates run data, processes streaks, checks achievements
3. **Data Sync**: App fetches user stats and dashboard data from backend
4. **Social Features**: Friend requests and management through Supabase

## Troubleshooting

### Common Issues

1. **Backend not accessible**: Make sure Supabase is running with `supabase status`
2. **Authentication errors**: Check that the JWT token is being sent correctly
3. **Data not syncing**: Verify the API endpoints are working with curl

### Debug Commands

```bash
# Check Supabase status
supabase status

# View logs
supabase logs

# Reset database
supabase db reset

# Test functions
supabase functions serve --env-file ./supabase/.env --no-verify-jwt
```

## Production Deployment

When ready for production:

1. Create a Supabase project at https://supabase.com
2. Deploy the functions: `supabase functions deploy`
3. Update the production URLs in `BackendConfig.swift`
4. Update the iOS app to use production environment

## Security Notes

- All endpoints require JWT authentication (except signup/login)
- Row Level Security (RLS) is enabled on all tables
- Users can only access their own data
- Anti-cheating validation is built into the speed validation endpoint 