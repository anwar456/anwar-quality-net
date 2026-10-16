/**
 * The API stores skills as Rails nested attributes: it deletes an existing child only when it receives
 * `{ id, _destroy: true }`. A child that is merely left out of the payload is kept.
 *
 * An edit form drops a removed row from its list, so on its own it would tell the user "removed" while the
 * server keeps the record (audit R-03). Call this with the list as loaded and the list as submitted: it returns
 * the submitted rows plus a destroy marker for every loaded row that is gone.
 */
export function withDestroyed<T extends { id?: number }>(
  original: readonly T[],
  current: readonly T[]
): (T | { id: number; _destroy: true })[] {
  const kept = new Set(current.map((row) => row.id).filter((id): id is number => id != null));
  const removed = original
    .filter((row) => row.id != null && !kept.has(row.id))
    .map((row) => ({ id: row.id as number, _destroy: true as const }));
  return [...current, ...removed];
}
