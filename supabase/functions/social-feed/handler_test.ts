import { decodeCursor, encodeCursor } from "./cursor.ts";
import { createHandler } from "./handler.ts";
import type { CursorPayload, DatabasePost, Repository } from "./types.ts";

const ids = Array.from({ length: 45 }, (_, i) => `10000000-0000-4000-8000-${String(45 - i).padStart(12, "0")}`);
const rows: DatabasePost[] = ids.map((id, index) => ({
  id,
  author_id: "00000000-0000-4000-8000-000000000001",
  username: "sampler",
  display_name: "Sam Rivera",
  avatar_url: null,
  body: `Post ${index}`,
  image_url: null,
  created_at: index < 6 ? "2026-08-31T18:42:00.000Z" : new Date(Date.UTC(2026, 7, 31, 18 - index)).toISOString(),
  is_liked: false,
  like_count: 0,
})).sort(compareRows);

class MemoryRepository implements Repository {
  likes = new Set<string>();
  constructor(readonly posts = rows) {}
  feed(limit: number, cursor: CursorPayload | null): Promise<DatabasePost[]> {
    const eligible = cursor
      ? this.posts.filter((post) =>
        post.created_at < cursor.createdAt || (post.created_at === cursor.createdAt && post.id < cursor.id)
      )
      : this.posts;
    return Promise.resolve(
      eligible.slice(0, limit).map((post) => ({
        ...post,
        is_liked: this.likes.has(post.id),
        like_count: this.likes.has(post.id) ? 1 : 0,
      })),
    );
  }
  setLike(postID: string, liked: boolean) {
    if (!this.posts.some((post) => post.id === postID)) {
      return Promise.resolve({ postExists: false, isLiked: false, likeCount: 0 });
    }
    if (liked) this.likes.add(postID);
    else this.likes.delete(postID);
    return Promise.resolve({
      postExists: true,
      isLiked: this.likes.has(postID),
      likeCount: this.likes.has(postID) ? 1 : 0,
    });
  }
}

const assert: (condition: unknown, message?: string) => asserts condition = (
  condition,
  message = "assertion failed",
) => {
  if (!condition) throw new Error(message);
};
const equal = (actual: unknown, expected: unknown) =>
  assert(
    JSON.stringify(actual) === JSON.stringify(expected),
    `${JSON.stringify(actual)} != ${JSON.stringify(expected)}`,
  );
const body = (response: Response) => response.json();
const request = (path: string, method = "GET") =>
  new Request(`http://localhost/functions/v1/social-feed${path}`, { method });

Deno.test("cursor round trips and rejects malformed or unsupported values", () => {
  const encoded = encodeCursor(rows[0].created_at, rows[0].id);
  equal(decodeCursor(encoded), { v: 1, createdAt: rows[0].created_at, id: rows[0].id });
  for (const invalid of ["garbage", btoa(JSON.stringify({ v: 2, createdAt: rows[0].created_at, id: rows[0].id }))]) {
    let threw = false;
    try {
      decodeCursor(invalid);
    } catch {
      threw = true;
    }
    assert(threw);
  }
});

Deno.test("first page defaults to 20 and uses descending timestamp then id", async () => {
  const payload = await body(
    await createHandler(new MemoryRepository(), { enableDevScenarios: false })(request("/feed")),
  );
  equal(payload.posts.length, 20);
  for (let i = 1; i < payload.posts.length; i++) assert(compareAPI(payload.posts[i - 1], payload.posts[i]) <= 0);
  assert(payload.hasMore && typeof payload.nextCursor === "string");
});

Deno.test("cursor traversal returns every post once including tied timestamps", async () => {
  const handler = createHandler(new MemoryRepository(), { enableDevScenarios: false });
  const received: string[] = [];
  let cursor: string | null = null;
  let final;
  do {
    final = await body(await handler(request(`/feed?limit=4${cursor ? `&cursor=${cursor}` : ""}`)));
    received.push(...final.posts.map((post: { id: string }) => post.id));
    cursor = final.nextCursor;
  } while (cursor);
  equal(received, rows.map((post) => post.id));
  equal(new Set(received).size, rows.length);
  equal({ nextCursor: final.nextCursor, hasMore: final.hasMore }, { nextCursor: null, hasMore: false });
});

Deno.test("invalid limits and cursors use the error contract", async () => {
  const handler = createHandler(new MemoryRepository(), { enableDevScenarios: false });
  for (const path of ["/feed?limit=0", "/feed?limit=51", "/feed?limit=2.5"]) {
    const response = await handler(request(path));
    equal(response.status, 400);
    const payload = await body(response);
    equal(payload.error.code, "invalid_request");
    assert(typeof payload.error.requestID === "string");
  }
  const response = await handler(request("/feed?cursor=bad"));
  equal(response.status, 400);
  equal((await body(response)).error.code, "invalid_cursor");
});

Deno.test("like and unlike are idempotent and unknown posts return 404", async () => {
  const handler = createHandler(new MemoryRepository(), { enableDevScenarios: false });
  const path = `/posts/${rows[0].id}/like`;
  for (const method of ["POST", "POST"]) {
    equal(await body(await handler(request(path, method))), { postID: rows[0].id, isLiked: true, likeCount: 1 });
  }
  for (const method of ["DELETE", "DELETE"]) {
    equal(await body(await handler(request(path, method))), { postID: rows[0].id, isLiked: false, likeCount: 0 });
  }
  const missing = await handler(request("/posts/ffffffff-ffff-4fff-8fff-ffffffffffff/like", "POST"));
  equal(missing.status, 404);
  equal((await body(missing)).error.code, "post_not_found");
});

Deno.test("development scenarios are deterministic and gated", async () => {
  const disabled = createHandler(new MemoryRepository(), { enableDevScenarios: false });
  equal((await body(await disabled(request("/feed?scenario=empty")))).error.code, "invalid_request");
  const enabled = createHandler(new MemoryRepository(), { enableDevScenarios: true });
  equal(await body(await enabled(request("/feed?scenario=empty"))), { posts: [], nextCursor: null, hasMore: false });
  const unavailable = await enabled(request("/feed?scenario=error"));
  equal(unavailable.status, 503);
  equal((await body(unavailable)).error.code, "service_unavailable");
  const duplicates = await body(await enabled(request("/feed?limit=3&scenario=duplicates")));
  equal(duplicates.posts[0].id, duplicates.posts[1].id);
});

Deno.test("health, routing, and methods return documented responses", async () => {
  const handler = createHandler(new MemoryRepository(), { enableDevScenarios: false });
  equal(await body(await handler(request("/health"))), { status: "ok" });
  equal((await body(await handler(request("/missing")))).error.code, "not_found");
  const method = await handler(request("/feed", "POST"));
  equal(method.status, 405);
  equal((await body(method)).error.code, "method_not_allowed");
});

function compareRows(a: DatabasePost, b: DatabasePost): number {
  return b.created_at.localeCompare(a.created_at) || b.id.localeCompare(a.id);
}

function compareAPI(a: { createdAt: string; id: string }, b: { createdAt: string; id: string }): number {
  return b.createdAt.localeCompare(a.createdAt) || b.id.localeCompare(a.id);
}
