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

    // Get friend ID from query parameters
    const url = new URL(req.url);
    const friendId = url.searchParams.get("friendId");
    
    if (!friendId) {
      return new Response(
        JSON.stringify({ error: "Friend ID is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify friendship exists
    const { data: friendship } = await supabase
      .from("friends")
      .select("*")
      .or(`user_id.eq.${user.id},friend_id.eq.${user.id}`)
      .or(`user_id.eq.${friendId},friend_id.eq.${friendId}`)
      .eq("status", "accepted")
      .maybeSingle();

    if (!friendship) {
      return new Response(
        JSON.stringify({ error: "Friend not found or not accepted" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get friend's user data
    const { data: friendUser } = await supabase.auth.admin.getUserById(friendId);
    if (!friendUser.user) {
      return new Response(
        JSON.stringify({ error: "Friend user not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get friend's recent runs
    const { data: recentRuns } = await supabase
      .from("runs")
      .select("*")
      .eq("user_id", friendId)
      .order("started_at", { ascending: false })
      .limit(5);

    // Get friend's achievements
    const { data: achievements } = await supabase
      .from("user_achievements")
      .select("*")
      .eq("user_id", friendId)
      .eq("is_unlocked", true)
      .order("unlocked_at", { ascending: false })
      .limit(10);

    // Calculate friend's stats
    const totalRuns = recentRuns?.length || 0;
    const totalDistance = recentRuns?.reduce((sum, run) => sum + (run.distance_miles || 0), 0) || 0;
    const totalDuration = recentRuns?.reduce((sum, run) => sum + (run.duration_s || 0), 0) || 0;
    const averagePace = totalDistance > 0 ? (totalDuration / 60) / (totalDistance / 1.60934) : 0;

    return new Response(
      JSON.stringify({
        friend: {
          id: friendUser.user.id,
          email: friendUser.user.email,
          firstName: friendUser.user.user_metadata?.first_name,
          lastName: friendUser.user.user_metadata?.last_name,
          bio: friendUser.user.user_metadata?.bio || "Runner"
        },
        stats: {
          totalRuns,
          totalDistance: Math.round(totalDistance * 100) / 100,
          totalDuration: Math.round(totalDuration),
          averagePace: Math.round(averagePace * 100) / 100
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
          title: achievement.title,
          description: achievement.description,
          category: achievement.category,
          icon: achievement.icon,
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