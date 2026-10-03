export type GameSlug = "sky-stack" | "pulse";

export interface ArcadotRow {
  id: string;
  active_game: GameSlug;
  updated_at: string;
}

export interface ArcadotRepository {
  get(id: string): Promise<ArcadotRow | null>;
  update(id: string, game: GameSlug): Promise<ArcadotRow | null>;
}

const allowedGames = new Set<GameSlug>(["sky-stack", "pulse"]);
const validID = (value: unknown): value is string =>
  typeof value === "string" && /^[A-Za-z0-9]{1,64}$/.test(value);

const json = (body: unknown, status = 200) =>
  Response.json(body, {
    status,
    headers: { "cache-control": "no-store" },
  });

export async function handleArcadotGameRequest(
  request: Request,
  repository: ArcadotRepository,
): Promise<Response> {
  if (request.method === "GET") {
    const id = new URL(request.url).searchParams.get("id");
    if (!validID(id)) return json({ error: "invalid_arcadot_id" }, 400);
    const row = await repository.get(id);
    return row ? json(row) : json({ error: "arcadot_not_found" }, 404);
  }

  if (request.method === "PUT") {
    let body: { id?: unknown; game?: unknown };
    try {
      body = await request.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }
    if (!validID(body.id)) return json({ error: "invalid_arcadot_id" }, 400);
    if (typeof body.game !== "string" || !allowedGames.has(body.game as GameSlug)) {
      return json({ error: "invalid_game" }, 400);
    }
    const row = await repository.update(body.id, body.game as GameSlug);
    return row ? json(row) : json({ error: "arcadot_not_found" }, 404);
  }

  return json({ error: "method_not_allowed" }, 405);
}
