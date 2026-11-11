import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Json = Record<string, unknown>;
function json(status: number, body: Json): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
function getSecretMap(name: string): Record<string, string> {
  const raw = Deno.env.get(name);
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed as Record<string, string> : {};
  } catch { return {}; }
}
function supabaseKeys() {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? getSecretMap("SUPABASE_PUBLISHABLE_KEYS")["default"];
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? getSecretMap("SUPABASE_SECRET_KEYS")["default"];
  if (!url || !anon || !service) throw new Error("SUPABASE_FUNCTION_CONFIG_MISSING");
  return { url, anon, service };
}
async function restGet<T>(url: string, serviceKey: string): Promise<T> {
  const response = await fetch(url, {
    headers: { apikey: serviceKey, Authorization: "Bearer " + serviceKey, Accept: "application/json" },
  });
  if (!response.ok) throw new Error("DATABASE_READ_FAILED_" + response.status);
  return await response.json() as T;
}
const categories = [
  "road_reconstruction", "water_supply", "sewerage", "stormwater_drainage",
  "electricity", "telecom", "gas", "borewell_groundwater", "building_planning",
  "public_health_engineering", "other",
] as const;
type Category = typeof categories[number];
function chooseCategory(explicit: string, text: string): Category {
  const value = explicit.toLowerCase().replace(/[\s-]+/g, "_");
  const aliases: Record<string, Category> = {
    roads: "road_reconstruction", road: "road_reconstruction", road_work: "road_reconstruction",
    water: "water_supply", drinking_water: "water_supply",
    drainage: "stormwater_drainage", stormwater: "stormwater_drainage", storm_water: "stormwater_drainage",
    sewer: "sewerage", sewage: "sewerage",
    electricity: "electricity", power: "electricity",
    telecom: "telecom", telecommunications: "telecom", internet: "telecom",
    gas: "gas", pipeline_gas: "gas",
    borewell: "borewell_groundwater", groundwater: "borewell_groundwater",
    building: "building_planning", building_approval: "building_planning",
    public_health: "public_health_engineering",
  };
  if (categories.includes(value as Category)) return value as Category;
  if (aliases[value]) return aliases[value];
  if (text.includes("water supply") || text.includes("drinking water") || text.includes("water main")) return "water_supply";
  if (text.includes("sewer") || text.includes("sewage")) return "sewerage";
  if (text.includes("stormwater") || text.includes("storm water") || text.includes("drain")) return "stormwater_drainage";
  if (text.includes("electric") || text.includes("power cable") || text.includes("transformer")) return "electricity";
  if (text.includes("telecom") || text.includes("fibre") || text.includes("fiber") || text.includes("telephone")) return "telecom";
  if (text.includes("gas")) return "gas";
  if (text.includes("borewell") || text.includes("groundwater") || text.includes("ground water")) return "borewell_groundwater";
  if (text.includes("building") || text.includes("planning") || text.includes("approval")) return "building_planning";
  if (text.includes("road") || text.includes("pavement") || text.includes("resurfacing") || text.includes("reconstruction")) return "road_reconstruction";
  if (text.includes("health") || text.includes("contamination")) return "public_health_engineering";
  return "other";
}
function departmentsFor(category: Category): string[] {
  const map: Record<Category, string[]> = {
    road_reconstruction: ["Roads & Highways", "Municipal Corporation"],
    water_supply: ["Water Supply", "Public Health Engineering"],
    sewerage: ["Sewage and Drainage", "Public Health Engineering"],
    stormwater_drainage: ["Stormwater Management", "Sewage and Drainage", "Municipal Corporation"],
    electricity: ["Electricity"],
    telecom: ["Telecommunications"],
    gas: ["Gas"],
    borewell_groundwater: ["Groundwater & Borewell Regulation", "Water Supply"],
    building_planning: ["Town Planning & Building Regulation", "Municipal Corporation"],
    public_health_engineering: ["Public Health Engineering", "Municipal Corporation"],
    other: ["Municipal Corporation"],
  };
  return map[category];
}
function assessCase(record: Record<string, unknown>, purpose: string): Json {
  const title = String(record.title ?? "Untitled case");
  const description = String(record.description ?? "");
  const road = String(record.road_name ?? "");
  const city = String(record.city ?? "location not stated");
  const status = String(record.status ?? "status not reported");
  const start = record.planned_start_date ? String(record.planned_start_date) : "";
  const end = record.planned_end_date ? String(record.planned_end_date) : "";
  const explicit = String(record.case_category ?? "");
  const activity = String(record.work_activity ?? "");
  const searchable = [title, description, road, explicit, activity].join(" ").toLowerCase();

  const category = chooseCategory(explicit, searchable);
  const urgentTerms = [
    "gas leak", "exposed wire", "electric shock", "fire", "collapse", "cave-in",
    "burst main", "major leak", "contamination", "injury", "injured", "flooding",
    "overflow", "accident", "emergency", "sinkhole",
  ];
  const elevatedTerms = [
    "road closure", "traffic diversion", "school", "hospital", "multiple department",
    "multiple departments", "water interruption", "power outage", "major work",
    "night work", "public disruption",
  ];
  const urgent = urgentTerms.some((term) => searchable.includes(term));
  const elevated = elevatedTerms.some((term) => searchable.includes(term));
  const priority = urgent ? "urgent_human_review" : elevated ? "elevated" : "routine";

  const missing: string[] = [];
  if (description.trim().length < 25) missing.push("Add a clearer work description and explain the public impact.");
  if (!road.trim()) missing.push("Confirm the road or locality through the authorised case record.");
  if (!start) missing.push("Confirm the proposed start date.");
  if (!end) missing.push("Confirm the proposed completion date.");
  if (start && end && end < start) missing.push("Correct the planned dates: the completion date is earlier than the start date.");

  const flags: string[] = [];
  if (urgent) flags.push("Potentially urgent wording detected; immediate human review is required.");
  if (elevated) flags.push("Potential public disruption or multi-department coordination is indicated.");
  if (category === "road_reconstruction" || category === "stormwater_drainage") {
    flags.push("Check whether road, drainage and other service owners need to coordinate the work.");
  }
  if (category === "water_supply" || category === "sewerage" || category === "gas" || category === "electricity" || category === "telecom") {
    flags.push("Confirm the responsible asset-owning authority and obtain its current site-specific clearance through official channels.");
  }
  if (record.work_radius_m !== null && record.work_radius_m !== undefined) {
    flags.push("The work-radius value is an applicant-provided estimate, not a verified footprint.");
  }

  const checks = [
    "Verify the submitted scope, drawings and permissions with the responsible authority.",
    "Obtain current written responses from affected utility-owning departments before scheduling work.",
    "Confirm traffic, pedestrian-access and public-notification arrangements where relevant.",
    "Record restoration, inspection and completion responsibilities.",
    "Have an authorised officer review this rule-based assessment; it is not an approval or excavation clearance.",
  ];
  if (purpose === "summary") {
    checks.splice(1, 1);
  }
  const confidence = explicit && category !== "other" ? 0.82 :
    category !== "other" ? 0.68 : 0.42;
  const labels: Record<Category, string> = {
    road_reconstruction: "road reconstruction", water_supply: "water supply",
    sewerage: "sewerage", stormwater_drainage: "stormwater drainage",
    electricity: "electricity", telecom: "telecommunications", gas: "gas",
    borewell_groundwater: "borewell / groundwater", building_planning: "building planning",
    public_health_engineering: "public-health engineering", other: "general infrastructure",
  };
  const purposeIntro = purpose === "triage" ? "Triage" :
    purpose === "coordination" ? "Coordination review" : "Summary";
  return {
    summary: purposeIntro + " for '" + title + "': this is a " + labels[category] +
      " case in " + city + " with current status '" + status +
      "'. The built-in rules matched the available case text; an authorised officer must verify the classification and next steps.",
    category,
    priority_band: priority,
    suggested_departments: departmentsFor(category),
    coordination_flags: flags,
    missing_information: missing,
    recommended_checks: checks,
    confidence,
    assessment_method: "deterministic_keyword_rules",
    limitations: "Rule match strength is not a calibrated probability. This assessment cannot verify site conditions, utility positions, permits or legal compliance.",
    work_activity: activity,
    road_name: road,
  };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json(405, { error: "METHOD_NOT_ALLOWED" });
  const bearer = request.headers.get("Authorization") ?? "";
  const tokenMatch = bearer.match(/^Bearer\s+(.+)$/i);
  if (!tokenMatch) return json(401, { error: "AUTHENTICATION_REQUIRED" });

  let body: { request_id?: unknown; purpose?: unknown };
  try { body = await request.json(); } catch { return json(400, { error: "INVALID_JSON" }); }
  const requestId = typeof body.request_id === "string" ? body.request_id.trim() : "";
  const purpose = typeof body.purpose === "string" ? body.purpose : "summary";
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidPattern.test(requestId)) return json(400, { error: "INVALID_REQUEST_ID" });
  if (!["triage", "summary", "coordination"].includes(purpose)) return json(400, { error: "INVALID_PURPOSE" });

  let keys: ReturnType<typeof supabaseKeys>;
  try { keys = supabaseKeys(); } catch { return json(503, { error: "SUPABASE_FUNCTION_CONFIG_MISSING" }); }
  const authResponse = await fetch(keys.url + "/auth/v1/user", {
    headers: { apikey: keys.anon, Authorization: "Bearer " + tokenMatch[1] },
  });
  if (!authResponse.ok) return json(401, { error: "INVALID_SESSION" });
  const authUser = await authResponse.json() as { id?: string };
  if (!authUser.id || !uuidPattern.test(authUser.id)) return json(401, { error: "INVALID_SESSION" });

  try {
    const profileUrl = new URL(keys.url + "/rest/v1/profiles");
    profileUrl.searchParams.set("select", "id,role,department_id");
    profileUrl.searchParams.set("id", "eq." + authUser.id);
    const profiles = await restGet<Array<{ id: string; role: string; department_id: string | null }>>(profileUrl.toString(), keys.service);
    const profile = profiles[0];
    if (!profile) return json(403, { error: "PROFILE_NOT_FOUND" });
    if (!["admin", "coordinator", "department"].includes(profile.role)) return json(403, { error: "STAFF_ACCESS_REQUIRED" });

    const requestUrl = new URL(keys.url + "/rest/v1/excavation_requests");
    requestUrl.searchParams.set("select", "id,title,description,road_name,city,status,planned_start_date,planned_end_date,department_id,case_category,work_activity,work_radius_m");
    requestUrl.searchParams.set("id", "eq." + requestId);
    const requests = await restGet<Array<Record<string, unknown>>>(requestUrl.toString(), keys.service);
    const caseRecord = requests[0];
    if (!caseRecord) return json(404, { error: "CASE_NOT_FOUND" });

    if (profile.role === "department") {
      if (!profile.department_id) return json(403, { error: "DEPARTMENT_NOT_ASSIGNED" });
      const assignmentUrl = new URL(keys.url + "/rest/v1/request_department_reviews");
      assignmentUrl.searchParams.set("select", "id");
      assignmentUrl.searchParams.set("request_id", "eq." + requestId);
      assignmentUrl.searchParams.set("department_id", "eq." + profile.department_id);
      const assignments = await restGet<Array<{ id: string }>>(assignmentUrl.toString(), keys.service);
      if (assignments.length === 0) return json(403, { error: "CASE_NOT_ASSIGNED_TO_YOUR_DEPARTMENT" });
    }

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const usageUrl = new URL(keys.url + "/rest/v1/case_ai_assessments");
    usageUrl.searchParams.set("select", "id");
    usageUrl.searchParams.set("created_by", "eq." + authUser.id);
    usageUrl.searchParams.set("created_at", "gte." + since);
    usageUrl.searchParams.set("limit", "11");
    const recentUsage = await restGet<Array<{ id: string }>>(usageUrl.toString(), keys.service);
    if (recentUsage.length >= 10) {
      return json(429, { error: "DAILY_RULE_LIMIT_REACHED", limit: 10, window: "24 hours" });
    }

    const assessment = assessCase(caseRecord, purpose);
    const insertResponse = await fetch(keys.url + "/rest/v1/case_ai_assessments", {
      method: "POST",
      headers: {
        apikey: keys.service,
        Authorization: "Bearer " + keys.service,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify({
        request_id: requestId,
        created_by: authUser.id,
        provider: "samanvay_builtin_rules",
        model: "samanvay-rules-v1",
        purpose,
        assessment,
      }),
    });
    if (!insertResponse.ok) {
      console.error("Unable to persist built-in case assessment", insertResponse.status, (await insertResponse.text()).slice(0, 500));
      return json(500, { error: "ASSESSMENT_AUDIT_PERSIST_FAILED" });
    }
    const saved = await insertResponse.json() as Array<{ id: string; created_at: string }>;
    return json(200, {
      assessment_id: saved[0]?.id ?? null,
      created_at: saved[0]?.created_at ?? null,
      assessment,
      engine: "samanvay-rules-v1",
      disclaimer: "Rule-based administrative assistance only. An authorised officer must verify the information and make every official decision. This is not a permit or excavation clearance.",
    });
  } catch (error) {
    console.error("SAMANVAY case rules error", error instanceof Error ? error.message : "unknown");
    return json(500, { error: "INTERNAL_SERVER_ERROR" });
  }
});
