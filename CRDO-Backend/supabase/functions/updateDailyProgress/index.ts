import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface UpdateProgressRequest {
  secondsCompleted: number;
  minutesGoal?: number;
  gemsEarned?: number;
}

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

    // Parse request body
    const body: UpdateProgressRequest = await req.json();
    
    if (body.secondsCompleted === undefined) {
      return new Response(
        JSON.stringify({ error: "Seconds completed is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const today = new Date().toISOString().split('T')[0];
    const updateData: any = {
      seconds_completed: body.secondsCompleted,
      updated_at: new Date().toISOString()
    };

    if (body.minutesGoal !== undefined) {
      updateData.minutes_goal = body.minutesGoal;
    }

    if (body.gemsEarned !== undefined) {
      updateData.gems_earned = body.gemsEarned;
    }

    // Check if daily progress already exists for today
    const { data: existingProgress } = await supabase
      .from("daily_progress")
      .select("id, seconds_completed")
      .eq("user_id", user.id)
      .eq("date", today)
      .maybeSingle();

    let result;
    if (existingProgress) {
      // Update existing progress (add to current seconds)
      const newSecondsCompleted = existingProgress.seconds_completed + body.secondsCompleted;
      
      const { data: updatedProgress, error: updateErr } = await supabase
        .from("daily_progress")
        .update({
          ...updateData,
          seconds_completed: newSecondsCompleted
        })
        .eq("user_id", user.id)
        .eq("date", today)
        .select()
        .single();

      if (updateErr) {
        console.error("Daily progress update error:", updateErr);
        return new Response(
          JSON.stringify({ error: "Failed to update daily progress" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      result = updatedProgress;
    } else {
      // Create new daily progress entry
      const { data: newProgress, error: insertErr } = await supabase
        .from("daily_progress")
        .insert({
          user_id: user.id,
          date: today,
          ...updateData
        })
        .select()
        .single();

      if (insertErr) {
        console.error("Daily progress creation error:", insertErr);
        return new Response(
          JSON.stringify({ error: "Failed to create daily progress" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      result = newProgress;
    }

    // Calculate progress percentage
    const goalSeconds = result.minutes_goal * 60;
    const progressPercentage = goalSeconds > 0 ? (result.seconds_completed / goalSeconds) : 0;

    return new Response(
      JSON.stringify({
        message: "Daily progress updated successfully",
        progress: {
          id: result.id,
          date: result.date,
          secondsCompleted: result.seconds_completed,
          minutesGoal: result.minutes_goal,
          gemsEarned: result.gems_earned,
          progressPercentage: Math.round(progressPercentage * 100) / 100,
          updatedAt: result.updated_at
        }
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