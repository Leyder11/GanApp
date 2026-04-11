import { Timestamp } from "firebase-admin/firestore";

function convertValue(value: unknown): unknown {
  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }

  if (Array.isArray(value)) {
    return value.map((item) => convertValue(item));
  }

  if (value && typeof value === "object") {
    const obj = value as Record<string, unknown>;
    const converted: Record<string, unknown> = {};

    Object.entries(obj).forEach(([key, nestedValue]) => {
      converted[key] = convertValue(nestedValue);
    });

    return converted;
  }

  return value;
}

export function mapDoc<T>(docId: string, data: Record<string, unknown>): T & { id: string } {
  const normalized = convertValue(data) as T;
  return {
    id: docId,
    ...normalized,
  };
}