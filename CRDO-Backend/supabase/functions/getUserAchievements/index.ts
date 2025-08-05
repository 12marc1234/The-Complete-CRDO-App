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

    // Get user's achievements
    let { data: achievements, error: achievementsErr } = await supabase
      .from("user_achievements")
      .select("*")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false });

    if (achievementsErr) {
      console.error("Achievements fetch error:", achievementsErr);
      return new Response(
        JSON.stringify({ error: "Failed to fetch achievements" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

          // If no achievements exist, create 10 essential achievements
      if (!achievements || achievements.length === 0) {
        const defaultAchievements = [
          // Distance Achievements (3)
          {
            user_id: user.id,
            achievement_id: "first_run",
            title: "First Steps",
            description: "Complete your first run",
            category: "distance",
            icon: "figure.run",
            target_value: 1
          },
          {
            user_id: user.id,
            achievement_id: "5k_runner",
            title: "5K Runner",
            description: "Run 5 kilometers in a single session",
            category: "distance",
            icon: "flag.checkered",
            target_value: 5000
          },
          {
            user_id: user.id,
            achievement_id: "10k_runner",
            title: "10K Runner",
            description: "Run 10 kilometers in a single session",
            category: "distance",
            icon: "flag.checkered.2",
            target_value: 10000
          },
          
          // Speed Achievements (2)
          {
            user_id: user.id,
            achievement_id: "speed_demon",
            title: "Speed Demon",
            description: "Achieve a pace faster than 7:00 min/mi",
            category: "speed",
            icon: "bolt.fill",
            target_value: 420
          },
          {
            user_id: user.id,
            achievement_id: "sprint_king",
            title: "Sprint King",
            description: "Achieve a pace faster than 6:00 min/mi",
            category: "speed",
            icon: "bolt.circle.fill",
            target_value: 360
          },
          
          // Consistency Achievements (2)
          {
            user_id: user.id,
            achievement_id: "consistency_king",
            title: "Consistency King",
            description: "Run 7 days in a row",
            category: "consistency",
            icon: "calendar",
            target_value: 7
          },
          {
            user_id: user.id,
            achievement_id: "streak_master",
            title: "Streak Master",
            description: "Run 30 days in a row",
            category: "consistency",
            icon: "calendar.badge.plus",
            target_value: 30
          },
          
          // Frequency Achievements (2)
          {
            user_id: user.id,
            achievement_id: "frequent_runner",
            title: "Frequent Runner",
            description: "Complete 10 runs",
            category: "frequency",
            icon: "number.circle",
            target_value: 10
          },
          {
            user_id: user.id,
            achievement_id: "dedicated_runner",
            title: "Dedicated Runner",
            description: "Complete 50 runs",
            category: "frequency",
            icon: "number.circle.fill",
            target_value: 50
          },
          
          // Social Achievements (1)
          {
            user_id: user.id,
            achievement_id: "social_butterfly",
            title: "Social Butterfly",
            description: "Add 5 friends",
            category: "social",
            icon: "person.2.fill",
            target_value: 5
          }
        ];

      const { data: insertedAchievements, error: insertErr } = await supabase
        .from("user_achievements")
        .insert(defaultAchievements)
        .select();

      if (insertErr) {
        console.error("Failed to create default achievements:", insertErr);
        return new Response(
          JSON.stringify({ error: "Failed to create default achievements" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      achievements = insertedAchievements;
    }

    // Group achievements by category
    const achievementsByCategory = achievements.reduce((acc, achievement) => {
      const category = achievement.category;
      if (!acc[category]) {
        acc[category] = [];
      }
      acc[category].push({
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
      });
      return acc;
    }, {} as Record<string, any[]>);

    return new Response(
      JSON.stringify({
        achievements: achievementsByCategory,
        totalAchievements: achievements.length,
        unlockedCount: achievements.filter(a => a.is_unlocked).length
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