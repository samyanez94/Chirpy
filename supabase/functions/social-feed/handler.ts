import {
  decodeFeedCursor,
  decodeSearchCursor,
  encodeFeedCursor,
  encodeSearchCursor,
  InvalidCursorError,
  isUUID,
} from "./cursor.ts";
import type { DatabasePost, DatabaseProfile, Environment, FeedPost, Profile, Repository } from "./types.ts";

import { timingSafeEqual } from "node:crypto";
import { PostingLimitError } from "./types.ts";

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

      const suppliedKey = request.headers.get("x-chirpy-api-key") ?? "";
      const expected = new TextEncoder().encode(environment.apiKey);
      const supplied = new TextEncoder().encode(suppliedKey);
      if (!expected.length || expected.length !== supplied.length || !timingSafeEqual(expected, supplied)) {
        return error(401, "unauthorized", "A valid Chirpy API key is required.");
      }

      if (path === "/profile") {
        if (request.method !== "GET") {
          return error(405, "method_not_allowed", "This method is not allowed for the requested route.");
        }
        const profile = await repository.currentProfile();
        if (!profile) throw new Error("Configured current profile is missing");
        return response(mapProfile(profile), 200, headers);
      }

      if (path === "/search") {
        if (request.method !== "GET") {
          return error(405, "method_not_allowed", "This method is not allowed for the requested route.");
        }
        const query = url.searchParams.get("q")?.trim() ?? "";
        const queryLength = Array.from(query).length;
        if (url.searchParams.getAll("q").length !== 1 || queryLength < 2 || queryLength > 100 || query.includes("\0")) {
          return error(
            400,
            "invalid_request",
            "Query must contain 2 through 100 characters after trimming and no null characters.",
          );
        }
        const limitValue = url.searchParams.get("limit");
        if (limitValue !== null && !/^[0-9]+$/.test(limitValue)) {
          return error(400, "invalid_request", "Limit must be an integer from 1 through 50.");
        }
        const limit = limitValue === null ? 20 : Number(limitValue);
        if (limit < 1 || limit > 50) {
          return error(400, "invalid_request", "Limit must be an integer from 1 through 50.");
        }
        const cursorValue = url.searchParams.get("cursor");
        const cursor = cursorValue === null ? null : decodeSearchCursor(cursorValue, query);
        const rows = await repository.search(query, limit + 1, cursor);
        const hasMore = rows.length > limit;
        const page = rows.slice(0, limit);
        const last = page.at(-1);
        return response(
          {
            posts: page.map(mapPost),
            nextCursor: hasMore && last ? encodeSearchCursor(query, last.created_at, last.id) : null,
            hasMore,
          },
          200,
          headers,
        );
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
        const profileValue = url.searchParams.get("profile_id");
        if (url.searchParams.getAll("profile_id").length > 1 || (profileValue !== null && !isUUID(profileValue))) {
          return error(400, "invalid_request", "Profile ID must be a single UUID.");
        }
        const profileID = profileValue?.toLowerCase() ?? null;
        const cursorValue = url.searchParams.get("cursor");
        const cursor = cursorValue === null ? null : decodeFeedCursor(cursorValue, profileID);
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

        const rows = await repository.feed(limit + 1, cursor, profileID);
        const hasMore = rows.length > limit;
        let posts = rows.slice(0, limit).map(mapPost);
        if (scenario === "duplicates" && posts.length > 1) {
          posts = [posts[0], posts[0], ...posts.slice(1, Math.max(1, limit - 1))];
        }
        const last = posts.at(-1);
        const lastRow = last ? rows.find((row) => row.id === last.id) : undefined;
        return response(
          {
            posts,
            nextCursor: hasMore && lastRow ? encodeFeedCursor(profileID, lastRow.created_at, lastRow.id) : null,
            hasMore,
          },
          200,
          headers,
        );
      }

      if (path === "/posts") {
        if (request.method !== "POST") {
          return error(405, "method_not_allowed", "This method is not allowed for the requested route.");
        }
        let payload: unknown;
        try {
          payload = await request.json();
        } catch {
          return error(400, "invalid_request", "The request body must be valid JSON.");
        }
        if (
          typeof payload !== "object" || payload === null || Array.isArray(payload) ||
          !("text" in payload) || typeof payload.text !== "string" ||
          Object.keys(payload).some((key) => key !== "text")
        ) {
          return error(400, "invalid_request", "The request body must contain only a text string.");
        }
        const text = payload.text.trim();
        if (Array.from(text).length < 1 || Array.from(text).length > 300) {
          return error(400, "invalid_request", "Text must contain 1 through 300 characters after trimming.");
        }
        return response(mapPost(await repository.createPost(text)), 201, headers);
      }

      const deleteMatch = path.match(/^\/posts\/([^/]+)$/);
      if (deleteMatch) {
        if (request.method !== "DELETE") {
          return error(405, "method_not_allowed", "This method is not allowed for the requested route.");
        }
        const postID = deleteMatch[1];
        if (!isUUID(postID)) return error(400, "invalid_request", "Post ID must be a UUID.");
        if (!await repository.deletePost(postID.toLowerCase())) {
          return error(404, "post_not_found", "The requested post does not exist or cannot be deleted.");
        }
        return new Response(null, { status: 204, headers });
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
      if (cause instanceof PostingLimitError) {
        return error(429, "rate_limit_exceeded", "Posting limit reached. Please try again later.");
      }
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
  path = path.replace(/^\/functions\/v1(?=\/)/, "");
  const marker = "/social-feed";
  const index = path.indexOf(marker);
  const result = index >= 0 ? path.slice(index + marker.length) : path;
  return result.replace(/\/$/, "") || "/";
}

function mapProfile(row: DatabaseProfile): Profile {
  return { id: row.id, username: row.username, displayName: row.display_name, avatarURL: row.avatar_url };
}

function mapPost(row: DatabasePost): FeedPost {
  return {
    id: row.id,
    author: mapProfile({ ...row, id: row.author_id }),
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
