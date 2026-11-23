/** Reads a PostGIS point returned by the API (hex EWKB) → {lat, lng}. */
export function parsePoint(hex: string | null | undefined): { lat: number; lng: number } | null {
  if (!hex || hex.length < 42) return null;
  try {
    const bytes = new Uint8Array(hex.match(/../g)!.map((b) => parseInt(b, 16)));
    const view = new DataView(bytes.buffer);
    const little = bytes[0] === 1;
    const type = view.getUint32(1, little);
    const offset = type & 0x20000000 ? 9 : 5; // skip SRID when present
    const lng = view.getFloat64(offset, little);
    const lat = view.getFloat64(offset + 8, little);
    return Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : null;
  } catch {
    return null;
  }
}

export const mapsLink = (p: { lat: number; lng: number }) =>
  `https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lng}`;
