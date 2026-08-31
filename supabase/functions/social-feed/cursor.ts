import type { CursorPayload } from "./types.ts";

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
    if (!value || !/^[A-Za-z0-9_-]+$/.test(value)) throw new Error();
    const padded = value.replaceAll("-", "+").replaceAll("_", "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
    const binary = atob(padded);
    const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
    const payload: unknown = JSON.parse(new TextDecoder(undefined, { fatal: true }).decode(bytes));
    if (!isCursor(payload)) throw new Error();
    return payload;
  } catch {
    throw new InvalidCursorError();
  }
}

function isCursor(value: unknown): value is CursorPayload {
  if (typeof value !== "object" || value === null) return false;
  const item = value as Record<string, unknown>;
  if (item.v !== 1 || typeof item.createdAt !== "string" || typeof item.id !== "string") return false;
  if (!UUID.test(item.id) || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$/.test(item.createdAt)) return false;
  return !Number.isNaN(Date.parse(item.createdAt));
}

export class InvalidCursorError extends Error {}
export const isUUID = (value: string): boolean => UUID.test(value);
