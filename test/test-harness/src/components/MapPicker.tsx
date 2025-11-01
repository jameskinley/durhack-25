import { MapContainer, TileLayer, Marker, useMapEvents, Polyline, useMap } from 'react-leaflet';
import L from 'leaflet';
import type { LatLngExpression } from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useEffect, useMemo, useState } from 'react';
import { curatePlaylist, type PlaylistTrack } from '../lib/api';

// Fix default marker icons for Leaflet with Vite
import markerIcon2x from 'leaflet/dist/images/marker-icon-2x.png';
import markerIcon from 'leaflet/dist/images/marker-icon.png';
import markerShadow from 'leaflet/dist/images/marker-shadow.png';
(L.Icon.Default as any).mergeOptions({
  iconRetinaUrl: markerIcon2x,
  iconUrl: markerIcon,
  shadowUrl: markerShadow,
});

type LatLng = { lat: number; lng: number };

function ClickHandler({ onClick }: { onClick: (latlng: LatLng) => void }) {
  useMapEvents({
    click(e: any) {
      onClick({ lat: e.latlng.lat, lng: e.latlng.lng });
    },
  });
  return null;
}

function MapRefSetter({ onReady }: { onReady: (m: L.Map) => void }) {
  const map = useMap();
  useEffect(() => { onReady(map); }, [map, onReady]);
  return null;
}

