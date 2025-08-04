// Shared configuration for CRDO Backend functions

export interface Config {
  supabaseUrl: string;
  serviceKey: string;
  corsHeaders: Record<string, string>;
  rateLimits: {
    finishRun: {
      maxRequests: number;
      windowMs: number;
    };
  };
  validation: {
    maxDistance: number;
    maxDuration: number;
    maxAverageSpeed: number;
    maxPeakSpeed: number;
  };
  achievements: {
    distanceBased: Array<{
      description: string;
      distance: number;
      points: number;
      gems: number;
    }>;
    streakBased: Array<{
      description: string;
      days: number;
      points: number;
      gems: number;
    }>;
    speedBased: Array<{
      description: string;
      speed: number;
      points: number;
      gems: number;
    }>;
  };
}

export const config: Config = {
  supabaseUrl: Deno.env.get("SUPABASE_URL") || "",
  serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "",
  corsHeaders: {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  },
  rateLimits: {
    finishRun: {
      maxRequests: 10,
      windowMs: 60 * 1000, // 1 minute
    },
  },
  validation: {
    maxDistance: 100, // 100 miles
    maxDuration: 86400, // 24 hours
    maxAverageSpeed: 27, // 27 mph
    maxPeakSpeed: 33, // 33 mph
  },
  achievements: {
    distanceBased: [
      {
        description: "Complete a 5km run",
        distance: 3.1, // 5km in miles
        points: 50,
        gems: 5,
      },
      {
        description: "Complete a 10km run",
        distance: 6.2, // 10km in miles
        points: 100,
        gems: 10,
      },
    ],
    streakBased: [
      {
        description: "Maintain a 7-day streak",
        days: 7,
        points: 75,
        gems: 7,
      },
      {
        description: "Maintain a 30-day streak", 
        days: 30,
        points: 200,
        gems: 30,
      },
    ],
    speedBased: [
      {
        description: "Maintain an average speed of 3 m/s",
        speed: 10.8, // 3 m/s in mph
        points: 150,
        gems: 15,
      },
    ],
  },
}; 