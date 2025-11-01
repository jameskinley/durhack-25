export type GetUserResponse = { id?: string; message?: string };
export type GetTagsResponse = { tags: string[] };

const base = import.meta.env.VITE_FUNCTIONS_URL?.replace(/\/$/, '') ?? '';

async function json<T>(res: Response): Promise<T> {
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json() as Promise<T>;
}

export async function getUserByName(name: string): Promise<GetUserResponse> {
  const url = `${base}/get-user?name=${encodeURIComponent(name)}`;
  const res = await fetch(url, { method: 'GET' });
  return json<GetUserResponse>(res);
}

export async function createUser(name: string, preferences: string[]): Promise<{ ok: boolean }>
{
  const url = `${base}/create-user`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, preferences })
  });
  // treat any 2xx as ok
  await json<any>(res);
  return { ok: true };
}

export async function getAllTags(): Promise<string[]> {
  const url = `${base}/get-tags`;
  try {
    const res = await fetch(url, { method: 'GET' });
    const data = await json<GetTagsResponse>(res);
    return data.tags ?? [];
  } catch {
    // fallback for local UI testing if function is unavailable
    return ['rock', 'pop', 'reggae', '60s', 'upbeat', 'jazz', 'electronic', 'indie'];
  }
}
