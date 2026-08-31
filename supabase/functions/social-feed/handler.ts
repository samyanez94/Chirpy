import { decodeCursor, encodeCursor, InvalidCursorError, isUUID } from "./cursor.ts";
import type { DatabasePost, Environment, FeedPost, Repository } from "./types.ts";

const jsonHeaders = { "content-type": "application/json; charset=utf-8" };

export function createHandler(repository: Repository, environment: Environment) {
  return async (request: Request): Promise<Response> => {
    const requestID = request.headers.get("x-request-id") ?? crypto.randomUUID();
    const headers = {
      ...jsonHeaders,
      "x-request-id": requestID,
      ...(environment.allowedOrigin ? { "access-control-allow-origin": environment.allowedOrigin } : {}),
    };
    const error = (status: number, code: string, message: string) =>
      new Response(JSON.stringify({ error: { code, message, requestID } }), { status, headers });

    try {
      const url = new URL(request.url);
      const path = normalizedPath(url.pathname);

      if (path === "/health") {
        if (request.method !== "GET") {
          return error(405, "method_not_allowed", "This method is not allowed for the requested route.");
        }
        return response({ status: "ok" }, 200, headers);
      }

      if (path === "/feed") {
        if (request.method !== "GET") {
          return error(405, "method_not_allowed", "This method is not allowed for the requested route.");
        }
        const limitValue = url.searchParams.get("limit");
        if (limitValue !== null && !/^[0-9]+$/.test(limitValue)) {
          return error(400, "invalid_request", "Limit must be an integer from 1 through 50.");
        }
        const limit = limitValue === null ? 20 : Number(limitValue);
        if (limit < 1 || limit > 50) {
          return error(400, "invalid_request", "Limit must be an integer from 1 through 50.");
        }
        const scenario = url.searchParams.get("scenario");
        if (scenario && !environment.enableDevScenarios) {
          return error(400, "invalid_request", "Development scenarios are not enabled.");
        }
        if (scenario && !["slow", "error", "empty", "duplicates"].includes(scenario)) {
          return error(400, "invalid_request", "Unknown development scenario.");
        }
        if (scenario === "error") return error(503, "service_unavailable", "A development failure was requested.");
        if (scenario === "empty") return response({ posts: [], nextCursor: null, hasMore: false }, 200, headers);
        if (scenario === "slow") await new Promise((resolve) => setTimeout(resolve, 2000));

        const cursorValue = url.searchParams.get("cursor");
        const cursor = cursorValue === null ? null : decodeCursor(cursorValue);
        const rows = await repository.feed(limit + 1, cursor);
        const hasMore = rows.length > limit;
        let posts = rows.slice(0, limit).map(mapPost);
        if (scenario === "duplicates" && posts.length > 1) {
          posts = [posts[0], posts[0], ...posts.slice(1, Math.max(1, limit - 1))];
        }
        const last = posts.at(-1);
        return response(
          { posts, nextCursor: hasMore && last ? encodeCursor(last.createdAt, last.id) : null, hasMore },
          200,
          headers,
        );
      }

      const match = path.match(/^\/posts\/([^/]+)\/like$/);
      if (match) {
        if (request.method !== "POST" && request.method !== "DELETE") {
          return error(405, "method_not_allowed", "This method is not allowed for the requested route.");
        }
        const postID = match[1];
        if (!isUUID(postID)) return error(400, "invalid_request", "Post ID must be a UUID.");
        const result = await repository.setLike(postID, request.method === "POST");
        if (!result.postExists) return error(404, "post_not_found", "The requested post does not exist.");
        return response({ postID, isLiked: result.isLiked, likeCount: result.likeCount }, 200, headers);
      }

      return error(404, "not_found", "The requested route does not exist.");
    } catch (cause) {
      if (cause instanceof InvalidCursorError) return error(400, "invalid_cursor", "The supplied cursor is invalid.");
      console.error(
        JSON.stringify({
          requestID,
          event: "request_failed",
          error: cause instanceof Error ? cause.message : "unknown",
        }),
      );
      return error(500, "internal_error", "An unexpected server error occurred.");
    }
  };
}

function normalizedPath(path: string): string {
  const marker = "/social-feed";
  const index = path.indexOf(marker);
  const result = index >= 0 ? path.slice(index + marker.length) : path;
  return result.replace(/\/$/, "") || "/";
}

function mapPost(row: DatabasePost): FeedPost {
  return {
    id: row.id,
    author: { id: row.author_id, username: row.username, displayName: row.display_name, avatarURL: row.avatar_url },
    text: row.body,
    imageURL: row.image_url,
    // PostgREST commonly serializes timestamptz with a +00:00 suffix. Normalize the
    // public contract and cursor input to the documented UTC ISO-8601 form.
    createdAt: new Date(row.created_at).toISOString(),
    isLiked: row.is_liked,
    likeCount: Number(row.like_count),
  };
}

function response(body: unknown, status: number, headers: HeadersInit): Response {
  return new Response(JSON.stringify(body), { status, headers });
}
