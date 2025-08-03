// supabase/functions/getDashboard/index.ts
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

    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "").trim();
    if (!token) return json({ error: "Unauthorized" }, 401);

    const {
      data: { user },
      error: userErr,
    } = await supabase.auth.getUser(token);
    if (userErr || !user) return json({ error: "Unauthorized" }, 401);

    const today = new Date().toISOString().slice(0, 10);

    const [streak, runs, achievements] = await Promise.all([
      supabase.from("streaks").select("*").eq("user_id", user.id).maybeSingle(),
      supabase
        .from("runs")
        .select("*")
        .eq("user_id", user.id)
        .order("started_at", { ascending: false })
        .limit(10),
      supabase
        .from("achievements")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(5)
    ]);

    // Calculate total gems from achievements
    const totalGems = achievements.data?.reduce((sum, achievement) => sum + (achievement.gems_balance || 0), 0) || 0;

    return json({
      streak: streak.data,
      gems: { balance: totalGems },
      recentRuns: runs.data ?? [],
      recentAchievements: achievements.data ?? []
    });
  } catch (e) {
    console.error(e);
    return json({ error: "Server error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}