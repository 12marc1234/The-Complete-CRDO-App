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
}

interface StreakData {
  current_streak: number;
  longest_streak: number;
  last_run_date: string;
  freeze_count: number;
}

interface Achievement {
  user_id: string;
  description: string;
  points: number;
  gems_balance: number;
  created_at: string;
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
    const { runId, distance, duration, averageSpeed, peakSpeed } = body;

    console.log(`[finishRun] Processing run ${runId} for user ${user.id}`);

    // Enhanced input validation
    if (!distance || distance <= 0 || distance > 100) { // Max 100 miles
      return new Response(
        JSON.stringify({ 
          error: "Invalid distance", 
          details: "Distance must be between 0 and 100 miles",
          code: "DISTANCE_VIOLATION"
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!duration || duration <= 0 || duration > 86400) { // Max 24 hours
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
    const calculatedSpeed = (distance / duration) * 3600; // Convert to mph
    const minPace = 0.5; // 0.5 mph minimum
    const maxPace = 20; // 20 mph maximum

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
    
    // Anti-cheating: Basic speed validation (27 mph is roughly 12 m/s)
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

    // Update or create streak
    const today = new Date().toISOString().split('T')[0];
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
        // Consecutive day
        streakData.current_streak = existingStreak.current_streak + 1;
        streakData.longest_streak = Math.max(existingStreak.longest_streak, streakData.current_streak);
        console.log(`[finishRun] Consecutive day - new streak: ${streakData.current_streak}`);
      } else if (daysDiff === 0) {
        // Same day, keep existing streak
        streakData.current_streak = existingStreak.current_streak;
        streakData.longest_streak = existingStreak.longest_streak;
        console.log(`[finishRun] Same day - keeping streak: ${streakData.current_streak}`);
      } else {
        // Streak broken, reset to 1
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
      // Create new streak
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

    // Check for achievements
    const achievements: Achievement[] = [];
    
    // Check for distance-based achievements
    if (distance >= 3.1) { // 5km = 3.1 miles
      achievements.push({
        user_id: user.id,
        description: "Complete a 5km run",
        points: 50,
        gems_balance: 5,
        created_at: new Date().toISOString()
      });
    }
    
    if (distance >= 6.2) { // 10km = 6.2 miles
      achievements.push({
        user_id: user.id,
        description: "Complete a 10km run",
        points: 100,
        gems_balance: 10,
        created_at: new Date().toISOString()
      });
    }

    // Check for streak-based achievements
    if (streakData.current_streak >= 7) {
      achievements.push({
        user_id: user.id,
        description: "Maintain a 7-day streak",
        points: 75,
        gems_balance: 7,
        created_at: new Date().toISOString()
      });
    }
    
    if (streakData.current_streak >= 30) {
      achievements.push({
        user_id: user.id,
        description: "Maintain a 30-day streak",
        points: 200,
        gems_balance: 30,
        created_at: new Date().toISOString()
      });
    }

    // Check for speed-based achievements (10.8 mph = 3 m/s)
    if (averageSpeed && averageSpeed >= 10.8) {
      achievements.push({
        user_id: user.id,
        description: "Maintain an average speed of 3 m/s",
        points: 150,
        gems_balance: 15,
        created_at: new Date().toISOString()
      });
    }

    // Insert achievements (avoid duplicates)
    console.log(`[finishRun] Processing ${achievements.length} achievements for user ${user.id}`);
    for (const achievement of achievements) {
      const { error: achievementError } = await supabase
        .from("achievements")
        .upsert([achievement], { 
          onConflict: "user_id,description",
          ignoreDuplicates: true 
        });

      if (achievementError) {
        console.error("Achievement insert error:", achievementError);
      } else {
        console.log(`[finishRun] Achievement "${achievement.description}" processed for user ${user.id}`);
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
        achievements: achievements.map(a => a.description)
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