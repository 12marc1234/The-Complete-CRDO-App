import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface SpeedValidationRequest {
  runId: string;
  distance: number; // in miles
  duration: number; // in seconds
  averageSpeed: number; // in mph
  peakSpeed: number; // in mph
}

interface SpeedValidationResult {
  isLegitimate: boolean;
  confidence: number;
  riskLevel: "low" | "medium" | "high" | "critical";
  riskScore: number;
  violations: string[];
  warnings: string[];
  evidence: {
    speedAnalysis: string;
    consistencyAnalysis: string;
    patternAnalysis: string;
  };
  recommendations: string[];
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

    const body: SpeedValidationRequest = await req.json();
    const { distance, duration, averageSpeed, peakSpeed } = body;

    // Get user's complete run history
    const { data: userRuns } = await supabase
      .from("runs")
      .select("*")
      .eq("user_id", user.id)
      .order("created_at", { ascending: false });

    const result: SpeedValidationResult = {
      isLegitimate: true,
      confidence: 0,
      riskLevel: "low",
      riskScore: 0,
      violations: [],
      warnings: [],
      evidence: {
        speedAnalysis: "",
        consistencyAnalysis: "",
        patternAnalysis: ""
      },
      recommendations: []
    };

    let riskScore = 0;

    // 1. Basic Speed Validation
    const calculatedSpeed = (distance / duration) * 3600; // Convert to mph
    const speedDifference = Math.abs(calculatedSpeed - averageSpeed);
    
    if (averageSpeed > 27) { // 27 mph = ~12 m/s
      result.violations.push("Speed exceeds human limits (27 mph)");
      result.evidence.speedAnalysis = "Impossible speed detected - likely cheating";
      riskScore += 40;
    } else if (averageSpeed > 22) { // 22 mph = ~10 m/s
      result.warnings.push("Elite athlete speed detected");
      result.evidence.speedAnalysis = "Very high speed - requires verification";
      riskScore += 20;
    } else if (averageSpeed > 18) { // 18 mph = ~8 m/s
      result.evidence.speedAnalysis = "Advanced runner speed - plausible";
      riskScore += 5;
    } else if (averageSpeed > 13) { // 13 mph = ~6 m/s
      result.evidence.speedAnalysis = "Good runner speed - normal range";
      riskScore += 0;
    } else {
      result.evidence.speedAnalysis = "Recreational runner speed - normal";
      riskScore += 0;
    }

    // 2. Peak Speed Validation
    if (peakSpeed > 33) { // 33 mph = ~15 m/s
      result.violations.push("Peak speed exceeds human limits (33 mph)");
      riskScore += 30;
    } else if (peakSpeed > 27) {
      result.warnings.push("Very high peak speed detected");
      riskScore += 15;
    }

    // 3. Speed Consistency Analysis
    if (userRuns && userRuns.length > 3) {
      const recentSpeeds = userRuns.slice(0, 5).map(run => run.average_speed_mph || 0);
      const avgSpeed = recentSpeeds.reduce((sum, s) => sum + s, 0) / recentSpeeds.length;
      const speedVariation = recentSpeeds.map(s => Math.abs(s - avgSpeed));
      const avgVariation = speedVariation.reduce((sum, v) => sum + v, 0) / speedVariation.length;
      
      if (avgVariation < 0.5 && recentSpeeds.length > 5) {
        result.violations.push("Suspiciously consistent speeds");
        result.evidence.consistencyAnalysis = "Perfect consistency suggests automation";
        riskScore += 30;
      } else if (avgVariation > 4.0) {
        result.evidence.consistencyAnalysis = "High variation - natural human performance";
        riskScore -= 10;
      } else {
        result.evidence.consistencyAnalysis = "Normal speed variation";
        riskScore += 0;
      }
    }

    // 4. Pattern Analysis
    if (userRuns && userRuns.length > 10) {
      const allSpeeds = userRuns.map(run => run.average_speed_mph || 0);
      const recentAvg = allSpeeds.slice(0, 5).reduce((sum, s) => sum + s, 0) / 5;
      const olderAvg = allSpeeds.slice(5, 10).reduce((sum, s) => sum + s, 0) / 5;
      
      if (recentAvg > olderAvg * 1.5) {
        result.violations.push("Impossible performance improvement");
        result.evidence.patternAnalysis = "Sudden 50%+ speed improvement";
        riskScore += 30;
      } else if (recentAvg > olderAvg * 1.2) {
        result.warnings.push("Suspicious performance improvement");
        result.evidence.patternAnalysis = "20%+ speed improvement";
        riskScore += 15;
      } else if (recentAvg > olderAvg * 1.1) {
        result.evidence.patternAnalysis = "Natural progression";
        riskScore += 0;
      } else {
        result.evidence.patternAnalysis = "Stable performance";
        riskScore += 0;
      }
    }

    // Determine risk level and confidence
    result.riskScore = Math.max(0, Math.min(100, riskScore));
    
    if (result.riskScore >= 80) {
      result.riskLevel = "critical";
      result.isLegitimate = false;
    } else if (result.riskScore >= 60) {
      result.riskLevel = "high";
      result.isLegitimate = false;
    } else if (result.riskScore >= 40) {
      result.riskLevel = "medium";
      result.isLegitimate = true;
    } else {
      result.riskLevel = "low";
      result.isLegitimate = true;
    }

    result.confidence = Math.max(0, Math.min(100, 100 - result.riskScore));

    // Generate recommendations
    if (result.riskLevel === "critical") {
      result.recommendations.push("Immediate manual review required");
      result.recommendations.push("Consider account suspension");
    } else if (result.riskLevel === "high") {
      result.recommendations.push("Flag for manual review");
      result.recommendations.push("Monitor user activity closely");
    } else if (result.riskLevel === "medium") {
      result.recommendations.push("Monitor user activity");
    } else {
      result.recommendations.push("Normal validation - no action required");
    }

    return new Response(
      JSON.stringify(result),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (e) {
    console.error("Speed validation error:", e);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}); 