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

    // Get query parameters
    const url = new URL(req.url);
    const timeframe = url.searchParams.get("timeframe") || "weekly";
    const limit = parseInt(url.searchParams.get("limit") || "50");

    // Validate timeframe
    const validTimeframes = ["weekly", "monthly", "all_time"];
    if (!validTimeframes.includes(timeframe)) {
      return new Response(
        JSON.stringify({ error: "Invalid timeframe. Must be weekly, monthly, or all_time" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get leaderboard data
    const { data: leaderboardEntries, error: leaderboardErr } = await supabase
      .from("leaderboards")
      .select(`
        *,
        user:user_id (
          id,
          email,
          user_metadata
        )
      `)
      .eq("timeframe", timeframe)
      .order("points", { ascending: false })
      .order("total_distance", { ascending: false })
      .limit(limit);

    if (leaderboardErr) {
      console.error("Leaderboard fetch error:", leaderboardErr);
      return new Response(
        JSON.stringify({ error: "Failed to fetch leaderboard" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Format leaderboard entries
    const formattedEntries = leaderboardEntries?.map((entry, index) => ({
      rank: index + 1,
      userId: entry.user_id,
      userEmail: entry.user?.email,
      userName: entry.user?.user_metadata?.first_name 
        ? `${entry.user.user_metadata.first_name} ${entry.user.user_metadata.last_name || ""}`.trim()
        : entry.user?.email?.split('@')[0] || "Anonymous",
      totalDistance: entry.total_distance,
      totalRuns: entry.total_runs,
      averagePace: entry.average_pace,
      points: entry.points,
      timeframe: entry.timeframe
    })) || [];

    return new Response(
      JSON.stringify({
        timeframe,
        entries: formattedEntries,
        totalEntries: formattedEntries.length
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