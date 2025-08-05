import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    // Get user from auth header
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "").trim();
    
    if (!token) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: { user }, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get all user data in parallel
    const [runs, streak, achievements, friends] = await Promise.all([
      supabase
        .from("runs")
        .select("*")
        .eq("user_id", user.id)
        .order("started_at", { ascending: false }),
      
      supabase
        .from("streaks")
        .select("*")
        .eq("user_id", user.id)
        .maybeSingle(),
      
      supabase
        .from("achievements")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false }),
      
      supabase
        .from("friends")
        .select("*")
        .or(`user_id.eq.${user.id},friend_id.eq.${user.id}`)
    ]);

    console.log(`[getUserStats] Streak query result for user ${user.id}:`, streak.data, streak.error);

    // Calculate statistics
    const totalRuns = runs.data?.length || 0;
    const totalDistance = runs.data?.reduce((sum, run) => sum + (run.distance_miles || 0), 0) || 0;
    const totalDuration = runs.data?.reduce((sum, run) => sum + (run.duration_s || 0), 0) || 0;
    const averageDistance = totalRuns > 0 ? totalDistance / totalRuns : 0;
    const averageDuration = totalRuns > 0 ? totalDuration / totalRuns : 0;
    
    // Calculate total points from achievements
    const totalPoints = achievements.data?.reduce((sum, achievement) => sum + (achievement.points || 0), 0) || 0;
    
    // Calculate total gems from achievements + runs
    const achievementGems = achievements.data?.reduce((sum, achievement) => sum + (achievement.gems_balance || 0), 0) || 0;
    const runGems = runs.data?.reduce((sum, run) => sum + (run.gems_earned || 0), 0) || 0;
    const totalGems = achievementGems + runGems;

    // Get recent runs (last 10)
    const recentRuns = runs.data?.slice(0, 10) || [];

    // Calculate weekly stats
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    const weeklyRuns = runs.data?.filter(run => 
      new Date(run.started_at) >= oneWeekAgo
    ) || [];
    const weeklyDistance = weeklyRuns.reduce((sum, run) => sum + (run.distance_miles || 0), 0);
    const weeklyDuration = weeklyRuns.reduce((sum, run) => sum + (run.duration_s || 0), 0);

    // Process friends data
    const acceptedFriends = friends.data?.filter(f => f.status === 'accepted') || [];
    const pendingRequests = friends.data?.filter(f => f.status === 'pending' && f.friend_id === user.id) || [];
    const sentRequests = friends.data?.filter(f => f.status === 'pending' && f.user_id === user.id) || [];

    return new Response(
      JSON.stringify({
        user: {
          id: user.id,
          email: user.email
        },
        stats: {
          totalRuns,
          totalDistance: Math.round(totalDistance * 100) / 100, // Round to 2 decimal places
          totalDuration: Math.round(totalDuration),
          averageDistance: Math.round(averageDistance * 100) / 100,
          averageDuration: Math.round(averageDuration),
          totalPoints,
          totalGems,
          weeklyRuns: weeklyRuns.length,
          weeklyDistance: Math.round(weeklyDistance * 100) / 100,
          weeklyDuration: Math.round(weeklyDuration)
        },
        streak: streak.data || {
          current_streak: 0,
          longest_streak: 0,
          last_run_date: null,
          freeze_count: 0
        },
        achievements: achievements.data || [],
        friends: {
          accepted: acceptedFriends.length,
          pendingRequests: pendingRequests.length,
          sentRequests: sentRequests.length,
          total: acceptedFriends.length + pendingRequests.length + sentRequests.length
        },
        recentRuns: recentRuns.map(run => ({
          id: run.id,
          distance: run.distance_miles,
          duration: run.duration_s,
          averageSpeed: run.average_speed_mph,
          peakSpeed: run.peak_speed_mph,
          gemsEarned: run.gems_earned,
          isFlagged: run.is_flagged,
          startedAt: run.started_at,
          createdAt: run.created_at
        }))
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (e) {
    console.error("Function error:", e);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}); 