import { useEffect, useMemo, useState } from 'react';
import { createJourney, getAllTags } from '../lib/api';

export default function UserFlow({ onReady }: { onReady: (journeyId: string) => void }) {
  const [name, setName] = useState('');
  const [status, setStatus] = useState<string>('');
  const [allTags, setAllTags] = useState<string[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const tags = await getAllTags();
        setAllTags(tags);
      } catch {
        // fallback handled in getAllTags
      }
    })();
  }, []);

  const canCreate = useMemo(() => name.trim().length > 0 && selected.size > 0, [name, selected]);

  async function onCreateUser() {
    if (!canCreate) return;
    setLoading(true);
    setStatus('Creating journey...');
    try {
      const res = await createJourney(name.trim(), Array.from(selected));
      if (res.ok) {
        setStatus('Journey created. You can now pick a route to generate a playlist.');
        onReady(res.id ?? name.trim());
        setSelected(new Set());
      } else {
        setStatus('Failed to create journey');
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
        <label className="text-sm text-gray-600">Journey name</label>
        <input
          value={name}
          onChange={e => setName(e.target.value)}
          placeholder="e.g. Morning Commute"
          className="h-11 px-3 rounded-lg border bg-white outline-none focus:ring-2 ring-gray-200"
        />
        {status && <div className="text-sm text-gray-600">{status}</div>}
      </div>

      {(allTags.length > 0) && (
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
              Create journey
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
