import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface FinishRunRequest {
  runId: string;
  distance: number; // in miles
  duration: number; // in seconds
  averageSpeed?: number; // in mph
  peakSpeed?: number; // in mph
  coordinates?: Array<{ lat: number; lng: number; timestamp?: string }>;
}

interface StreakData {
  current_streak: number;
  longest_streak: number;
  last_run_date: string;
  freeze_count: number;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const startTime = Date.now();
    console.log(`[finishRun] Starting run completion process`);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });

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

    const body: FinishRunRequest = await req.json();
    const { runId, distance, duration, averageSpeed, peakSpeed, coordinates } = body;

    console.log(`[finishRun] Processing run ${runId} for user ${user.id}`);

    // Enhanced input validation
    if (!distance || distance <= 0 || distance > 100) {
      return new Response(
        JSON.stringify({ 
          error: "Invalid distance", 
          details: "Distance must be between 0 and 100 miles",
          code: "DISTANCE_VIOLATION"
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!duration || duration <= 0 || duration > 86400) {
      return new Response(
        JSON.stringify({ 
          error: "Invalid duration", 
          details: "Duration must be between 0 and 86400 seconds",
          code: "DURATION_VIOLATION"
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Calculate speed in mph
    const calculatedSpeed = (distance / duration) * 3600;
    const minPace = 0.5;
    const maxPace = 20;

    if (calculatedSpeed < minPace && distance > 1) {
      return new Response(
        JSON.stringify({ 
          error: "Suspicious activity detected", 
          details: "Distance too high for reported speed. Please ensure accurate tracking.",
          code: "PACE_VIOLATION"
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Calculate gems earned (1 gem per mile)
    const gemsEarned = Math.floor(distance);
    
    // Anti-cheating: Basic speed validation
    let isFlagged = false;
    if (averageSpeed && averageSpeed > 27) {
      isFlagged = true;
      console.warn(`[finishRun] Suspicious speed detected for user ${user.id}: ${averageSpeed} mph`);
    }

    // Update the run with completion data
    console.log(`[finishRun] Updating run ${runId} for user ${user.id}`);
    const { error: updateError } = await supabase
      .from("runs")
      .update({
        distance_miles: distance,
        duration_s: duration,
        average_speed_mph: averageSpeed || calculatedSpeed,
        peak_speed_mph: peakSpeed || calculatedSpeed,
        gems_earned: gemsEarned,
        is_flagged: isFlagged
      })
      .eq("id", runId);

    if (updateError) {
      console.error("Run update error:", updateError);
      return new Response(
        JSON.stringify({ error: "Failed to update run", details: updateError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[finishRun] Run ${runId} updated successfully`);

    // Save route coordinates if provided
    if (coordinates && coordinates.length > 0) {
      console.log(`[finishRun] Saving route coordinates for run ${runId}`);
      const { error: routeError } = await supabase
        .from("run_routes")
        .upsert({
          run_id: runId,
          coordinates: coordinates
        }, { onConflict: "run_id" });

      if (routeError) {
        console.error("Route save error:", routeError);
      } else {
        console.log(`[finishRun] Route saved successfully for run ${runId}`);
      }
    }

    // Update daily progress
    const today = new Date().toISOString().split('T')[0];
    console.log(`[finishRun] Updating daily progress for user ${user.id}`);
    
    const { data: existingProgress } = await supabase
      .from("daily_progress")
      .select("id, seconds_completed, gems_earned")
      .eq("user_id", user.id)
      .eq("date", today)
      .maybeSingle();

    if (existingProgress) {
      // Update existing progress
      const { error: progressError } = await supabase
        .from("daily_progress")
        .update({
          seconds_completed: existingProgress.seconds_completed + duration,
          gems_earned: existingProgress.gems_earned + gemsEarned,
          updated_at: new Date().toISOString()
        })
        .eq("user_id", user.id)
        .eq("date", today);

      if (progressError) {
        console.error("Daily progress update error:", progressError);
      } else {
        console.log(`[finishRun] Daily progress updated for user ${user.id}`);
      }
    } else {
      // Create new daily progress entry
      const { error: progressError } = await supabase
        .from("daily_progress")
        .insert({
          user_id: user.id,
          date: today,
          seconds_completed: duration,
          gems_earned: gemsEarned,
          minutes_goal: 15
        });

      if (progressError) {
        console.error("Daily progress creation error:", progressError);
      } else {
        console.log(`[finishRun] Daily progress created for user ${user.id}`);
      }
    }

    // Update or create streak
    console.log(`[finishRun] Checking streak for user ${user.id} on date ${today}`);
    
    const { data: existingStreak, error: streakQueryError } = await supabase
      .from("streaks")
      .select("*")
      .eq("user_id", user.id)
      .single();

    if (streakQueryError) {
      console.log(`[finishRun] No existing streak found for user ${user.id}:`, streakQueryError.message);
    } else {
      console.log(`[finishRun] Found existing streak for user ${user.id}:`, existingStreak);
    }

    let streakData: StreakData = {
      current_streak: 1,
      longest_streak: 1,
      last_run_date: today,
      freeze_count: 0,
    };

    if (existingStreak) {
      const lastRunDate = new Date(existingStreak.last_run_date);
      const todayDate = new Date(today);
      const daysDiff = Math.floor((todayDate.getTime() - lastRunDate.getTime()) / (1000 * 60 * 60 * 24));

      console.log(`[finishRun] Days since last run: ${daysDiff}`);

      if (daysDiff === 1) {
        streakData.current_streak = existingStreak.current_streak + 1;
        streakData.longest_streak = Math.max(existingStreak.longest_streak, streakData.current_streak);
        console.log(`[finishRun] Consecutive day - new streak: ${streakData.current_streak}`);
      } else if (daysDiff === 0) {
        streakData.current_streak = existingStreak.current_streak;
        streakData.longest_streak = existingStreak.longest_streak;
        console.log(`[finishRun] Same day - keeping streak: ${streakData.current_streak}`);
      } else {
        streakData.current_streak = 1;
        streakData.longest_streak = existingStreak.longest_streak;
        console.log(`[finishRun] Streak broken - resetting to: ${streakData.current_streak}`);
      }

      const { error: streakUpdateError } = await supabase
        .from("streaks")
        .update(streakData)
        .eq("user_id", user.id);

      if (streakUpdateError) {
        console.error("Streak update error:", streakUpdateError);
      } else {
        console.log(`[finishRun] Streak updated successfully for user ${user.id}`);
      }
    } else {
      console.log(`[finishRun] Creating new streak for user ${user.id}:`, streakData);
      const { error: streakCreateError } = await supabase
        .from("streaks")
        .insert([streakData]);

      if (streakCreateError) {
        console.error("Streak creation error:", streakCreateError);
      } else {
        console.log(`[finishRun] Streak created successfully for user ${user.id}`);
      }
    }

    // Update achievements
    console.log(`[finishRun] Updating achievements for user ${user.id}`);
    
    // Get user's current achievements
    const { data: userAchievements } = await supabase
      .from("user_achievements")
      .select("*")
      .eq("user_id", user.id);

    const unlockedAchievements: string[] = [];

    // Update distance-based achievements
    for (const achievement of userAchievements || []) {
      let shouldUnlock = false;
      let newProgress = achievement.progress;

      switch (achievement.achievement_id) {
        case "first_run":
          if (distance > 0 && !achievement.is_unlocked) {
            shouldUnlock = true;
            newProgress = 1.0;
          }
          break;
        case "5k_runner":
          if (distance >= 3.1 && !achievement.is_unlocked) {
            shouldUnlock = true;
            newProgress = 1.0;
          }
          break;
        case "speed_demon":
          if (averageSpeed && averageSpeed >= 10.8 && !achievement.is_unlocked) {
            shouldUnlock = true;
            newProgress = 1.0;
          }
          break;
        case "consistency_king":
          if (streakData.current_streak >= 7 && !achievement.is_unlocked) {
            shouldUnlock = true;
            newProgress = 1.0;
          } else if (streakData.current_streak < 7) {
            newProgress = Math.min(1.0, streakData.current_streak / 7.0);
          }
          break;
        case "marathon_ready":
          // This would need to track total lifetime distance
          // For now, just update progress based on this run
          const currentValue = achievement.current_value + distance;
          newProgress = Math.min(1.0, currentValue / achievement.target_value);
          break;
      }

      if (shouldUnlock || newProgress !== achievement.progress) {
        const { error: achievementError } = await supabase
          .from("user_achievements")
          .update({
            is_unlocked: shouldUnlock ? true : achievement.is_unlocked,
            progress: newProgress,
            current_value: achievement.achievement_id === "marathon_ready" 
              ? achievement.current_value + distance 
              : achievement.current_value,
            unlocked_at: shouldUnlock ? new Date().toISOString() : achievement.unlocked_at
          })
          .eq("id", achievement.id);

        if (achievementError) {
          console.error("Achievement update error:", achievementError);
        } else if (shouldUnlock) {
          unlockedAchievements.push(achievement.title);
          console.log(`[finishRun] Achievement unlocked: ${achievement.title}`);
        }
      }
    }

    const endTime = Date.now();
    const executionTime = endTime - startTime;
    console.log(`[finishRun] Function execution time: ${executionTime}ms`);

    return new Response(
      JSON.stringify({
        message: "Run completed successfully",
        runId,
        streak: streakData,
        unlockedAchievements,
        gemsEarned
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );

  } catch (e) {
    console.error("Function error:", e);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});