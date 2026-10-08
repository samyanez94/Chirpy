import { decodeCursor, decodeSearchCursor, encodeCursor, encodeSearchCursor } from "./cursor.ts";
import { PostingLimitError } from "./types.ts";
import { createHandler } from "./handler.ts";
import type { CursorPayload, DatabasePost, Repository, SearchCursorPayload } from "./types.ts";

const ids = Array.from({ length: 45 }, (_, i) => `10000000-0000-4000-8000-${String(45 - i).padStart(12, "0")}`);
const rows: DatabasePost[] = ids.map((id, index) => ({
  id,
  author_id: "00000000-0000-4000-8000-000000000001",
  username: "crumbclub",
  display_name: "Pip Sparrow",
  avatar_url: null,
  body: `Post ${index}`,
  image_url: null,
  created_at: index < 6 ? "2026-08-31T18:42:00.000Z" : new Date(Date.UTC(2026, 7, 31, 18 - index)).toISOString(),
  is_liked: false,
  like_count: 0,
})).sort(compareRows);

class MemoryRepository implements Repository {
  likes = new Set<string>();
  readonly posts: DatabasePost[];
  createdTexts: string[] = [];
  searches: { query: string; limit: number; cursor: SearchCursorPayload | null }[] = [];
  constructor(posts = rows) {
    this.posts = posts.map((post) => ({ ...post }));
  }
  createPost(text: string): Promise<DatabasePost> {
    this.createdTexts.push(text);
    const post: DatabasePost = {
      ...rows[0],
      id: crypto.randomUUID(),
      body: text,
      created_at: new Date().toISOString(),
      image_url: null,
      is_liked: false,
      like_count: 0,
    };
    this.posts.push(post);
    this.posts.sort(compareRows);
    return Promise.resolve(post);
  }
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
  async search(query: string, limit: number, cursor: SearchCursorPayload | null): Promise<DatabasePost[]> {
    this.searches.push({ query, limit, cursor });
    const posts = await this.feed(this.posts.length, cursor ? { ...cursor, v: 1 } : null);
    return posts.filter((post) => post.body.toLowerCase().includes(query.toLowerCase())).slice(0, limit);
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
const request = (path: string, method = "GET") => {
  const prefix = (path.split("?")[0] === "/feed" || path.split("?")[0] === "/posts" || path.startsWith("/posts/"))
    ? "/functions/v1"
    : "/functions/v1/social-feed";
  return new Request(`http://localhost${prefix}${path}`, { method, headers: { "x-chirpy-api-key": "test-key" } });
};

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
    await createHandler(new MemoryRepository(), { apiKey: "test-key", enableDevScenarios: false })(request("/feed")),
  );
  equal(payload.posts.length, 20);
  for (let i = 1; i < payload.posts.length; i++) assert(compareAPI(payload.posts[i - 1], payload.posts[i]) <= 0);
  assert(payload.hasMore && typeof payload.nextCursor === "string");
});

Deno.test("cursor traversal returns every post once including tied timestamps", async () => {
  const handler = createHandler(new MemoryRepository(), { apiKey: "test-key", enableDevScenarios: false });
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
  const handler = createHandler(new MemoryRepository(), { apiKey: "test-key", enableDevScenarios: false });
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
  const handler = createHandler(new MemoryRepository(), { apiKey: "test-key", enableDevScenarios: false });
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
  const disabled = createHandler(new MemoryRepository(), { apiKey: "test-key", enableDevScenarios: false });
  equal((await body(await disabled(request("/feed?scenario=empty")))).error.code, "invalid_request");
  const enabled = createHandler(new MemoryRepository(), { apiKey: "test-key", enableDevScenarios: true });
  equal(await body(await enabled(request("/feed?scenario=empty"))), { posts: [], nextCursor: null, hasMore: false });
  const unavailable = await enabled(request("/feed?scenario=error"));
  equal(unavailable.status, 503);
  equal((await body(unavailable)).error.code, "service_unavailable");
  const duplicates = await body(await enabled(request("/feed?limit=3&scenario=duplicates")));
  equal(duplicates.posts[0].id, duplicates.posts[1].id);
});

