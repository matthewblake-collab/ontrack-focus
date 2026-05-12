// barcode-lookup — resolves a product barcode via Open Food Facts and caches the
// result into the `products` table, returning the cached row (or `null` on a miss).
//
// Called by the OnTrack iOS app (BarcodeLookupViewModel) when a scanned barcode
// isn't already in `products`. Uses the service-role key for the write-back so it
// bypasses the products RLS (which only allows authenticated reads + user-source
// writes). Request: POST { "barcode": "<digits>" }. Response: a product row
// { id, product_name, serving_size, serving_units, dosage_form } or the JSON
// literal `null`.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

function inferDosageForm(name: string, categories: string[]): string | null {
  const t = (name + " " + categories.join(" ")).toLowerCase();
  if (/\b(capsule|cap|caps|softgel|vegecap)\b/.test(t)) return "capsules";
  if (/\b(tablet|tab|caplet)\b/.test(t)) return "tablets";
  if (/\b(gummy|gummies|pastille|chewable)\b/.test(t)) return "gummy";
  if (/\b(oil|drops|liquid|syrup|tincture|elixir|shot)\b/.test(t)) return "liquid";
  if (/\b(bar|bars|cookie|brownie)\b/.test(t)) return "bar";
  if (/\b(spray|mist)\b/.test(t)) return "spray";
  if (/\b(powder|protein|creatine|pre[- ]?workout|bcaa|eaa|amino|glutamine|electrolyte|hydration|isolate|blend|sachet)\b/.test(t)) return "powder";
  return null;
}

function toNumberOrNull(v: unknown): number | null {
  if (typeof v === "number" && isFinite(v)) return v;
  if (typeof v === "string") {
    const n = parseFloat(v);
    return isFinite(n) ? n : null;
  }
  return null;
}

const PROJECTION = "id, product_name, serving_size, serving_units, dosage_form";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  let barcode = "";
  try {
    const body = await req.json();
    barcode = String(body?.barcode ?? "").trim();
  } catch {
    return new Response(JSON.stringify({ error: "invalid body" }), { status: 400, headers: jsonHeaders });
  }
  if (!barcode || !/^[0-9]{6,14}$/.test(barcode)) {
    return new Response(JSON.stringify({ error: "invalid barcode" }), { status: 400, headers: jsonHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const sb = createClient(supabaseUrl, serviceKey);

  // Open Food Facts lookup (8s ceiling so a slow OFF never blocks the scan flow).
  let off: any = null;
  try {
    const url = `https://world.openfoodfacts.org/api/v2/product/${barcode}.json?fields=code,product_name,brands,serving_quantity,serving_quantity_unit,nutriments,image_url,categories_tags`;
    const res = await fetch(url, {
      headers: { "User-Agent": "OnTrack/1.0 (matthewblake@coastandcountryenergy.com.au)" },
      signal: AbortSignal.timeout(8000),
    });
    if (res.ok) off = await res.json();
  } catch {
    off = null;
  }

  const product = off?.status === 1 ? off.product : null;
  const name = String(product?.product_name ?? "").trim();
  if (!product || !name) {
    return new Response("null", { status: 200, headers: jsonHeaders });
  }

  const categories: string[] = Array.isArray(product.categories_tags) ? product.categories_tags : [];
  const brand = String(product.brands ?? "").split(",")[0].trim() || null;
  const row = {
    source: "off",
    barcode,
    brand,
    product_name: name,
    serving_size: toNumberOrNull(product.serving_quantity),
    serving_units: (typeof product.serving_quantity_unit === "string" && product.serving_quantity_unit.trim()) || null,
    servings_per_container: null,
    dosage_form: inferDosageForm(name, categories),
    ingredients_json: product.nutriments ?? null,
    image_url: (typeof product.image_url === "string" && product.image_url) || null,
    country: "AU",
    verified: false,
  };

  // Two-step write — the products(barcode) unique index is PARTIAL
  // (WHERE barcode IS NOT NULL), so PostgREST upsert/onConflict can't target it.
  try {
    const { data: existing } = await sb.from("products").select("id").eq("barcode", barcode).limit(1).maybeSingle();
    if (existing?.id) {
      const { source: _s, barcode: _b, country: _c, ...enrich } = row;
      await sb.from("products").update({ ...enrich, updated_at: new Date().toISOString() }).eq("id", existing.id);
    } else {
      await sb.from("products").insert(row);
    }
  } catch (e) {
    console.error("barcode-lookup write failed:", e);
    return new Response("null", { status: 200, headers: jsonHeaders });
  }

  const { data: finalRow } = await sb.from("products").select(PROJECTION).eq("barcode", barcode).limit(1).maybeSingle();
  return new Response(JSON.stringify(finalRow ?? null), { status: 200, headers: jsonHeaders });
});
