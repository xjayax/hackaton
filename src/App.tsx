import { useState } from 'react'
import './App.css'

function App() {
  const [count, setCount] = useState(0)

  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center">
      <div className="bg-white p-8 rounded-lg shadow-lg text-center">
        <h1 className="text-3xl font-bold text-gray-800 mb-4">TradingPros</h1>
        <p className="text-gray-600 mb-6">
          Votre plateforme de trading professionnelle
        </p>
        <button
          className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded transition-colors"
          onClick={() => setCount((count) => count + 1)}
        >
          Compteur: {count}
        </button>
      </div>
    </div>
  )
}

export default App