export default function MapPicker({ journeyId }: { journeyId?: string | null }) {
  const [a, setA] = useState<LatLng | null>(null);
  const [b, setB] = useState<LatLng | null>(null);
  const [addrA, setAddrA] = useState<string>('');
  const [addrB, setAddrB] = useState<string>('');
  const [status, setStatus] = useState<string>('');
  const [map, setMap] = useState<L.Map | null>(null);
  const [route, setRoute] = useState<LatLngExpression[] | null>(null);
  const [durationMin, setDurationMin] = useState<number>(20);
  const [curating, setCurating] = useState<boolean>(false);
  const [playlist, setPlaylist] = useState<PlaylistTrack[] | null>(null);
  const center: LatLngExpression = useMemo(() => [51.505, -0.09], []);

  function onMapClick(latlng: LatLng) {
    if (!a) setA(latlng);
    else if (!b) setB(latlng);
    else {
      // replace the nearest marker to the click
      const da = Math.hypot(latlng.lat - a.lat, latlng.lng - a.lng);
      const db = Math.hypot(latlng.lat - (b?.lat ?? 0), latlng.lng - (b?.lng ?? 0));
      if (da <= db) setA(latlng); else setB(latlng);
    }
  }

  async function geocode(query: string): Promise<LatLng | null> {
    try {
      if (!query.trim()) return null;
      const url = `https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${encodeURIComponent(query)}`;
      const res = await fetch(url, { headers: { 'Accept': 'application/json' } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json() as Array<{ lat: string; lon: string }>;
      if (!Array.isArray(data) || data.length === 0) return null;
      const { lat, lon } = data[0];
      return { lat: Number(lat), lng: Number(lon) };
    } catch (e) {
      console.error('geocode failed', e);
      return null;
    }
  }

  async function findA() {
    setStatus('');
    const pt = await geocode(addrA);
    if (pt) {
      setA(pt);
      if (map) map.setView([pt.lat, pt.lng], 13);
    } else {
      setStatus('Address A not found');
    }
  }

  async function findB() {
    setStatus('');
    const pt = await geocode(addrB);
    if (pt) {
      setB(pt);
      if (map) map.setView([pt.lat, pt.lng], 13);
    } else {
      setStatus('Address B not found');
    }
  }

  async function buildRoute(a: LatLng, b: LatLng): Promise<LatLngExpression[] | null> {
    try {
      const url = `https://router.project-osrm.org/route/v1/driving/${a.lng},${a.lat};${b.lng},${b.lat}?overview=full&geometries=geojson`;
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      const coords: [number, number][] | undefined = data?.routes?.[0]?.geometry?.coordinates;
      if (!coords || coords.length === 0) return null;
      // Convert [lon, lat] -> [lat, lon]
      return coords.map(([lon, lat]) => [lat, lon]);
    } catch (e) {
      console.error('route failed', e);
      return null;
    }
  }

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (a && b) {
        setStatus('');
        const r = await buildRoute(a, b);
        if (!cancelled) {
          setRoute(r);
          if (r && r.length && map) {
            const bounds = L.latLngBounds(r as any);
            map.fitBounds(bounds, { padding: [20, 20] });
          }
        }
      } else {
        setRoute(null);
      }
    })();
    return () => { cancelled = true; };
  }, [a, b, map]);

  function toPoints(): { x: number; y: number }[] {
    if (route && Array.isArray(route) && route.length > 1) {
      const pts = (route as [number, number][]);
      const maxPts = 200;
      const step = Math.max(1, Math.ceil(pts.length / maxPts));
      const sampled: [number, number][] = [];
      for (let i = 0; i < pts.length; i += step) sampled.push(pts[i]);
      const last = pts[pts.length - 1];
      if (sampled.length === 0 || sampled[sampled.length - 1] !== last) sampled.push(last);
      return sampled.map(([lat, lon]) => ({ x: lon, y: lat }));
    }
    if (a && b) return [ { x: a.lng, y: a.lat }, { x: b.lng, y: b.lat } ];
    return [];
  }

  async function onCurate() {
    setStatus('');
    setPlaylist(null);
    if (!journeyId) { setStatus('Create a journey first'); return; }
    const pts = toPoints();
    if (pts.length < 2) { setStatus('Pick two locations or build a route first'); return; }
    setCurating(true);
    try {
      const pl = await curatePlaylist({ journeyId, points: pts, durationSeconds: Math.max(60, Math.round(durationMin * 60)) });
      setPlaylist(pl);
    } catch (e) {
      console.error('curate failed', e);
      setStatus('Failed to curate playlist');
    } finally {
      setCurating(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="text-xs text-gray-500">Point A</label>
          <div className="mt-2 flex gap-2">
            <input
              className="h-10 w-full rounded-lg border px-3"
              placeholder="Address A (e.g. Durham Cathedral)"
              value={addrA}
              onChange={e => setAddrA(e.target.value)}
              onKeyDown={e => { if (e.key === 'Enter') void findA(); }}
            />
            <button className="h-10 px-4 rounded-lg bg-gray-900 text-white" onClick={findA}>Find A</button>
          </div>
        </div>
        <div>
          <label className="text-xs text-gray-500">Point B</label>
          <div className="mt-2 flex gap-2">
            <input
              className="h-10 w-full rounded-lg border px-3"
              placeholder="Address B (e.g. Newcastle Station)"
              value={addrB}
              onChange={e => setAddrB(e.target.value)}
              onKeyDown={e => { if (e.key === 'Enter') void findB(); }}
            />
            <button className="h-10 px-4 rounded-lg bg-gray-900 text-white" onClick={findB}>Find B</button>
          </div>
        </div>
      </div>

      <div className="h-[400px] rounded-xl overflow-hidden border">
        <MapContainer center={center} zoom={13} style={{ height: '100%', width: '100%' }}>
          <MapRefSetter onReady={setMap} />
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          <ClickHandler onClick={onMapClick} />
          {a && <Marker position={[a.lat, a.lng]} draggable eventHandlers={{ dragend: (e: any) => {
            const m = e.target as L.Marker; const p = m.getLatLng(); setA({ lat: p.lat, lng: p.lng });
          } }} />}
          {b && <Marker position={[b.lat, b.lng]} draggable eventHandlers={{ dragend: (e: any) => {
            const m = e.target as L.Marker; const p = m.getLatLng(); setB({ lat: p.lat, lng: p.lng });
          } }} />}
          {route && <Polyline positions={route} pathOptions={{ color: '#2563eb', weight: 4 }} />}
        </MapContainer>
      </div>

      {status && <div className="text-sm text-red-600">{status}</div>}

      {(a || b) && (
        <div className="text-sm text-gray-600">
          {a && <div>A: {a.lat.toFixed(5)}, {a.lng.toFixed(5)}</div>}
          {b && <div>B: {b.lat.toFixed(5)}, {b.lng.toFixed(5)}</div>}
        </div>
      )}

      <div className="flex items-end gap-3">
        <div>
          <label className="text-xs text-gray-500">Planned duration (minutes)</label>
          <input type="number" min={1} className="mt-1 h-10 w-32 rounded-lg border px-3" value={durationMin} onChange={e => setDurationMin(Number(e.target.value))} />
        </div>
        <button onClick={onCurate} disabled={curating || !journeyId} className="h-10 px-4 rounded-lg bg-gray-900 text-white disabled:opacity-50">
          {curating ? 'Generating…' : 'Generate playlist'}
        </button>
      </div>

      {playlist && (
        <div className="mt-4">
          <h3 className="text-sm font-medium mb-2">Playlist</h3>
          <ul className="divide-y border rounded-lg">
            {playlist.map((p, idx) => (
              <li key={idx} className="p-3 flex items-center justify-between">
                <div>
                  <div className="font-medium">{p.track}</div>
                  <div className="text-xs text-gray-500">{p.artist}</div>
                </div>
                <span className={`text-xs px-2 py-1 rounded-full border ${p.type === 'bio' ? 'bg-amber-50 border-amber-200 text-amber-700' : 'bg-gray-50 border-gray-200 text-gray-600'}`}>
                  {p.type === 'bio' ? 'Artist bio' : 'Track'}
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
