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
    const { friendEmail } = body;

    if (!friendEmail) {
      return new Response(
        JSON.stringify({ error: "Missing required field: friendEmail" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Find the friend by email
    const { data: friendUser, error: friendError } = await supabase.auth.admin.listUsers();
    const friend = friendUser.users.find(u => u.email === friendEmail);

    if (!friend) {
      return new Response(
        JSON.stringify({ error: "User not found with this email" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (friend.id === user.id) {
      return new Response(
        JSON.stringify({ error: "Cannot send friend request to yourself" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check if friend request already exists
    const { data: existingRequest } = await supabase
      .from("friends")
      .select("*")
      .or(`and(user_id.eq.${user.id},friend_id.eq.${friend.id}),and(user_id.eq.${friend.id},friend_id.eq.${user.id})`)
      .single();

    if (existingRequest) {
      if (existingRequest.status === 'accepted') {
        return new Response(
          JSON.stringify({ error: "Already friends with this user" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } else if (existingRequest.status === 'pending') {
        return new Response(
          JSON.stringify({ error: "Friend request already pending" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Send friend request
    const { data: friendRequest, error: insertError } = await supabase
      .from("friends")
      .insert([{
        user_id: user.id,
        friend_id: friend.id,
        status: 'pending',
        requested_at: new Date().toISOString()
      }])
      .select()
      .single();

    if (insertError) {
      console.error("Friend request insert error:", insertError);
      return new Response(
        JSON.stringify({ error: "Failed to send friend request", details: insertError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        message: "Friend request sent successfully",
        friendRequest
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