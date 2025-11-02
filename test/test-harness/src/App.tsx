import './App.css'
import UserFlow from './components/UserFlow'
import MapPicker from './components/MapPicker'
import { useState } from 'react'

export default function App() {
  const [journeyId, setJourneyId] = useState<string | null>(null)
  return (
    <div className="min-h-screen bg-white text-gray-900">
      <header className="border-b bg-gray-50/80 backdrop-blur sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-4 py-4 flex items-center justify-between">
          <h1 className="text-xl font-semibold tracking-tight">Durhack • Test Harness</h1>
          <div className="text-sm text-gray-500">Flat UI • Tailwind</div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 py-6 grid grid-cols-1 lg:grid-cols-2 gap-6">
        <section className="rounded-xl border p-4 bg-white">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-lg font-medium">Preferences</h2>
            {journeyId && (
              <div className="text-xs px-2 py-1 rounded-full bg-gray-100 border font-mono text-gray-600">id: {journeyId}</div>
            )}
          </div>
          <UserFlow onReady={setJourneyId} />
        </section>

        <section className="rounded-xl border p-4 bg-white">
          <h2 className="text-lg font-medium mb-3">Pick Locations</h2>
          <MapPicker journeyId={journeyId} />
        </section>
      </main>
    </div>
  )
}
