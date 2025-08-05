import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface Coordinate {
  lat: number;
  lng: number;
  timestamp?: string;
}

interface SaveRouteRequest {
  runId: string;
  coordinates: Coordinate[];
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
    const body: SaveRouteRequest = await req.json();
    
    if (!body.runId || !body.coordinates || body.coordinates.length === 0) {
      return new Response(
        JSON.stringify({ error: "Run ID and coordinates are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify the run belongs to the user
    const { data: run, error: runErr } = await supabase
      .from("runs")
      .select("id, user_id")
      .eq("id", body.runId)
      .eq("user_id", user.id)
      .single();

    if (runErr || !run) {
      return new Response(
        JSON.stringify({ error: "Run not found or access denied" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check if route already exists for this run
    const { data: existingRoute } = await supabase
      .from("run_routes")
      .select("id")
      .eq("run_id", body.runId)
      .maybeSingle();

    let result;
    if (existingRoute) {
      // Update existing route
      const { data: updatedRoute, error: updateErr } = await supabase
        .from("run_routes")
        .update({
          coordinates: body.coordinates
        })
        .eq("run_id", body.runId)
        .select()
        .single();

      if (updateErr) {
        console.error("Route update error:", updateErr);
        return new Response(
          JSON.stringify({ error: "Failed to update route" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      result = updatedRoute;
    } else {
      // Create new route
      const { data: newRoute, error: insertErr } = await supabase
        .from("run_routes")
        .insert({
          run_id: body.runId,
          coordinates: body.coordinates
        })
        .select()
        .single();

      if (insertErr) {
        console.error("Route creation error:", insertErr);
        return new Response(
          JSON.stringify({ error: "Failed to create route" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      result = newRoute;
    }

    return new Response(
      JSON.stringify({
        message: "Route saved successfully",
        route: {
          id: result.id,
          runId: result.run_id,
          coordinateCount: result.coordinates.length,
          createdAt: result.created_at
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