export interface CursorPayload {
  v: 1;
  createdAt: string;
  id: string;
}

export interface SearchCursorPayload {
  v: 1;
  kind: "search";
  query: string;
  createdAt: string;
  id: string;
}

export interface DatabasePost {
  id: string;
  author_id: string;
  username: string;
  display_name: string;
  avatar_url: string | null;
  body: string;
  image_url: string | null;
  created_at: string;
  is_liked: boolean;
  like_count: number;
}

export interface FeedPost {
  id: string;
  author: { id: string; username: string; displayName: string; avatarURL: string | null };
  text: string;
  imageURL: string | null;
  createdAt: string;
  isLiked: boolean;
  likeCount: number;
}

export interface Repository {
  createPost(text: string): Promise<DatabasePost>;
  feed(limitPlusOne: number, cursor: CursorPayload | null): Promise<DatabasePost[]>;
  search(query: string, limitPlusOne: number, cursor: SearchCursorPayload | null): Promise<DatabasePost[]>;
  setLike(postID: string, liked: boolean): Promise<{ postExists: boolean; isLiked: boolean; likeCount: number }>;
}

export class PostingLimitError extends Error {}

export interface Environment {
  apiKey: string;
  enableDevScenarios: boolean;
  allowedOrigin?: string;
}