Deno.test("health, routing, and methods return documented responses", async () => {
  const handler = createHandler(new MemoryRepository(), { apiKey: "test-key", enableDevScenarios: false });
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

const createRequest = (payload: unknown, path = "/functions/v1/posts") =>
  new Request(`http://localhost${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", "x-chirpy-api-key": "test-key" },
    body: JSON.stringify(payload),
  });

Deno.test("creation returns a complete post through both route prefixes", async () => {
  for (const path of ["/functions/v1/posts", "/functions/v1/social-feed/posts"]) {
    const repository = new MemoryRepository();
    const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
    const result = await handler(createRequest({ text: "  Hello\n\nworld!  " }, path));
    equal(result.status, 201);
    const post = await body(result);
    assert(typeof post.id === "string" && post.id.length === 36);
    equal(post, {
      id: post.id,
      author: { id: rows[0].author_id, username: "crumbclub", displayName: "Pip Sparrow", avatarURL: null },
      text: "Hello\n\nworld!",
      imageURL: null,
      createdAt: post.createdAt,
      isLiked: false,
      likeCount: 0,
    });
    equal(new Date(post.createdAt).toISOString(), post.createdAt);
    equal(repository.createdTexts, ["Hello\n\nworld!"]);
    equal((await body(await handler(request("/feed")))).posts[0], post);
    const like = await body(await handler(request(`/posts/${post.id}/like`, "POST")));
    equal(like, { postID: post.id, isLiked: true, likeCount: 1 });
    equal(new MemoryRepository().posts.length, rows.length);
  }
});

Deno.test("creation counts Unicode code points and accepts the text boundaries", async () => {
  const repository = new MemoryRepository();
  const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
  for (const text of ["a", "a".repeat(300), "😀".repeat(300), "e\u0301".repeat(150)]) {
    const result = await handler(createRequest({ text: ` \t${text}\n ` }));
    equal(result.status, 201);
    equal((await body(result)).text, text);
  }
});

Deno.test("invalid creation payloads never reach the repository", async () => {
  const repository = new MemoryRepository();
  const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
  for (
    const payload of [
      null,
      [],
      "text",
      1,
      true,
      {},
      { text: null },
      { text: 1 },
      { text: [] },
      { text: "" },
      { text: " \t\n\u00a0 " },
      { text: "a".repeat(301) },
      { text: "😀".repeat(301) },
      { text: "hello", authorID: rows[0].author_id },
      { text: "hello", imageURL: null },
      { text: "hello", attachments: [] },
      { text: "hello", unknown: true },
    ]
  ) {
    const result = await handler(createRequest(payload));
    equal(result.status, 400);
    const payloadError = (await body(result)).error;
    equal(payloadError.code, "invalid_request");
    equal(payloadError.requestID, result.headers.get("x-request-id"));
  }
  for (const raw of ["", "{", '{"text":']) {
    const result = await handler(
      new Request("http://localhost/functions/v1/posts", {
        method: "POST",
        body: raw,
        headers: { "x-chirpy-api-key": "test-key" },
      }),
    );
    equal(result.status, 400);
    equal((await body(result)).error.code, "invalid_request");
  }
  equal(repository.createdTexts, []);
});

Deno.test("creation rejects unsupported methods and reports repository failures", async () => {
  const repository = new MemoryRepository();
  const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
  for (const method of ["GET", "PUT", "PATCH", "DELETE"]) {
    const result = await handler(request("/posts", method));
    equal(result.status, 405);
    equal((await body(result)).error.code, "method_not_allowed");
  }
  equal(repository.createdTexts, []);
  repository.createPost = () => Promise.reject(new Error("Database unavailable"));
  const result = await handler(createRequest({ text: "Hello" }));
  equal(result.status, 500);
  equal((await body(result)).error.code, "internal_error");
});

Deno.test("all data routes reject missing and incorrect API keys", async () => {
  const repository = new MemoryRepository();
  const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
  for (const path of ["/feed", "/search?q=post", "/posts", `/posts/${rows[0].id}/like`]) {
    for (const key of ["", "wrong", "bad-key!"]) {
      const result = await handler(
        new Request(`http://localhost/functions/v1${path}`, {
          method: path === "/feed" || path.startsWith("/search") ? "GET" : "POST",
          headers: { "x-chirpy-api-key": key },
        }),
      );
      equal(result.status, 401);
      equal((await body(result)).error.code, "unauthorized");
    }
  }
  equal(repository.createdTexts, []);
  equal((await handler(new Request("http://localhost/functions/v1/social-feed/health"))).status, 200);
  const unconfigured = createHandler(repository, { apiKey: "", enableDevScenarios: false });
  equal((await unconfigured(request("/feed"))).status, 401);
});

