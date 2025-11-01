import { useMemo, useState } from 'react';
import { createUser, getAllTags, getUserByName } from '../lib/api';

export default function UserFlow() {
  const [name, setName] = useState('');
  const [status, setStatus] = useState<string>('');
  const [userId, setUserId] = useState<string | null>(null);
  const [allTags, setAllTags] = useState<string[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(false);

  const canCreate = useMemo(() => name.trim().length > 0 && selected.size > 0, [name, selected]);

  async function onGetUser() {
    setStatus('');
    setUserId(null);
    if (!name.trim()) {
      setStatus('Enter a name first');
      return;
    }
    setLoading(true);
    try {
      const res = await getUserByName(name.trim());
      if (res.id) {
        setUserId(res.id);
        setStatus('User exists');
      } else {
        setStatus('No user; pick tags to create');
        // Load tags if not yet loaded
        if (allTags.length === 0) {
          const tags = await getAllTags();
          setAllTags(tags);
        }
      }
    } catch (e: any) {
      setStatus(`Error: ${e?.message ?? 'failed'}`);
    } finally {
      setLoading(false);
    }
  }

  async function onCreateUser() {
    if (!canCreate) return;
    setLoading(true);
    setStatus('Creating user...');
    try {
      const ok = await createUser(name.trim(), Array.from(selected));
      if (ok.ok) {
        setStatus('User created. Click "Get user" again to fetch id.');
        setSelected(new Set());
      } else {
        setStatus('Failed to create user');
      }
    } catch (e: any) {
      setStatus(`Error: ${e?.message ?? 'failed'}`);
    } finally {
      setLoading(false);
    }
  }

  function toggleTag(tag: string) {
    setSelected(prev => {
      const next = new Set(prev);
      if (next.has(tag)) next.delete(tag); else next.add(tag);
      return next;
    });
  }

  // Flat, fluid UI
  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-2">
        <label className="text-sm text-gray-600">User name</label>
        <input
          value={name}
          onChange={e => setName(e.target.value)}
          placeholder="e.g. alex"
          className="h-11 px-3 rounded-lg border bg-white outline-none focus:ring-2 ring-gray-200"
        />
        <div className="flex gap-2">
          <button
            onClick={onGetUser}
            disabled={loading}
            className="h-10 px-4 rounded-lg bg-gray-900 text-white disabled:opacity-50"
          >
            {loading ? 'Loading...' : 'Get user'}
          </button>
        </div>
        {status && <div className="text-sm text-gray-600">{status}</div>}
        {userId && (
          <div className="text-sm">
            <span className="text-gray-500">User ID:</span> <span className="font-mono">{userId}</span>
          </div>
        )}
      </div>

      {(!userId && allTags.length > 0) && (
        <div className="space-y-3">
          <div className="text-sm text-gray-600">Select preferences</div>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2">
            {allTags.map(tag => (
              <button
                key={tag}
                onClick={() => toggleTag(tag)}
                className={`h-9 px-3 rounded-lg border text-sm text-left ${selected.has(tag) ? 'bg-gray-900 text-white' : 'bg-white hover:bg-gray-50'}`}
              >
                {tag}
              </button>
            ))}
          </div>
          <div className="pt-2">
            <button
              onClick={onCreateUser}
              disabled={!canCreate || loading}
              className="h-10 px-4 rounded-lg bg-gray-900 text-white disabled:opacity-50"
            >
              Create user
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
