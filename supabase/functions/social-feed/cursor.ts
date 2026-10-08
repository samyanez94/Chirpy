import type { CursorPayload, FeedCursorPayload, SearchCursorPayload } from "./types.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function toBase64Url(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

export function encodeCursor(createdAt: string, id: string): string {
  return toBase64Url(JSON.stringify({ v: 1, createdAt, id }));
}

export function decodeCursor(value: string): CursorPayload {
  try {
    const payload = decodePayload(value);
    if (!isCursor(payload)) throw new Error();
    return payload;
  } catch {
    throw new InvalidCursorError();
  }
}

// New feed cursors bind the author filter; legacy cursors remain valid only for Home.
export function encodeFeedCursor(profileID: string | null, createdAt: string, id: string): string {
  return toBase64Url(JSON.stringify({ v: 1, kind: "feed", profileID, createdAt, id }));
}

export function decodeFeedCursor(value: string, profileID: string | null): CursorPayload | FeedCursorPayload {
  try {
    if (value.length > 2048) throw new Error();
    const payload = decodePayload(value);
    if (typeof payload !== "object" || payload === null) throw new Error();
    const item = payload as Record<string, unknown>;
    if (!("kind" in item)) {
      if (profileID !== null || "profileID" in item || !isCursor(payload)) throw new Error();
      return payload;
    }
    if (item.v !== 1 || item.kind !== "feed" || item.profileID !== profileID || "query" in item) throw new Error();
    if (typeof item.id !== "string" || !isUUID(item.id)) throw new Error();
    if (typeof item.createdAt !== "string" || !isTimestamp(item.createdAt)) throw new Error();
    return payload as FeedCursorPayload;
  } catch {
    throw new InvalidCursorError();
  }
}

export function encodeSearchCursor(query: string, createdAt: string, id: string): string {
  // Preserve database timestamp precision, including sub-millisecond digits.
  return toBase64Url(JSON.stringify({ v: 1, kind: "search", query, createdAt, id }));
}

export function decodeSearchCursor(value: string, query: string): SearchCursorPayload {
  try {
    if (value.length > 2048) throw new Error();
    const payload = decodePayload(value);
    if (!isSearchCursor(payload, query)) throw new Error();
    return payload;
  } catch {
    throw new InvalidCursorError();
  }
}

function decodePayload(value: string): unknown {
  if (!value || !/^[A-Za-z0-9_-]+$/.test(value)) throw new Error();
  const padded = value.replaceAll("-", "+").replaceAll("_", "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  return JSON.parse(new TextDecoder(undefined, { fatal: true }).decode(bytes));
}

function isSearchCursor(value: unknown, query: string): value is SearchCursorPayload {
  if (typeof value !== "object" || value === null) return false;
  const item = value as Record<string, unknown>;
  if (item.v !== 1 || item.kind !== "search" || item.query !== query) return false;
  if (typeof item.createdAt !== "string" || typeof item.id !== "string" || !UUID.test(item.id)) return false;
  return isTimestamp(item.createdAt);
}

function isTimestamp(value: string): boolean {
  const date = value.match(
    /^(\d{4})-(\d{2})-(\d{2})T([01]\d|2[0-3]):([0-5]\d):([0-5]\d)(?:\.\d{1,6})?(?:Z|[+-](?:0\d|1[0-5]):[0-5]\d)$/,
  );
  if (!date) return false;
  const [year, month, day] = date.slice(1, 4).map(Number);
  const leapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const daysPerMonth = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  // Date.parse normalizes some impossible dates; reject them before sending to Postgres.
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > daysPerMonth[month - 1]) {
    return false;
  }
  return !Number.isNaN(Date.parse(value));
}

function isCursor(value: unknown): value is CursorPayload {
  if (typeof value !== "object" || value === null) return false;
  const item = value as Record<string, unknown>;
  if ("kind" in item || "query" in item) return false;
  if (item.v !== 1 || typeof item.createdAt !== "string" || typeof item.id !== "string") return false;
  if (!UUID.test(item.id) || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$/.test(item.createdAt)) return false;
  return !Number.isNaN(Date.parse(item.createdAt));
}

export class InvalidCursorError extends Error {}
export const isUUID = (value: string): boolean => UUID.test(value);
