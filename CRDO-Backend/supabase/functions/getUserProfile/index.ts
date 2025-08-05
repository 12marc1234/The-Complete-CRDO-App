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

    // Get user's recent runs for activity
    const { data: recentRuns } = await supabase
      .from("runs")
      .select("*")
      .eq("user_id", user.id)
      .order("started_at", { ascending: false })
      .limit(5);

    // Get user's daily progress
    const today = new Date().toISOString().split('T')[0];
    const { data: dailyProgress } = await supabase
      .from("daily_progress")
      .select("*")
      .eq("user_id", user.id)
      .eq("date", today)
      .maybeSingle();

    // Get user's achievements
    const { data: achievements } = await supabase
      .from("user_achievements")
      .select("*")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false });

    // Calculate total stats
    const totalRuns = recentRuns?.length || 0;
    const totalDistance = recentRuns?.reduce((sum, run) => sum + (run.distance_miles || 0), 0) || 0;
    const totalDuration = recentRuns?.reduce((sum, run) => sum + (run.duration_s || 0), 0) || 0;
    const averagePace = totalDistance > 0 ? (totalDuration / 60) / (totalDistance / 1.60934) : 0; // min/mi

    return new Response(
      JSON.stringify({
        user: {
          id: user.id,
          email: user.email,
          firstName: user.user_metadata?.first_name,
          lastName: user.user_metadata?.last_name,
          bio: user.user_metadata?.bio || "Runner"
        },
        stats: {
          totalRuns,
          totalDistance: Math.round(totalDistance * 100) / 100,
          totalDuration: Math.round(totalDuration),
          averagePace: Math.round(averagePace * 100) / 100
        },
        dailyProgress: dailyProgress || {
          seconds_completed: 0,
          minutes_goal: 15,
          gems_earned: 0
        },
        recentActivity: recentRuns?.map(run => ({
          id: run.id,
          distance: run.distance_miles,
          duration: run.duration_s,
          startedAt: run.started_at,
          gemsEarned: run.gems_earned
        })) || [],
        achievements: achievements?.map(achievement => ({
          id: achievement.id,
          achievementId: achievement.achievement_id,
          title: achievement.title,
          description: achievement.description,
          category: achievement.category,
          icon: achievement.icon,
          isUnlocked: achievement.is_unlocked,
          progress: achievement.progress,
          targetValue: achievement.target_value,
          currentValue: achievement.current_value,
          unlockedAt: achievement.unlocked_at
        })) || []
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