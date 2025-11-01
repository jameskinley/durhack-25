import './App.css'
import UserFlow from './components/UserFlow'
import MapPicker from './components/MapPicker'

export default function App() {
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
          <h2 className="text-lg font-medium mb-3">User Setup</h2>
          <UserFlow />
        </section>

        <section className="rounded-xl border p-4 bg-white">
          <h2 className="text-lg font-medium mb-3">Pick Locations</h2>
          <MapPicker />
        </section>
      </main>
    </div>
  )
}
