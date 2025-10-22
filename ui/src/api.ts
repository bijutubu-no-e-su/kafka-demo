const API_BASE = import.meta.env.VITE_API_BASE || "";

export type PanelName = "a" | "b" | "c" | "d";

export async function fetchPanelColor(name: PanelName): Promise<string> {
  const res = await fetch(`${API_BASE}/api/panel/${name}`, {
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`fetch ${name} failed: ${res.status}`);
  const json = await res.json();
  return (json?.color as string) || "gray";
}

export async function fetchAllPanels(): Promise<{
  a: string;
  b: string;
  c: string;
  d: string;
}> {
  const res = await fetch(`${API_BASE}/api/panels`, { cache: "no-store" });
  if (!res.ok) throw new Error(`fetch panels failed: ${res.status}`);
  const json = await res.json();
  return {
    a: json.a || "gray",
    b: json.b || "gray",
    c: json.c || "gray",
    d: json.d || "gray",
  };
}
