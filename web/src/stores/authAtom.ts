import { atom } from "jotai";

export interface AuthState {
  token: string | null;
}

const STORAGE_KEY = "auth_token";

export function getStoredToken(): string | null {
  // A pre-issued token for local work. `import.meta.env.DEV` is false in production builds, so the branch (and the
  // token with it) is removed from the bundle and logging out really logs out.
  const devToken = import.meta.env.DEV ? import.meta.env.VITE_DEV_TOKEN : undefined;
  return localStorage.getItem(STORAGE_KEY) ?? devToken ?? null;
}

export function saveToken(token: string) {
  localStorage.setItem(STORAGE_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(STORAGE_KEY);
}

export const authAtom = atom<AuthState>({
  token: getStoredToken(),
});
