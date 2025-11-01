import { MapContainer, TileLayer, Marker, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import type { LatLngExpression } from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useMemo, useState } from 'react';

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

export default function MapPicker() {
  const [a, setA] = useState<LatLng | null>(null);
  const [b, setB] = useState<LatLng | null>(null);
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

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="text-xs text-gray-500">Point A (lat, lng)</label>
          <div className="flex gap-2">
            <input
              className="h-10 w-full rounded-lg border px-3"
              placeholder="lat"
              value={a?.lat ?? ''}
              onChange={e => setA({ lat: Number(e.target.value || 0), lng: a?.lng ?? 0 })}
            />
            <input
              className="h-10 w-full rounded-lg border px-3"
              placeholder="lng"
              value={a?.lng ?? ''}
              onChange={e => setA({ lat: a?.lat ?? 0, lng: Number(e.target.value || 0) })}
            />
          </div>
        </div>
        <div>
          <label className="text-xs text-gray-500">Point B (lat, lng)</label>
          <div className="flex gap-2">
            <input
              className="h-10 w-full rounded-lg border px-3"
              placeholder="lat"
              value={b?.lat ?? ''}
              onChange={e => setB({ lat: Number(e.target.value || 0), lng: b?.lng ?? 0 })}
            />
            <input
              className="h-10 w-full rounded-lg border px-3"
              placeholder="lng"
              value={b?.lng ?? ''}
              onChange={e => setB({ lat: b?.lat ?? 0, lng: Number(e.target.value || 0) })}
            />
          </div>
        </div>
      </div>

      <div className="h-[400px] rounded-xl overflow-hidden border">
        <MapContainer center={center} zoom={13} style={{ height: '100%', width: '100%' }}>
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
        </MapContainer>
      </div>

      {(a || b) && (
        <div className="text-sm text-gray-600">
          {a && <div>A: {a.lat.toFixed(5)}, {a.lng.toFixed(5)}</div>}
          {b && <div>B: {b.lat.toFixed(5)}, {b.lng.toFixed(5)}</div>}
        </div>
      )}
    </div>
  );
}
