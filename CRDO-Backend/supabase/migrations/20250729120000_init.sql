-- Create the runs table
CREATE TABLE IF NOT EXISTS runs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  distance_miles DECIMAL(10,2),
  duration_s DECIMAL(10,2), -- in seconds
  average_speed_mph DECIMAL(10,2),
  peak_speed_mph DECIMAL(10,2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  gems_earned INTEGER DEFAULT 0,
  is_flagged BOOLEAN DEFAULT FALSE
);

-- Create the streaks table
CREATE TABLE IF NOT EXISTS streaks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  last_run_date DATE,
  freeze_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create the achievements table
CREATE TABLE IF NOT EXISTS achievements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  gems_balance INTEGER DEFAULT 0,
  description TEXT,
  points INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, description)
);

-- Create the friends table
CREATE TABLE IF NOT EXISTS friends (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  friend_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'blocked'
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  responded_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

-- Create the crdo_backend table for aggregated user data
CREATE TABLE IF NOT EXISTS crdo_backend (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  users INTEGER DEFAULT 0,
  runs TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  streaks INTEGER DEFAULT 0,
  friends JSONB DEFAULT '{}',
  achievements JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE crdo_backend ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Runs table policies
CREATE POLICY "Users can view their own runs" ON runs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own runs" ON runs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own runs" ON runs
  FOR UPDATE USING (auth.uid() = user_id);

-- Streaks table policies
CREATE POLICY "Users can view their own streaks" ON streaks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own streaks" ON streaks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own streaks" ON streaks
  FOR UPDATE USING (auth.uid() = user_id);

-- Service role policies for streaks (for Edge Functions)
CREATE POLICY "Service role can view streaks" ON streaks
  FOR SELECT USING (auth.role() = 'service_role');

CREATE POLICY "Service role can insert streaks" ON streaks
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Service role can update streaks" ON streaks
  FOR UPDATE USING (auth.role() = 'service_role');

-- Achievements table policies
CREATE POLICY "Users can view their own achievements" ON achievements
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own achievements" ON achievements
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Friends table policies
CREATE POLICY "Users can view their own friend relationships" ON friends
  FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "Users can insert their own friend requests" ON friends
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own friend relationships" ON friends
  FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- CRDO backend table policies (admin only)
CREATE POLICY "Admin can view crdo data" ON crdo_backend
  FOR SELECT USING (auth.role() = 'service_role');

CREATE POLICY "Admin can insert crdo data" ON crdo_backend
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Admin can update crdo data" ON crdo_backend
  FOR UPDATE USING (auth.role() = 'service_role');

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_runs_user_id ON runs(user_id);
CREATE INDEX IF NOT EXISTS idx_runs_started_at ON runs(started_at);
CREATE INDEX IF NOT EXISTS idx_runs_is_flagged ON runs(is_flagged);
CREATE INDEX IF NOT EXISTS idx_streaks_user_id ON streaks(user_id);
CREATE INDEX IF NOT EXISTS idx_achievements_user_id ON achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_friends_user_id ON friends(user_id);
CREATE INDEX IF NOT EXISTS idx_friends_friend_id ON friends(friend_id);
CREATE INDEX IF NOT EXISTS idx_friends_status ON friends(status);
