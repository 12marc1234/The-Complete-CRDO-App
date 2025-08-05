import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client with service role key for admin access
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get all users from auth.users table
    const { data: users, error } = await supabase.auth.admin.listUsers()

    if (error) {
      console.error('Error fetching users:', error)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch users', details: error.message }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get additional user data from our custom tables
    const { data: userStats, error: statsError } = await supabase
      .from('runs')
      .select('user_id, distance_miles, duration_s, started_at')
      .order('started_at', { ascending: false })

    const { data: userStreaks, error: streaksError } = await supabase
      .from('streaks')
      .select('user_id, current_streak, longest_streak, last_run_date')

    // Combine user data with stats
    const enrichedUsers = users.users.map(user => {
      const userRuns = userStats?.filter(run => run.user_id === user.id) || []
      const userStreak = userStreaks?.find(streak => streak.user_id === user.id)
      
      const totalRuns = userRuns.length
      const totalDistance = userRuns.reduce((sum, run) => sum + (run.distance_miles || 0), 0)
      const totalDuration = userRuns.reduce((sum, run) => sum + (run.duration_s || 0), 0)
      const lastRun = userRuns.length > 0 ? userRuns[0].started_at : null

      return {
        id: user.id,
        email: user.email,
        created_at: user.created_at,
        last_sign_in_at: user.last_sign_in_at,
        email_confirmed_at: user.email_confirmed_at,
        stats: {
          total_runs: totalRuns,
          total_distance_miles: totalDistance,
          total_duration_seconds: totalDuration,
          last_run: lastRun,
          current_streak: userStreak?.current_streak || 0,
          longest_streak: userStreak?.longest_streak || 0,
          last_run_date: userStreak?.last_run_date
        }
      }
    })

    return new Response(
      JSON.stringify({ 
        users: enrichedUsers,
        total_users: enrichedUsers.length,
        timestamp: new Date().toISOString()
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
}) 