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

    // Get all friend relationships for this user
    const { data: friendRelationships, error: friendsError } = await supabase
      .from("friends")
      .select("*")
      .or(`user_id.eq.${user.id},friend_id.eq.${user.id}`);

    if (friendsError) {
      console.error("Friends fetch error:", friendsError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch friends", details: friendsError }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get all users to map friend IDs to user data
    const { data: allUsers } = await supabase.auth.admin.listUsers();
    const userMap = new Map(allUsers.users.map(u => [u.id, u]));

    // Process friend relationships
    const friends = [];
    const pendingRequests = [];
    const sentRequests = [];

    for (const relationship of friendRelationships || []) {
      const isUserInitiator = relationship.user_id === user.id;
      const friendId = isUserInitiator ? relationship.friend_id : relationship.user_id;
      const friendUser = userMap.get(friendId);

      if (!friendUser) continue;

      const friendData = {
        id: friendUser.id,
        email: friendUser.email,
        relationshipId: relationship.id,
        status: relationship.status,
        requestedAt: relationship.requested_at,
        respondedAt: relationship.responded_at
      };

      if (relationship.status === 'accepted') {
        friends.push(friendData);
      } else if (relationship.status === 'pending') {
        if (isUserInitiator) {
          sentRequests.push(friendData);
        } else {
          pendingRequests.push(friendData);
        }
      }
    }

    return new Response(
      JSON.stringify({
        friends,
        pendingRequests,
        sentRequests,
        totalFriends: friends.length,
        totalPendingRequests: pendingRequests.length,
        totalSentRequests: sentRequests.length
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