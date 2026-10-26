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
    create: async (id, game) => row?.id === id
      ? null
      : { id, active_game: game, updated_at: "2026-10-03T01:00:00Z" },
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

Deno.test("POST creates assignments for every supported game", async () => {
  for (const game of ["sky-stack", "pulse", "orbit"]) {
    const response = await handleArcadotGameRequest(
      new Request("https://example.test/arcadot-game", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-lumi-provisioning-token": "provision-test-token",
        },
        body: JSON.stringify({ id: `NEW${game.length}`, game }),
      }),
      repository(null),
      { provisioningToken: "provision-test-token" },
    );
    assertEquals(response.status, 201);
    assertEquals((await response.json()).active_game, game);
  }
});

Deno.test("POST requires the dedicated provisioning token", async () => {
  for (const token of [undefined, "wrong-token"]) {
    const headers: Record<string, string> = { "content-type": "application/json" };
    if (token) headers["x-lumi-provisioning-token"] = token;
    const response = await handleArcadotGameRequest(
      new Request("https://example.test/arcadot-game", {
        method: "POST",
        headers,
        body: JSON.stringify({ id: "NEW25", game: "pulse" }),
      }),
      repository(null),
      { provisioningToken: "provision-test-token" },
    );
    assertEquals(response.status, 401);
    assertEquals((await response.json()).error, "unauthorized");
  }
});

Deno.test("POST validates IDs, JSON, and games", async () => {
  const requests = [
    new Request("https://example.test/arcadot-game", {
      method: "POST",
      headers: { "x-lumi-provisioning-token": "provision-test-token" },
      body: "not-json",
    }),
    new Request("https://example.test/arcadot-game", {
      method: "POST",
      headers: { "content-type": "application/json", "x-lumi-provisioning-token": "provision-test-token" },
      body: JSON.stringify({ id: "A/B", game: "pulse" }),
    }),
    new Request("https://example.test/arcadot-game", {
      method: "POST",
      headers: { "content-type": "application/json", "x-lumi-provisioning-token": "provision-test-token" },
      body: JSON.stringify({ id: "NEW25", game: "unknown" }),
    }),
  ];

  for (const request of requests) {
    const response = await handleArcadotGameRequest(
      request,
      repository(null),
      { provisioningToken: "provision-test-token" },
    );
    assertEquals(response.status, 400);
  }
});

Deno.test("POST returns conflict for an existing Arcadot", async () => {
  const response = await handleArcadotGameRequest(
    new Request("https://example.test/arcadot-game", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-lumi-provisioning-token": "provision-test-token",
      },
      body: JSON.stringify({ id: "00025", game: "pulse" }),
    }),
    repository(),
    { provisioningToken: "provision-test-token" },
  );
  assertEquals(response.status, 409);
  assertEquals((await response.json()).error, "arcadot_already_exists");
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

Deno.test("PUT accepts Orbit assignments", async () => {
  const response = await handleArcadotGameRequest(
    new Request("https://example.test/arcadot-game", {
      method: "PUT",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ id: "00025", game: "orbit" }),
    }),
    repository(),
  );
  assertEquals(response.status, 200);
  assertEquals((await response.json()).active_game, "orbit");
});

Deno.test("unknown Arcadots return 404", async () => {
  const response = await handleArcadotGameRequest(
    new Request("https://example.test/arcadot-game?id=99999"),
    repository(null),
  );
  assertEquals(response.status, 404);
});
