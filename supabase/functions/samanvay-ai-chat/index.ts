import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ChatMessage = { role: "user" | "assistant"; content: string };

function json(status: number, body: Record<string, unknown>): Response {
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
    return parsed && typeof parsed === "object"
      ? parsed as Record<string, string>
      : {};
  } catch {
    return {};
  }
}

function getSupabaseKeys() {
  const url = Deno.env.get("SUPABASE_URL");
  const publishable = Deno.env.get("SUPABASE_ANON_KEY") ??
    getSecretMap("SUPABASE_PUBLISHABLE_KEYS")["default"];
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    getSecretMap("SUPABASE_SECRET_KEYS")["default"];
  if (!url || !publishable || !secret) {
    throw new Error("SUPABASE_FUNCTION_CONFIG_MISSING");
  }
  return { url, publishable, secret };
}

async function readJson<T>(url: string, serviceKey: string): Promise<T> {
  const response = await fetch(url, {
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      Accept: "application/json",
    },
  });
  if (!response.ok) throw new Error(`DATABASE_READ_FAILED_${response.status}`);
  return await response.json() as T;
}

type RequestContextRow = {
  request_number?: number | string;
  title?: string;
  status?: string;
  case_category?: string;
  road_name?: string;
  city?: string;
  planned_start_date?: string;
  planned_end_date?: string;
  created_at?: string;
  updated_at?: string;
};
type NoticeContextRow = {
  notice_code?: string;
  title?: string;
  notice_type?: string;
  summary?: string;
  city?: string;
  district?: string;
  area_label?: string;
  responsible_department_name?: string;
  starts_on?: string;
  ends_on?: string;
  progress_percent?: number;
  notice_status?: string;
  source_url?: string;
};
type UserContext = {
  displayName: string;
  role: string;
  departmentName: string;
  requests: RequestContextRow[];
  notices: NoticeContextRow[];
};

type OfficialSourceRow = {
  source_key?: string; agency?: string; dataset_name?: string; source_url?: string;
  geography?: string; data_theme?: string; access_mode?: string;
  integration_status?: string; format?: string; last_checked_at?: string; notes?: string;
};
type CoverageRow = {
  state_ut_id?: string; data_domain?: string; responsible_authority?: string;
  official_portal_url?: string; national_source_url?: string;
  coverage_status?: string; data_granularity?: string;
  operational_use_allowed?: boolean; last_checked_at?: string; notes?: string;
};
type StateRow = { id?: string; name?: string };
type SafeReference = {
  id: string; title: string; agency: string; url: string;
  geography: string; status: string; checked_at: string; kind: string;
  note: string;
};

function scoreReference(text: string, terms: string[]): number {
  const haystack = text.toLowerCase();
  return terms.reduce((score, term) => score + (haystack.includes(term) ? 1 : 0), 0);
}

async function exactPublicRowCount(
  supabaseUrl: string,
  serviceKey: string,
  table: string,
): Promise<number | null> {
  try {
    const url = new URL(supabaseUrl + "/rest/v1/" + table);
    url.searchParams.set("select", "id");
    const response = await fetch(url.toString(), {
      method: "HEAD",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Range-Unit": "items",
        Range: "0-0",
        Prefer: "count=exact",
      },
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) return null;
    const contentRange = response.headers.get("content-range") ?? "";
    const countText = contentRange.substring(contentRange.lastIndexOf("/") + 1);
    if (!countText || !Array.from(countText).every((character) => character >= "0" && character <= "9")) return null;
    return Number(countText);
  } catch {
    return null;
  }
}

