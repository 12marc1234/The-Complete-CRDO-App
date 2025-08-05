import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface UpdateProgressRequest {
  achievementId: string;
  currentValue: number;
  progress: number;
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
    
    if (!body.achievementId || body.currentValue === undefined || body.progress === undefined) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Update achievement progress
    const { data: updatedAchievement, error: updateErr } = await supabase
      .from("user_achievements")
      .update({
        current_value: body.currentValue,
        progress: body.progress
      })
      .eq("user_id", user.id)
      .eq("achievement_id", body.achievementId)
      .select()
      .single();

    if (updateErr) {
      console.error("Achievement update error:", updateErr);
      return new Response(
        JSON.stringify({ error: "Failed to update achievement progress" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        message: "Achievement progress updated successfully",
        achievement: {
          id: updatedAchievement.id,
          achievementId: updatedAchievement.achievement_id,
          title: updatedAchievement.title,
          currentValue: updatedAchievement.current_value,
          progress: updatedAchievement.progress,
          isUnlocked: updatedAchievement.is_unlocked
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