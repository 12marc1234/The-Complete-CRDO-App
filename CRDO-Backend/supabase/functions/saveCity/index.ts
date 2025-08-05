import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface Building {
  id: string;
  type: string;
  position: { x: number; y: number };
}

interface SaveCityRequest {
  buildings: Building[];
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
    const body: SaveCityRequest = await req.json();
    
    if (!body.buildings) {
      return new Response(
        JSON.stringify({ error: "Buildings data is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check if user already has a city
    const { data: existingCity } = await supabase
      .from("user_cities")
      .select("id")
      .eq("user_id", user.id)
      .single();

    let result;
    if (existingCity) {
      // Update existing city
      const { data: updatedCity, error: updateErr } = await supabase
        .from("user_cities")
        .update({
          buildings: body.buildings,
          updated_at: new Date().toISOString()
        })
        .eq("user_id", user.id)
        .select()
        .single();

      if (updateErr) {
        console.error("City update error:", updateErr);
        return new Response(
          JSON.stringify({ error: "Failed to update city" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      result = updatedCity;
    } else {
      // Create new city
      const { data: newCity, error: insertErr } = await supabase
        .from("user_cities")
        .insert({
          user_id: user.id,
          buildings: body.buildings
        })
        .select()
        .single();

      if (insertErr) {
        console.error("City creation error:", insertErr);
        return new Response(
          JSON.stringify({ error: "Failed to create city" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      result = newCity;
    }

    return new Response(
      JSON.stringify({
        message: "City saved successfully",
        city: {
          id: result.id,
          buildings: result.buildings,
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