async function retrieveLivePublicSnapshot(
  supabaseUrl: string,
  serviceKey: string,
): Promise<SafeReference | null> {
  const tables = [
    ["india_state_uts", "State/UT directory rows"],
    ["india_data_coverage", "State/UT and data-domain coverage rows"],
    ["official_data_sources", "registered official source records"],
    ["groundwater_state_assessments", "groundwater state assessments"],
    ["groundwater_district_assessments", "groundwater district assessments"],
    ["groundwater_station_observations", "groundwater telemetry observations"],
    ["building_approval_public_register_records", "public building-register records"],
    ["india_administrative_units", "administrative-unit directory rows"],
    ["india_national_authority_directory", "national authority directory records"],
  ] as const;

  const counts = await Promise.all(tables.map(async ([table, label]) => ({
    label,
    count: await exactPublicRowCount(supabaseUrl, serviceKey, table),
  })));
  const available = counts.filter((item) => item.count !== null);
  if (available.length === 0) return null;

  const note = [
    "Live exact row counts queried from SAMANVAY public tables at " + new Date().toISOString() + ".",
    ...available.map((item) => item.label + ": " + item.count),
    "Counts describe records stored in SAMANVAY only; they do not certify completeness, source freshness, positional accuracy, authority permission, or operational readiness.",
    "A zero administrative-unit count means the directory has no rows; it does not mean those places do not exist.",
    "No row count, missing record, or empty map layer may be treated as proof that an underground utility is absent or that excavation is safe.",
  ].join(" ");

  return {
    id: "LIVE1",
    title: "SAMANVAY live public-data row-count snapshot",
    agency: "SAMANVAY public database",
    url: "",
    geography: "India",
    status: "live_counts_not_quality_certified",
    checked_at: new Date().toISOString(),
    kind: "live_public_snapshot",
    note: note.slice(0, 1800),
  };
}

async function retrieveUserContext(
  supabaseUrl: string,
  serviceKey: string,
  userId: string,
  profile: { role: string; display_name?: string | null; department_id?: string | null },
): Promise<UserContext> {
  let departmentName = "";
  if (profile.department_id) {
    try {
      const departmentUrl = new URL(supabaseUrl + "/rest/v1/departments");
      departmentUrl.searchParams.set("select", "name");
      departmentUrl.searchParams.set("id", "eq." + profile.department_id);
      departmentUrl.searchParams.set("limit", "1");
      const departments = await readJson<Array<{ name?: string }>>(departmentUrl.toString(), serviceKey);
      departmentName = departments[0]?.name ?? "";
    } catch {
      departmentName = "";
    }
  }

  // Only retrieve case metadata the authenticated role is entitled to see.
  // Descriptions, attachments, chat messages, private identifiers, coordinates,
  // and exact underground-asset geometry are deliberately excluded.
  const requestUrl = new URL(supabaseUrl + "/rest/v1/excavation_requests");
  requestUrl.searchParams.set(
    "select",
    "request_number,title,status,case_category,road_name,city,planned_start_date,planned_end_date,created_at,updated_at",
  );
  requestUrl.searchParams.set("order", "created_at.desc");
  requestUrl.searchParams.set("limit", "30");
  if (profile.role === "requester" || profile.role === "citizen") {
    requestUrl.searchParams.set("requester_id", "eq." + userId);
  } else if (profile.role === "department") {
    if (!profile.department_id) {
      requestUrl.searchParams.set("request_number", "eq.-1");
    } else {
      requestUrl.searchParams.set("department_id", "eq." + profile.department_id);
    }
  }
  // Coordinator/admin roles can see request metadata under their authorised
  // app role. They still receive no descriptions, attachments or utility routes.
  let requests: RequestContextRow[] = [];
  try {
    requests = await readJson<RequestContextRow[]>(requestUrl.toString(), serviceKey);
  } catch {
    requests = [];
  }

  // Only authority-published public notices are included in the assistant.
  const noticesUrl = new URL(supabaseUrl + "/rest/v1/public_excavation_notices");
  noticesUrl.searchParams.set(
    "select",
    "notice_code,title,notice_type,summary,city,district,area_label,responsible_department_name,starts_on,ends_on,progress_percent,notice_status,source_url",
  );
  noticesUrl.searchParams.set("notice_status", "in.(published,active)");
  noticesUrl.searchParams.set("order", "starts_on.asc");
  noticesUrl.searchParams.set("limit", "50");
  let notices: NoticeContextRow[] = [];
  try {
    notices = await readJson<NoticeContextRow[]>(noticesUrl.toString(), serviceKey);
  } catch {
    notices = [];
  }

  return {
    displayName: (profile.display_name ?? "").trim(),
    role: profile.role,
    departmentName,
    requests,
    notices,
  };
}