Deno.test("posting limits use the existing error envelope", async () => {
  const repository = new MemoryRepository();
  repository.createPost = () => {
    throw new PostingLimitError();
  };
  const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
  const result = await handler(createRequest({ text: "Hello" }));
  equal(result.status, 429);
  equal((await body(result)).error.code, "rate_limit_exceeded");
});

Deno.test("search returns feed-style posts through both route prefixes and trims the query", async () => {
  for (const prefix of ["/functions/v1", "/functions/v1/social-feed"]) {
    const repository = new MemoryRepository();
    repository.likes.add(rows[0].id);
    const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
    const result = await handler(
      new Request(`http://localhost${prefix}/search?q=%20POST%20`, {
        headers: { "x-chirpy-api-key": "test-key" },
      }),
    );
    equal(result.status, 200);
    const payload = await body(result);
    equal(payload.posts.length, 20);
    equal(payload.posts[0], {
      id: rows[0].id,
      author: { id: rows[0].author_id, username: "crumbclub", displayName: "Pip Sparrow", avatarURL: null },
      text: rows[0].body,
      imageURL: null,
      createdAt: rows[0].created_at,
      isLiked: true,
      likeCount: 1,
    });
    assert(payload.hasMore);
    equal(repository.searches[0], { query: "POST", limit: 21, cursor: null });
    equal(decodeSearchCursor(payload.nextCursor, "POST").query, "POST");
  }
});

Deno.test("search traverses every matching post exactly once, including tied timestamps", async () => {
  const repository = new MemoryRepository();
  const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
  const received: string[] = [];
  let cursor: string | null = null;
  let final;
  do {
    const params = new URLSearchParams({ q: "post", limit: "4" });
    if (cursor) params.set("cursor", cursor);
    const result = await handler(request(`/search?${params}`));
    equal(result.status, 200);
    final = await body(result);
    received.push(...final.posts.map((post: { id: string }) => post.id));
    cursor = final.nextCursor;
  } while (cursor);
  equal(received, rows.map((post) => post.id));
  equal(new Set(received).size, rows.length);
  equal({ nextCursor: final.nextCursor, hasMore: final.hasMore }, { nextCursor: null, hasMore: false });
  assert(repository.searches.slice(1).every((search) => search.cursor?.query === "post"));
});

Deno.test("search validates queries, limits, and methods before calling the repository", async () => {
  const repository = new MemoryRepository();
  const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
  for (const query of [null, "", " \t\n ", "x", "😀", "x".repeat(101), "😀".repeat(101), "ab\0cd"]) {
    const params = new URLSearchParams();
    if (query !== null) params.set("q", query);
    const result = await handler(request(`/search?${params}`));
    equal(result.status, 400);
    const payload = await body(result);
    equal(payload.error.code, "invalid_request");
    equal(payload.error.requestID, result.headers.get("x-request-id"));
  }
  for (const suffix of ["&q=other", "&limit=", "&limit=0", "&limit=51", "&limit=2.5", "&limit=bad", "&limit=-1"]) {
    const result = await handler(request(`/search?q=post${suffix}`));
    equal(result.status, 400);
    equal((await body(result)).error.code, "invalid_request");
  }
  for (const method of ["POST", "PUT", "DELETE", "PATCH"]) {
    const result = await handler(request("/search?q=post", method));
    equal(result.status, 405);
    equal((await body(result)).error.code, "method_not_allowed");
  }
  equal(repository.searches, []);
});

