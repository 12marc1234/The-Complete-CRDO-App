import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface UpdateProfileRequest {
  bio?: string;
  firstName?: string;
  lastName?: string;
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
    const body: UpdateProfileRequest = await req.json();
    
    if (!body.bio && !body.firstName && !body.lastName) {
      return new Response(
        JSON.stringify({ error: "No profile data provided" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Update user metadata
    const updateData: any = {};
    if (body.bio !== undefined) updateData.bio = body.bio;
    if (body.firstName !== undefined) updateData.first_name = body.firstName;
    if (body.lastName !== undefined) updateData.last_name = body.lastName;

    const { data: updatedUser, error: updateErr } = await supabase.auth.admin.updateUserById(
      user.id,
      { user_metadata: updateData }
    );

    if (updateErr) {
      console.error("Profile update error:", updateErr);
      return new Response(
        JSON.stringify({ error: "Failed to update profile", details: updateErr }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        message: "Profile updated successfully",
        user: {
          id: updatedUser.user.id,
          email: updatedUser.user.email,
          user_metadata: updatedUser.user.user_metadata
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