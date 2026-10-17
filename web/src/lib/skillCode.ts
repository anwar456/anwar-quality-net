/**
 * The short code shown next to a skill name.
 * Taxonomy ids already look like "SK-ENG-001" and are shown as stored; older numeric ids are padded ("SK-007").
 */
export function formatSkillCode(id: string | number | null | undefined): string {
  if (id == null || id === "") return "";
  if (typeof id === "number" || /^\d+$/.test(id)) return `SK-${String(id).padStart(3, "0")}`;
  return id;
}
