import { assertEquals } from "jsr:@std/assert";
import {
  type ArcadotRepository,
  type ArcadotRow,
  handleArcadotGameRequest,
} from "./handler.ts";

const initial: ArcadotRow = {
  id: "00025",
  active_game: "pulse",
  updated_at: "2026-10-03T00:00:00Z",
};

function repository(row: ArcadotRow | null = initial): ArcadotRepository {
  return {
    get: async (id) => row?.id === id ? row : null,
    update: async (id, game) => row?.id === id ? { ...row, active_game: game } : null,
  };
}

Deno.test("GET returns an existing Arcadot assignment", async () => {
  const response = await handleArcadotGameRequest(
    new Request("https://example.test/arcadot-game?id=00025"),
    repository(),
  );
  assertEquals(response.status, 200);
  assertEquals((await response.json()).active_game, "pulse");
});

Deno.test("GET rejects invalid and missing Arcadot IDs", async () => {
  for (const url of [
    "https://example.test/arcadot-game",
    "https://example.test/arcadot-game?id=A/B",
  ]) {
    const response = await handleArcadotGameRequest(new Request(url), repository());
    assertEquals(response.status, 400);
  }
});

Deno.test("PUT validates and updates supported games", async () => {
  const response = await handleArcadotGameRequest(
    new Request("https://example.test/arcadot-game", {
      method: "PUT",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ id: "00025", game: "sky-stack" }),
    }),
    repository(),
  );
  assertEquals(response.status, 200);
  assertEquals((await response.json()).active_game, "sky-stack");

  const invalid = await handleArcadotGameRequest(
    new Request("https://example.test/arcadot-game", {
      method: "PUT",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ id: "00025", game: "unknown" }),
    }),
    repository(),
  );
  assertEquals(invalid.status, 400);
});

Deno.test("unknown Arcadots return 404", async () => {
  const response = await handleArcadotGameRequest(
    new Request("https://example.test/arcadot-game?id=99999"),
    repository(null),
  );
  assertEquals(response.status, 404);
});
