import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// 🧠 Function to insert a fake run for testing purposes
// This is a test utility function for seeding test data, not part of the main running flow
serve(async (req) => {
  console.log("🔥 Function start");

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!url || !serviceKey) {
      console.error("❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
      return new Response(
        JSON.stringify({ error: "Missing Supabase environment variables" }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    console.log("🔑 Env loaded");

    const supabase = createClient(url, serviceKey);
    console.log("🧪 Client created");

    // Create a test user first
    const { data: userData, error: userError } = await supabase.auth.admin.createUser({
      email: "test@example.com",
      password: "testpassword123",
      email_confirm: true
    });

    if (userError) {
      console.error("❌ User creation error:", userError);
      // If user already exists, try to get the existing user
      const { data: existingUser } = await supabase.auth.admin.listUsers();
      const testUser = existingUser.users.find(u => u.email === "test@example.com");
      
      if (!testUser) {
        return new Response(
          JSON.stringify({ error: "Failed to create or find test user", details: userError }),
          {
            status: 500,
            headers: { "Content-Type": "application/json" },
          }
        );
      }
      
      console.log("✅ Using existing test user:", testUser.id);
      
      // Insert run data
      const { error } = await supabase.from("runs").insert([
        {
          user_id: testUser.id,
          started_at: new Date(Date.now() - 3600000).toISOString(), // 1 hour ago
          finished_at: new Date().toISOString(),
          distance_m: 5200, // 5.2 km in meters
          duration_s: 1800, // 30 minutes in seconds
        },
      ]);

      if (error) {
        console.error("❌ Insert error:", error);
        return new Response(
          JSON.stringify({ error: "Insert failed", raw: error }),
          {
            status: 500,
            headers: { "Content-Type": "application/json" },
          }
        );
      }

      console.log("✅ Inserted successfully");
      return new Response(
        JSON.stringify({ message: "Test run seeded successfully.", user_id: testUser.id }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    console.log("✅ Created new test user:", userData.user.id);
    
    // Insert run data
    const { error } = await supabase.from("runs").insert([
      {
        user_id: userData.user.id,
        started_at: new Date(Date.now() - 3600000).toISOString(), // 1 hour ago
        finished_at: new Date().toISOString(),
        distance_m: 5200, // 5.2 km in meters
        duration_s: 1800, // 30 minutes in seconds
      },
    ]);

    if (error) {
      console.error("❌ Insert error:", error);
      return new Response(
        JSON.stringify({ error: "Insert failed", raw: error }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    console.log("✅ Inserted successfully");
    return new Response(
      JSON.stringify({ message: "Test run seeded successfully.", user_id: userData.user.id }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (e) {
    console.error("❌ Exception:", e);
    return new Response(
      JSON.stringify({ error: String(e) }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});