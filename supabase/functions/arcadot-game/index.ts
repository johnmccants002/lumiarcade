import { createClient } from "npm:@supabase/supabase-js@2";
import {
  type ArcadotRepository,
  type GameSlug,
  handleArcadotGameRequest,
} from "./handler.ts";

const projectURL = Deno.env.get("SUPABASE_URL") ?? "";
const publishableKeys = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}");
const secretKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
const publishableKey = publishableKeys.default ?? "";
const secretKey = secretKeys.default ?? "";
const admin = createClient(projectURL, secretKey);

const repository: ArcadotRepository = {
  async get(id) {
    const { data, error } = await admin
      .from("arcadots")
      .select("id, active_game, updated_at")
      .eq("id", id)
      .maybeSingle();
    if (error) throw error;
    return data;
  },
  async update(id, game: GameSlug) {
    const { data, error } = await admin
      .from("arcadots")
      .update({ active_game: game, updated_at: new Date().toISOString() })
      .eq("id", id)
      .select("id, active_game, updated_at")
      .maybeSingle();
    if (error) throw error;
    return data;
  },
};

Deno.serve(async (request) => {
  if (!publishableKey || request.headers.get("apikey") !== publishableKey) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }
  try {
    return await handleArcadotGameRequest(request, repository);
  } catch (error) {
    console.error("arcadot-game", error);
    return Response.json({ error: "internal_error" }, { status: 500 });
  }
});
