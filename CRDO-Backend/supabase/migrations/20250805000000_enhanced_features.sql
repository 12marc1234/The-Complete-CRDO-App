-- Enhanced Backend Features Migration
-- This migration adds support for achievements, city builder, leaderboards, and enhanced user profiles

-- Add bio field to user profiles (using user_metadata)
-- Note: We'll handle this in the Edge Functions since we can't modify auth.users directly

-- Enhanced achievements table
CREATE TABLE IF NOT EXISTS user_achievements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id TEXT NOT NULL, -- e.g., "first_run", "5k_runner"
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL, -- "distance", "speed", "consistency", "social", "special"
  icon TEXT NOT NULL,
  is_unlocked BOOLEAN DEFAULT FALSE,
  progress DECIMAL(5,2) DEFAULT 0.0, -- 0.0 to 1.0
  target_value INTEGER,
  current_value INTEGER DEFAULT 0,
  unlocked_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, achievement_id)
);

-- City buildings table
CREATE TABLE IF NOT EXISTS user_cities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  buildings JSONB DEFAULT '[]',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Leaderboards table
CREATE TABLE IF NOT EXISTS leaderboards (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  timeframe TEXT NOT NULL, -- "weekly", "monthly", "all_time"
  total_distance DECIMAL(10,2) DEFAULT 0,
  total_runs INTEGER DEFAULT 0,
  average_pace DECIMAL(10,2) DEFAULT 0,
  points INTEGER DEFAULT 0,
  rank INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, timeframe)
);

-- Daily progress table
CREATE TABLE IF NOT EXISTS daily_progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  seconds_completed INTEGER DEFAULT 0,
  minutes_goal INTEGER DEFAULT 15,
  gems_earned INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, date)
);

-- Route coordinates table
CREATE TABLE IF NOT EXISTS run_routes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  run_id UUID REFERENCES runs(id) ON DELETE CASCADE,
  coordinates JSONB NOT NULL, -- Array of {lat, lng} coordinates
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE run_routes ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for user_achievements
CREATE POLICY "Users can view their own achievements" ON user_achievements
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own achievements" ON user_achievements
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own achievements" ON user_achievements
  FOR UPDATE USING (auth.uid() = user_id);

-- Service role policies for achievements
CREATE POLICY "Service role can manage achievements" ON user_achievements
  FOR ALL USING (auth.role() = 'service_role');

-- Create RLS policies for user_cities
CREATE POLICY "Users can view their own city" ON user_cities
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own city" ON user_cities
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own city" ON user_cities
  FOR UPDATE USING (auth.uid() = user_id);

-- Service role policies for cities
CREATE POLICY "Service role can manage cities" ON user_cities
  FOR ALL USING (auth.role() = 'service_role');

-- Create RLS policies for leaderboards
CREATE POLICY "Users can view leaderboards" ON leaderboards
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own leaderboard entries" ON leaderboards
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own leaderboard entries" ON leaderboards
  FOR UPDATE USING (auth.uid() = user_id);

-- Service role policies for leaderboards
CREATE POLICY "Service role can manage leaderboards" ON leaderboards
  FOR ALL USING (auth.role() = 'service_role');

-- Create RLS policies for daily_progress
CREATE POLICY "Users can view their own daily progress" ON daily_progress
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own daily progress" ON daily_progress
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own daily progress" ON daily_progress
  FOR UPDATE USING (auth.uid() = user_id);

-- Service role policies for daily_progress
CREATE POLICY "Service role can manage daily progress" ON daily_progress
  FOR ALL USING (auth.role() = 'service_role');

-- Create RLS policies for run_routes
CREATE POLICY "Users can view their own run routes" ON run_routes
  FOR SELECT USING (auth.uid() = (SELECT user_id FROM runs WHERE id = run_routes.run_id));

CREATE POLICY "Users can insert their own run routes" ON run_routes
  FOR INSERT WITH CHECK (auth.uid() = (SELECT user_id FROM runs WHERE id = run_routes.run_id));

-- Service role policies for run_routes
CREATE POLICY "Service role can manage run routes" ON run_routes
  FOR ALL USING (auth.role() = 'service_role');

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement_id ON user_achievements(achievement_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_category ON user_achievements(category);
CREATE INDEX IF NOT EXISTS idx_user_cities_user_id ON user_cities(user_id);
CREATE INDEX IF NOT EXISTS idx_leaderboards_user_id ON leaderboards(user_id);
CREATE INDEX IF NOT EXISTS idx_leaderboards_timeframe ON leaderboards(timeframe);
CREATE INDEX IF NOT EXISTS idx_leaderboards_points ON leaderboards(points);
CREATE INDEX IF NOT EXISTS idx_daily_progress_user_id ON daily_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_progress_date ON daily_progress(date);
CREATE INDEX IF NOT EXISTS idx_run_routes_run_id ON run_routes(run_id);

-- Note: Achievements will be created dynamically by the getUserAchievements function
-- when a user first accesses their achievements 