import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

interface HealthStatus {
  status: "healthy" | "unhealthy";
  timestamp: string;
  version: string;
  database: {
    status: "connected" | "disconnected";
    responseTime?: number;
  };
  functions: {
    status: "running" | "stopped";
    count: number;
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const startTime = Date.now();
    
    // Test database connection
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    let dbStatus: "connected" | "disconnected" = "disconnected";
    let dbResponseTime: number | undefined;

    try {
      const dbStartTime = Date.now();
      const { error } = await supabase.from("runs").select("count").limit(1);
      const dbEndTime = Date.now();
      
      if (!error) {
        dbStatus = "connected";
        dbResponseTime = dbEndTime - dbStartTime;
      }
    } catch (e) {
      console.error("Database health check failed:", e);
    }

    const endTime = Date.now();
    const totalResponseTime = endTime - startTime;

    const healthStatus: HealthStatus = {
      status: dbStatus === "connected" ? "healthy" : "unhealthy",
      timestamp: new Date().toISOString(),
      version: "1.0.0",
      database: {
        status: dbStatus,
        responseTime: dbResponseTime,
      },
      functions: {
        status: "running",
        count: 8, // Update this based on your actual function count
      },
    };

    return new Response(
      JSON.stringify(healthStatus),
      { 
        status: healthStatus.status === "healthy" ? 200 : 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );

  } catch (e) {
    console.error("Health check error:", e);
    return new Response(
      JSON.stringify({ 
        status: "unhealthy", 
        error: "Health check failed",
        timestamp: new Date().toISOString()
      }),
      { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}); 