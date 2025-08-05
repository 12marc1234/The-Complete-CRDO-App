# CRDO Backend Enhancements

## Overview
This document outlines the comprehensive backend enhancements made to support the advanced frontend features including achievements, city builder, enhanced profiles, and daily progress tracking.

## Database Schema Changes

### New Tables Created

#### 1. `user_achievements`
- **Purpose**: Track user achievement progress and unlocks
- **Key Fields**:
  - `achievement_id`: Unique identifier for achievement type
  - `title`, `description`, `category`, `icon`: Achievement metadata
  - `is_unlocked`, `progress`: Achievement status
  - `target_value`, `current_value`: Progress tracking
  - `unlocked_at`: Timestamp when achievement was unlocked

#### 2. `user_cities`
- **Purpose**: Store user's city builder layouts
- **Key Fields**:
  - `buildings`: JSONB array of building data
  - `updated_at`: Last modification timestamp

#### 3. `leaderboards`
- **Purpose**: Track user rankings across different timeframes
- **Key Fields**:
  - `timeframe`: "weekly", "monthly", "all_time"
  - `total_distance`, `total_runs`, `average_pace`: Performance metrics
  - `points`, `rank`: Leaderboard positioning

#### 4. `daily_progress`
- **Purpose**: Track daily running goals and progress
- **Key Fields**:
  - `seconds_completed`: Daily running time
  - `minutes_goal`: Daily target (default 15 minutes)
  - `gems_earned`: Daily gem earnings

#### 5. `run_routes`
- **Purpose**: Store GPS coordinates for run visualization
- **Key Fields**:
  - `coordinates`: JSONB array of lat/lng coordinates
  - `run_id`: Reference to the run

## New Edge Functions

### User Profile Management
1. **`updateUserProfile`** - Update user bio and profile information
2. **`getUserProfile`** - Get detailed user profile with stats and achievements

### Achievements System
3. **`getUserAchievements`** - Get user's achievement progress (creates defaults if none exist)
4. **`updateAchievementProgress`** - Update achievement progress

### City Builder
5. **`saveCity`** - Save user's city layout
6. **`getCity`** - Get user's city layout

### Daily Progress Tracking
7. **`updateDailyProgress`** - Update daily running progress and goals

### Route Tracking
8. **`saveRunRoute`** - Save GPS coordinates for run visualization

### Leaderboards
9. **`getLeaderboards`** - Get leaderboard data for different timeframes

### Enhanced Friend System
10. **`getFriendProfile`** - Get detailed friend profile with stats and achievements

## Enhanced Existing Functions

### `finishRun` Updates
- **Route Saving**: Automatically saves GPS coordinates when provided
- **Daily Progress**: Updates daily progress tracking
- **Achievement Integration**: Updates achievement progress based on run data
- **Enhanced Response**: Returns unlocked achievements and gems earned

## Security & Performance

### Row Level Security (RLS)
- All new tables have RLS enabled
- Service role policies for Edge Functions
- User-specific access controls

### Indexes
- Performance indexes on frequently queried fields
- Composite indexes for leaderboard queries
- Date-based indexes for daily progress

## Achievement System

### Default Achievements
1. **First Steps** - Complete your first run
2. **5K Runner** - Run 5 kilometers in a single session
3. **Speed Demon** - Achieve a pace faster than 7:00 min/mi
4. **Consistency King** - Run 7 days in a row
5. **Social Butterfly** - Add 5 friends
6. **Marathon Ready** - Run 26.2 miles total

### Achievement Categories
- **Distance**: Based on run distance
- **Speed**: Based on pace achievements
- **Consistency**: Based on streaks
- **Social**: Based on friend interactions
- **Special**: Unique achievements

## API Endpoints Summary

### Authentication Required
All endpoints require valid JWT token in Authorization header.

### GET Endpoints
- `GET /functions/v1/getUserProfile` - Get user profile
- `GET /functions/v1/getUserAchievements` - Get achievements
- `GET /functions/v1/getCity` - Get city layout
- `GET /functions/v1/getLeaderboards?timeframe=weekly` - Get leaderboards
- `GET /functions/v1/getFriendProfile?friendId=uuid` - Get friend profile

### POST Endpoints
- `POST /functions/v1/updateUserProfile` - Update profile
- `POST /functions/v1/updateAchievementProgress` - Update achievement
- `POST /functions/v1/saveCity` - Save city layout
- `POST /functions/v1/updateDailyProgress` - Update daily progress
- `POST /functions/v1/saveRunRoute` - Save run route

## Migration Instructions

1. **Apply Database Migration**:
   ```bash
   cd CRDO-Backend
   supabase db reset
   ```

2. **Deploy Edge Functions**:
   ```bash
   supabase functions deploy
   ```

3. **Verify Health Check**:
   ```bash
   curl http://localhost:54321/functions/v1/health
   ```

## Frontend Integration Points

### Profile Updates
- Use `updateUserProfile` to save bio changes
- Use `getUserProfile` to display comprehensive profile data

### Achievements
- Use `getUserAchievements` to display achievement progress
- Use `updateAchievementProgress` for real-time updates

### City Builder
- Use `saveCity` when user saves city layout
- Use `getCity` to load user's city on app start

### Daily Progress
- Use `updateDailyProgress` after each run
- Integrate with existing `GemsManager` for daily goals

### Route Visualization
- Use `saveRunRoute` when finishing a run
- Store coordinates for animated route display

## Error Handling

All functions include comprehensive error handling:
- Input validation
- Authentication checks
- Database error handling
- Proper HTTP status codes
- Detailed error messages

## Performance Considerations

- All functions are under 500 lines for maintainability
- Efficient database queries with proper indexing
- Batch operations where possible
- CORS headers for cross-origin requests
- Comprehensive logging for debugging 