function contextualReply(prompt: string, context: UserContext): string | null {
  const q = prompt.toLowerCase();

  if (includesAny(q, [
    "my request", "my requests", "request status", "track my", "my case",
    "my cases", "show my request", "show my cases", "status of request",
  ])) {
    const number = prompt.match(/(?:request|case)\s*(?:number|no\.?|#)?\s*(\d{1,14})/i)?.[1];
    const matches = number
      ? context.requests.filter((item) => String(item.request_number ?? "") === number)
      : context.requests.slice(0, 6);
    if (!matches.length) {
      return number
        ? "I could not find that request number in the cases visible to your signed-in account. Check the number or contact the assigned department."
        : "There are no request records currently visible to your signed-in account. Once you submit a request, ANIL can summarise its recorded status here.";
    }
    return matches.map((item) => {
      const place = [item.road_name, item.city].filter(Boolean).join(", ");
      const dates = [item.planned_start_date, item.planned_end_date].filter(Boolean).join(" to ");
      return [
        "Request #" + String(item.request_number ?? "—"),
        (item.title ?? item.case_category ?? "Infrastructure request").replaceAll("_", " "),
        "Status: " + String(item.status ?? "not reported"),
        place ? "Location: " + place : "",
        dates ? "Planned dates: " + dates : "",
      ].filter(Boolean).join(" · ");
    }).join("\n`);
  }

  if (includesAny(q, ["my profile", "my department", "which department am i", "who am i"])) {
    const name = context.displayName || "Signed-in user";
    const department = context.departmentName ? " · Department: " + context.departmentName : "";
    return name + " · Role: " + context.role + department + ".";
  }

  if (includesAny(q, [
    "nearby excavation", "excavations near", "near me", "nearby work",
    "works near", "excavation around", "public work near", "no-dig notice",
    "no dig notice", "active excavation",
  ])) {
    const explicit = prompt.match(/\b(?:near|around|in|at)\s+([a-z][a-z\s-]{1,35})/i)?.[1]?.trim();
    const recentCity = context.requests.find((item) => item.city)?.city ?? "";
    const candidate = (explicit && !["me", "my location", "here"].includes(explicit.toLowerCase()))
      ? explicit
      : recentCity;
    if (!candidate) {
      return "ANIL has no live GPS location in this chat. Share your city or locality name and I can check the published public-work notices available in SAMANVAY for that area.";
    }
    const area = candidate.toLowerCase();
    const matches = context.notices.filter((item) => [
      item.city, item.district, item.area_label,
    ].some((value) => (value ?? "").toLowerCase().includes(area) || area.includes((value ?? "").toLowerCase()) && (value ?? "").length > 2));
    if (!matches.length) {
      return "I found no published SAMANVAY work notices matching " + candidate + " in the current public notice feed. This feed may be incomplete; check the relevant local authority before making decisions.";
    }
    return "Published public-work notices matching " + candidate + ":\n" + matches.slice(0, 6).map((item) => [
      item.notice_code ?? "Notice",
      item.title ?? "Public work",
      [item.area_label, item.city, item.district].filter(Boolean).join(", "),
      item.responsible_department_name ? "Department: " + item.responsible_department_name : "",
      [item.starts_on, item.ends_on].filter(Boolean).join(" to "),
      item.notice_status ?? "",
    ].filter(Boolean).join(" · ")).join("\n`);
  }

  return null;
}


async function retrieveSafeReferences(
  supabaseUrl: string,
  serviceKey: string,
  prompt: string,
): Promise<SafeReference[]> {
  const terms = Array.from(new Set(
    (prompt.toLowerCase().match(/[\p{L}\p{N}]{3,}/gu) ?? [])
      .filter((term) => ![
        "what", "when", "where", "which", "does", "this", "that", "with",
        "from", "have", "help", "about", "please", "show", "tell", "explain",
        "your", "will", "would", "could", "should", "there", "their", "into",
        "near", "need", "want", "can", "the", "and", "for", "how"
      ].includes(term)),
  )).slice(0, 30);

  const sourcesUrl = new URL(supabaseUrl + "/rest/v1/official_data_sources");
  sourcesUrl.searchParams.set("select", "source_key,agency,dataset_name,source_url,geography,data_theme,access_mode,integration_status,format,last_checked_at,notes");
  sourcesUrl.searchParams.set("order", "last_checked_at.desc");
  sourcesUrl.searchParams.set("limit", "100");

  const coverageUrl = new URL(supabaseUrl + "/rest/v1/india_data_coverage");
  coverageUrl.searchParams.set("select", "state_ut_id,data_domain,responsible_authority,official_portal_url,national_source_url,coverage_status,data_granularity,operational_use_allowed,last_checked_at,notes");
  coverageUrl.searchParams.set("order", "last_checked_at.desc");
  coverageUrl.searchParams.set("limit", "450");

  const statesUrl = new URL(supabaseUrl + "/rest/v1/india_state_uts");
  statesUrl.searchParams.set("select", "id,name");
  statesUrl.searchParams.set("limit", "50");

  const [sourceResult, coverageResult, stateResult] = await Promise.allSettled([
    readJson<OfficialSourceRow[]>(sourcesUrl.toString(), serviceKey),
    readJson<CoverageRow[]>(coverageUrl.toString(), serviceKey),
    readJson<StateRow[]>(statesUrl.toString(), serviceKey),
  ]);
  const sourceRows = sourceResult.status === "fulfilled" ? sourceResult.value : [];
  const coverageRows = coverageResult.status === "fulfilled" ? coverageResult.value : [];
  const stateRows = stateResult.status === "fulfilled" ? stateResult.value : [];
  const stateNames = new Map(stateRows.map((row) => [row.id ?? "", row.name ?? ""]));

  const candidates: Array<{ score: number; reference: SafeReference }> = [];
  for (const row of sourceRows) {
    const searchable = [
      row.source_key, row.agency, row.dataset_name, row.geography,
      row.data_theme, row.access_mode, row.integration_status, row.format, row.notes,
    ].filter(Boolean).join(" ");
    const score = scoreReference(searchable, terms);
    if (score < 1) continue;
    candidates.push({
      score,
      reference: {
        id: "",
        title: (row.dataset_name ?? row.source_key ?? "Official data source").slice(0, 180),
        agency: (row.agency ?? "Publisher not stated").slice(0, 140),
        url: (row.source_url ?? "").slice(0, 500),
        geography: (row.geography ?? "Geography not stated").slice(0, 180),
        status: (row.integration_status ?? "status_not_reported").slice(0, 80),
        checked_at: row.last_checked_at ?? "",
        kind: "source_registry",
        note: (row.notes ?? "").slice(0, 260),
      },
    });
  }
  for (const row of coverageRows) {
    const stateName = stateNames.get(row.state_ut_id ?? "") ?? "";
    const searchable = [
      stateName, row.data_domain, row.responsible_authority, row.coverage_status,
      row.data_granularity,
      row.operational_use_allowed === true ? "operational allowed" : "operational not allowed",
      row.notes,
    ].filter(Boolean).join(" ");
    const score = scoreReference(searchable, terms);
    if (score < 1) continue;
    const sourceUrl = row.official_portal_url || row.national_source_url || "";
    candidates.push({
      score,
      reference: {
        id: "",
        title: (stateName || "State/UT") + " · " + (row.data_domain ?? "coverage") + " coverage status",
        agency: (row.responsible_authority ?? "Responsible authority not stated").slice(0, 140),
        url: sourceUrl.slice(0, 500),
        geography: stateName || "India",
        status: (row.coverage_status ?? "status_not_reported").slice(0, 100),
        checked_at: row.last_checked_at ?? "",
        kind: "state_coverage",
        note: (row.operational_use_allowed === true ? "Operational use allowed by metadata. " : "Operational use is not enabled by metadata. ") + (row.notes ?? "").slice(0, 220),
      },
    });
  }

  candidates.sort((a, b) =>
    b.score - a.score ||
    (b.reference.checked_at || "").localeCompare(a.reference.checked_at || ""),
  );
  return candidates.slice(0, 8).map((item, index) => ({
    ...item.reference,
    id: "S" + (index + 1),
  }));
}


function includesAny(text: string, terms: string[]): boolean {
  return terms.some((term) => text.includes(term));
}

function buildZeroCostReply(
  prompt: string,
  references: SafeReference[],
  liveSnapshot: SafeReference | null,
  userContext: UserContext,
): string {
  const personalised = contextualReply(prompt, userContext);
  if (personalised) return personalised;
  const q = prompt.toLowerCase();
  const refs = references.slice(0, 4).map((item) => "[" + item.id + "] " + item.title + " — " + item.agency);
  const refsText = refs.length ? "\n\nRelevant catalogue references:\n" + refs.join("\n") : "";
  const dataText = liveSnapshot && includesAny(q, ["dataset", "coverage", "data", "records", "groundwater", "source", "district", "state", "india"])
    ? "\n\n" + liveSnapshot.note
    : "";

  if (includesAny(q, ["exact utility", "utility alignment", "underground route", "pipe route", "cable route", "gas pipeline route", "utility depth", "access point", "map exact"])) {
    return "I can explain SAMANVAY's public mapping and coordination workflow, but I cannot disclose or infer precise underground utility alignments, depths, access points, or sensitive infrastructure details. Use the authorised department's controlled records and an approved site-verification process.";
  }
  if (includesAny(q, ["safe to dig", "safe to excavate", "no dig clearance", "is excavation safe", "utility absent", "clear to dig"])) {
    return "SAMANVAY's stored data or an empty map layer cannot establish that a site is safe to excavate. This assistant cannot issue a no-dig clearance. Obtain current written clearance and site verification from every relevant utility-owning authority before work is considered.";
  }
  if (includesAny(q, ["api key", "secret key", "system prompt", "reveal instructions", "password", "otp"])) {
    return "Do not share API keys, passwords, one-time codes, identity numbers, or confidential infrastructure drawings in this chat. I cannot retrieve or reveal secrets.";
  }
  if (includesAny(q, ["what is samanvay", "about samanvay", "what can i do", "what does this app", "features"])) {
    return "SAMANVAY is an infrastructure coordination platform. Its intended workflows bring citizens and authorised departments together around road works, excavation requests, water supply, sewerage, stormwater drainage, electricity, telecom, gas, groundwater and borewell regulation, building planning, public-health engineering, and cross-department coordination. Available functions depend on the modules and verified data enabled in the current deployment.";
  }
  if (includesAny(q, ["raise a request", "submit a request", "new request", "file a complaint", "report a problem", "citizen request"])) {
    return "To submit an infrastructure issue, sign in using the Citizen profile, open the request-creation area, choose the closest issue category, enter a clear title and description, add the road or locality and any requested supporting details, review the information, then submit. Keep private identity numbers and passwords out of the description. Save the request reference so you can follow its status.";
  }
  if (includesAny(q, ["status", "track request", "request stages", "workflow"])) {
    return "Open your request list and select the relevant request to see the status recorded by SAMANVAY. The current database contains submitted requests; do not assume that every planned workflow stage is active in this deployment. For an official decision or a status that appears incorrect, contact the assigned department or platform administrator.";
  }
  if (includesAny(q, ["department", "who handles", "which department", "route", "assign"])) {
    return "Typical routing guidance: water-supply issues → Water Supply; sewerage or drainage → Sewage and Drainage or Stormwater Management; electricity → Electricity; telecom → Telecommunications; gas → Gas; roads → Roads and Highways or Municipal Corporation; building planning → Town Planning and Building Regulation; groundwater or borewells → Groundwater and Borewell Regulation. This is a suggested route only; an authorised coordinator must confirm the responsible authority.";
  }
  if (includesAny(q, ["coordinate", "coordination", "multiple department", "cross department", "joint work"])) {
    return "For cross-department work, identify the work owner, affected service categories, proposed dates and public impact; request coordination from the responsible departments; record each department's response in the case; and ensure the authorised coordinator resolves conflicts before work begins. This assistant cannot approve a schedule or permit.";
  }
  if (includesAny(q, ["map", "gis", "satellite", "3d", "underground map"])) {
    return "The GIS module is intended to provide geographic context, administrative navigation and approved infrastructure layers. Public views should show only generalised, non-sensitive information; precise utility geometry must remain restricted to authorised roles. A layer appearing on the map does not itself certify positional accuracy, completeness, or excavation safety.";
  }
  if (includesAny(q, ["groundwater", "borewell", "water level", "water table"])) {
    return "SAMANVAY has groundwater-related records and assessment tables, but the presence of stored observations does not guarantee complete district coverage or a live reading at a particular location. Check the observation date, station, district and source metadata shown in the app. Use the relevant groundwater authority for an official assessment.";
  }
  if (includesAny(q, ["dataset", "coverage", "india wide", "india-wide", "north india", "state", "district", "official source", "data source", "records"])) {
    return "I can report what is stored in SAMANVAY and show catalogue references, but I must distinguish stored records from verified national coverage. Coverage metadata is not the same as an imported, quality-checked, operational dataset. Check the source, geography, last-checked date, coverage status and permitted-use field before relying on a dataset." + refsText + dataText;
  }
  if (includesAny(q, ["login", "sign in", "cannot login", "forgot password", "profile"])) {
    return "Use the account registered for your SAMANVAY role and sign in through the app's login screen. The role and department access are checked against the authenticated profile. If the correct portal is missing, ask the administrator to verify the profile role and department assignment; do not share your password or OTP in chat.";
  }
  return "Tell me what you need help with in SAMANVAY. I can check request metadata visible to your role, published public-work notices, department routing, GIS layer status and registered data sources. For nearby works, include a city or locality; live GPS is not shared with ANIL automatically.";
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json(405, { error: "METHOD_NOT_ALLOWED" });

  const bearer = request.headers.get("Authorization") ?? "";
  const tokenMatch = bearer.match(/^Bearer\s+(.+)$/i);
  if (!tokenMatch) return json(401, { error: "AUTHENTICATION_REQUIRED" });

  let body: { messages?: unknown };
  try { body = await request.json(); } catch { return json(400, { error: "INVALID_JSON" }); }
  if (!Array.isArray(body.messages) || body.messages.length < 1 || body.messages.length > 12) {
    return json(400, { error: "INVALID_MESSAGE_HISTORY" });
  }

  const messages: ChatMessage[] = [];
  let totalCharacters = 0;
  for (const raw of body.messages) {
    if (!raw || typeof raw !== "object") return json(400, { error: "INVALID_MESSAGE" });
    const item = raw as Record<string, unknown>;
    const role = item.role;
    const content = typeof item.content === "string" ? item.content.trim() : "";
    if ((role !== "user" && role !== "assistant") || content.length < 1 || content.length > 1200) {
      return json(400, { error: "INVALID_MESSAGE" });
    }
    totalCharacters += content.length;
    if (totalCharacters > 9000) return json(413, { error: "CHAT_CONTEXT_TOO_LARGE" });
    messages.push({ role, content });
  }
  if (messages[messages.length - 1].role !== "user") return json(400, { error: "LATEST_MESSAGE_MUST_BE_USER" });

  let keys: ReturnType<typeof getSupabaseKeys>;
  try { keys = getSupabaseKeys(); } catch { return json(503, { error: "SUPABASE_FUNCTION_CONFIG_MISSING" }); }

  const authResponse = await fetch(keys.url + "/auth/v1/user", {
    headers: { apikey: keys.publishable, Authorization: "Bearer " + tokenMatch[1] },
  });
  if (!authResponse.ok) return json(401, { error: "INVALID_SESSION" });
  const authUser = await authResponse.json() as { id?: string };
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!authUser.id || !uuidPattern.test(authUser.id)) return json(401, { error: "INVALID_SESSION" });

  try {
    const profileUrl = new URL(keys.url + "/rest/v1/profiles");
    profileUrl.searchParams.set("select", "id,role,display_name,department_id");
    profileUrl.searchParams.set("id", "eq." + authUser.id);
    const profiles = await readJson<Array<{
      id: string; role: string; display_name?: string | null; department_id?: string | null;
    }>>(profileUrl.toString(), keys.secret);
    const profile = profiles[0];
    if (!profile) return json(403, { error: "PROFILE_NOT_FOUND" });
    if (!["requester", "citizen", "department", "coordinator", "admin"].includes(profile.role)) {
      return json(403, { error: "PROFILE_ROLE_NOT_SUPPORTED" });
    }

    const prompt = messages[messages.length - 1].content;
    const [userContext, catalogueReferences] = await Promise.all([
      retrieveUserContext(keys.url, keys.secret, authUser.id, profile),
      retrieveSafeReferences(keys.url, keys.secret, prompt),
    ]);
    const isDataQuestion = includesAny(prompt.toLowerCase(), [
      "dataset", "coverage", "data", "records", "groundwater", "source", "district", "state", "india",
    ]);
    const liveSnapshot = isDataQuestion
      ? await retrieveLivePublicSnapshot(keys.url, keys.secret)
      : null;
    const references = liveSnapshot ? [...catalogueReferences, liveSnapshot] : catalogueReferences;
    const reply = buildZeroCostReply(prompt, references, liveSnapshot, userContext);
    return json(200, {
      reply,
      mode: "contextual_retrieval",
      model: "anil-samanvay-context-v1",
      sources: references.map(({ id, title, agency, url, geography, status, checked_at, kind, note }) => ({
        id, title, agency, url, geography, status, checked_at, kind, note,
      })),
      disclaimer: "Built-in rule-based guidance and public database metadata only. No paid external AI API is used. Verify official decisions and infrastructure information through authorised records and relevant authorities.",
    });
  } catch (error) {
    console.error("SAMANVAY built-in assistant error", error instanceof Error ? error.message : "unknown");
    return json(500, { error: "INTERNAL_SERVER_ERROR" });
  }
});