Deno.test("search accepts Unicode query boundaries and treats punctuation as literal text", async () => {
  const posts = [
    "100% crumbs",
    "under_score",
    "path\\crumbs",
    "bread crumbs",
    "😀😀",
    "x".repeat(100),
    "😀".repeat(100),
  ];
  const repository = new MemoryRepository(posts.map((text, index) => ({ ...rows[index], body: text })));
  const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
  for (const query of ["0%", "_s", "\\c", "bread crumbs", "😀😀", "x".repeat(100), "😀".repeat(100)]) {
    const result = await handler(request(`/search?${new URLSearchParams({ q: query, limit: "50" })}`));
    equal(result.status, 200);
    const payload = await body(result);
    equal(payload.posts.map((post: { text: string }) => post.text), posts.filter((text) => text.includes(query)));
    equal(payload.nextCursor, null);
    equal(payload.hasMore, false);
  }
});

Deno.test("search returns an empty page for no matches and reports repository failures", async () => {
  const repository = new MemoryRepository();
  const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
  equal(await body(await handler(request("/search?q=absent"))), { posts: [], nextCursor: null, hasMore: false });
  repository.search = () => Promise.reject(new Error("Database unavailable"));
  const result = await handler(request("/search?q=post"));
  equal(result.status, 500);
  equal((await body(result)).error.code, "internal_error");
});

Deno.test("search cursors are query-bound, reject malformed payloads, and cannot be used for the feed", async () => {
  const repository = new MemoryRepository();
  const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
  const valid = encodeSearchCursor("post", rows[0].created_at, rows[0].id);
  const searchPayload = { v: 1, kind: "search", query: "post", createdAt: rows[0].created_at, id: rows[0].id };
  for (
    const cursor of [
      "",
      "bad",
      "a".repeat(2049),
      encodeCursor(rows[0].created_at, rows[0].id),
      encodeSearchCursor("other", rows[0].created_at, rows[0].id),
      btoa(JSON.stringify({ ...searchPayload, v: 2 })),
      btoa(JSON.stringify({ ...searchPayload, kind: "feed" })),
      btoa(JSON.stringify({ ...searchPayload, createdAt: "bad" })),
      btoa(JSON.stringify({ ...searchPayload, createdAt: "2026-02-30T12:00:00Z" })),
      btoa(JSON.stringify({ ...searchPayload, createdAt: "0000-01-01T12:00:00Z" })),
      btoa(JSON.stringify({ ...searchPayload, createdAt: "2026-10-08T24:00:00Z" })),
      btoa(JSON.stringify({ ...searchPayload, createdAt: "2026-10-08T12:00:00+16:00" })),
      btoa(JSON.stringify({ ...searchPayload, id: "bad" })),
      btoa(JSON.stringify(null)),
      btoa(JSON.stringify([])),
    ]
  ) {
    const result = await handler(request(`/search?${new URLSearchParams({ q: "post", cursor })}`));
    equal(result.status, 400);
    equal((await body(result)).error.code, "invalid_cursor");
  }
  const feedResult = await handler(request(`/feed?${new URLSearchParams({ cursor: valid })}`));
  equal(feedResult.status, 400);
  equal((await body(feedResult)).error.code, "invalid_cursor");
  equal(repository.searches, []);
  equal((await handler(request(`/search?${new URLSearchParams({ q: " post ", cursor: valid })}`))).status, 200);
});

Deno.test("search cursors preserve database microseconds even though public dates use milliseconds", async () => {
  const timestamp = "2026-10-08T12:00:00.123456+00:00";
  const repository = new MemoryRepository([
    { ...rows[0], created_at: timestamp },
    { ...rows[1], created_at: timestamp },
  ]);
  const handler = createHandler(repository, { apiKey: "test-key", enableDevScenarios: false });
  const page = await body(await handler(request("/search?q=post&limit=1")));
  equal(page.posts[0].createdAt, "2026-10-08T12:00:00.123Z");
  equal(decodeSearchCursor(page.nextCursor, "post").createdAt, timestamp);
  const unicode = encodeSearchCursor("😀😀", timestamp, rows[0].id);
  equal(decodeSearchCursor(unicode, "😀😀").query, "😀😀");
});
