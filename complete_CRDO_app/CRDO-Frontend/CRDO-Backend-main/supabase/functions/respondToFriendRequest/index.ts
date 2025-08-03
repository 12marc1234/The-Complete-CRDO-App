import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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

    // Parse request body
    const body = await req.json();
    const { requestId, action } = body; // action: "accept" or "reject"

    if (!requestId || !action) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: requestId, action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!['accept', 'reject'].includes(action)) {
      return new Response(
        JSON.stringify({ error: "Invalid action. Must be 'accept' or 'reject'" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get the friend request
    const { data: friendRequest, error: requestError } = await supabase
      .from("friends")
      .select("*")
      .eq("id", requestId)
      .eq("friend_id", user.id) // User must be the one receiving the request
      .eq("status", "pending")
      .single();

    if (requestError || !friendRequest) {
      return new Response(
        JSON.stringify({ error: "Friend request not found or already processed" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Update the friend request status
    const newStatus = action === 'accept' ? 'accepted' : 'rejected';
    const { error: updateError } = await supabase
      .from("friends")
      .update({
        status: newStatus,
        responded_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq("id", requestId);

    if (updateError) {
      console.error("Friend request update error:", updateError);
      return new Response(
        JSON.stringify({ error: "Failed to update friend request", details: updateError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        message: `Friend request ${action}ed successfully`,
        status: newStatus
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