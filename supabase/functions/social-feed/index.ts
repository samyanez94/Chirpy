import { createClient } from "npm:@supabase/supabase-js@2.57.4";
import { PostingLimitError } from "./types.ts";
import { createHandler } from "./handler.ts";
import type { CursorPayload, DatabasePost, DatabaseProfile, Repository, SearchCursorPayload } from "./types.ts";

const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const demoUserID = Deno.env.get("DEMO_USER_ID");
const apiKey = Deno.env.get("CHIRPY_API_KEY");
if (!url || !key || !demoUserID || !apiKey) throw new Error("Required server environment is missing");

const client = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });

const repository: Repository = {
  async currentProfile(): Promise<DatabaseProfile | null> {
    const { data, error } = await client.from("profiles")
      .select("id, username, display_name, avatar_url")
      .eq("id", demoUserID)
      .maybeSingle();
    if (error) throw new Error(`current_profile failed: ${error.code}`);
    return data;
  },
  async createPost(text: string): Promise<DatabasePost> {
    const { data, error } = await client.rpc("create_post", {
      p_demo_user_id: demoUserID,
      p_text: text,
    });
    if (error?.code === "P0429") throw new PostingLimitError();
    if (error) throw new Error(`create_post failed: ${error.code}`);
    const row = data?.[0];
    if (!row) throw new Error("create_post returned no result");
    return row as DatabasePost;
  },
  async feed(limitPlusOne: number, cursor: CursorPayload | null, profileID: string | null): Promise<DatabasePost[]> {
    const { data, error } = await client.rpc("feed_page", {
      p_demo_user_id: demoUserID,
      p_profile_id: profileID,
      p_limit: limitPlusOne,
      p_cursor_created_at: cursor?.createdAt ?? null,
      p_cursor_id: cursor?.id ?? null,
    });
    if (error) throw new Error(`feed_page failed: ${error.code}`);
    return data as DatabasePost[];
  },
  async search(query: string, limitPlusOne: number, cursor: SearchCursorPayload | null): Promise<DatabasePost[]> {
    const { data, error } = await client.rpc("search_posts", {
      p_demo_user_id: demoUserID,
      p_query: query,
      p_limit: limitPlusOne,
      p_cursor_created_at: cursor?.createdAt ?? null,
      p_cursor_id: cursor?.id ?? null,
    });
    if (error) throw new Error(`search_posts failed: ${error.code}`);
    return data as DatabasePost[];
  },
  async setLike(postID: string, liked: boolean) {
    const { data, error } = await client.rpc("set_post_like", {
      p_demo_user_id: demoUserID,
      p_post_id: postID,
      p_liked: liked,
    });
    if (error) throw new Error(`set_post_like failed: ${error.code}`);
    const row = data?.[0];
    if (!row) throw new Error("set_post_like returned no result");
    return { postExists: row.post_exists, isLiked: row.is_liked, likeCount: Number(row.like_count) };
  },
};

Deno.serve(createHandler(repository, {
  apiKey,
  enableDevScenarios: Deno.env.get("ENABLE_DEV_SCENARIOS") === "true",
  allowedOrigin: Deno.env.get("ALLOWED_ORIGIN") || undefined,
}));
