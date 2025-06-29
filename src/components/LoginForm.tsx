import { useState } from 'react'
import { supabase, diagnosticSupabase } from '../lib/supabase'
import { Eye, EyeOff, AlertCircle, CheckCircle } from 'lucide-react'

interface LoginFormProps {
  onSuccess?: () => void
}

export default function LoginForm({ onSuccess }: LoginFormProps) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)
  const [isSignUp, setIsSignUp] = useState(false)
  const [diagnosticInfo, setDiagnosticInfo] = useState<any>(null)

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    setSuccess(null)

    try {
      console.log('Tentative de connexion avec:', { email, password: '***' })

      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      })

      console.log('Réponse de connexion:', { data, error })

      if (error) {
        console.error('Erreur de connexion:', error)
        setError(`Erreur de connexion: ${error.message}`)
        
        // Log de sécurité en cas d'échec
        await logSecurityEvent('login_failed', false, { error: error.message })
      } else {
        console.log('Connexion réussie:', data)
        setSuccess('Connexion réussie!')
        
        // Log de sécurité en cas de succès
        await logSecurityEvent('login_success', true, { user_id: data.user?.id })
        
        if (onSuccess) {
          onSuccess()
        }
      }
    } catch (err) {
      console.error('Erreur inattendue:', err)
      setError(`Erreur inattendue: ${err}`)
    } finally {
      setLoading(false)
    }
  }

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    setSuccess(null)

    try {
      console.log('Tentative d\'inscription avec:', { email, password: '***' })

      const { data, error } = await supabase.auth.signUp({
        email,
        password,
      })

      console.log('Réponse d\'inscription:', { data, error })

      if (error) {
        console.error('Erreur d\'inscription:', error)
        setError(`Erreur d'inscription: ${error.message}`)
      } else {
        console.log('Inscription réussie:', data)
        setSuccess('Inscription réussie! Vérifiez votre email si nécessaire.')
        
        // Log de sécurité
        await logSecurityEvent('signup_success', true, { user_id: data.user?.id })
      }
    } catch (err) {
      console.error('Erreur inattendue:', err)
      setError(`Erreur inattendue: ${err}`)
    } finally {
      setLoading(false)
    }
  }

  const logSecurityEvent = async (actionType: string, success: boolean, details: any) => {
    try {
      const { error } = await supabase.from('user_security_logs').insert({
        action_type: actionType,
        success: success,
        details: details,
        ip_address: '127.0.0.1', // En production, récupérer la vraie IP
        user_agent: navigator.userAgent
      })
      
      if (error) {
        console.warn('Impossible de logger l\'événement de sécurité:', error)
      }
    } catch (err) {
      console.warn('Erreur lors du logging:', err)
    }
  }

  const runDiagnostic = async () => {
    console.log('Lancement du diagnostic...')
    const diagnostic = await diagnosticSupabase()
    setDiagnosticInfo(diagnostic)
  }

  const testDatabaseAccess = async () => {
    try {
      // Test d'accès aux différentes tables
      const tests = [
        { name: 'users', query: supabase.from('users').select('id').limit(1) },
        { name: 'profiles', query: supabase.from('profiles').select('id').limit(1) },
        { name: 'user_security_logs', query: supabase.from('user_security_logs').select('id').limit(1) },
      ]

      for (const test of tests) {
        try {
          const { data, error } = await test.query
          console.log(`✅ Table ${test.name}:`, { data, error })
        } catch (err) {
          console.error(`❌ Table ${test.name}:`, err)
        }
      }
    } catch (err) {
      console.error('Erreur lors du test d\'accès:', err)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="bg-white p-8 rounded-xl shadow-2xl w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-gray-800 mb-2">TradingPros</h1>
          <p className="text-gray-600">
            {isSignUp ? 'Créer un compte' : 'Connexion à votre compte'}
          </p>
        </div>

        {error && (
          <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg flex items-center gap-3">
            <AlertCircle className="h-5 w-5 text-red-500 flex-shrink-0" />
            <p className="text-red-700 text-sm">{error}</p>
          </div>
        )}

        {success && (
          <div className="mb-4 p-4 bg-green-50 border border-green-200 rounded-lg flex items-center gap-3">
            <CheckCircle className="h-5 w-5 text-green-500 flex-shrink-0" />
            <p className="text-green-700 text-sm">{success}</p>
          </div>
        )}

        <form onSubmit={isSignUp ? handleSignUp : handleLogin} className="space-y-6">
          <div>
            <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
              Email
            </label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-colors"
              placeholder="votre@email.com"
              required
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
              Mot de passe
            </label>
            <div className="relative">
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-4 py-3 pr-12 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-colors"
                placeholder="••••••••"
                required
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-gray-700"
              >
                {showPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white font-semibold py-3 px-4 rounded-lg transition-colors focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
          >
            {loading ? 'Chargement...' : (isSignUp ? 'S\'inscrire' : 'Se connecter')}
          </button>
        </form>

        <div className="mt-6 text-center">
          <button
            onClick={() => setIsSignUp(!isSignUp)}
            className="text-blue-600 hover:text-blue-700 font-medium"
          >
            {isSignUp ? 'Déjà un compte ? Se connecter' : 'Pas de compte ? S\'inscrire'}
          </button>
        </div>

        {/* Outils de diagnostic */}
        <div className="mt-8 pt-6 border-t border-gray-200">
          <h3 className="text-sm font-medium text-gray-700 mb-3">Outils de diagnostic</h3>
          <div className="space-y-2">
            <button
              onClick={runDiagnostic}
              className="w-full text-left px-3 py-2 text-sm bg-gray-50 hover:bg-gray-100 rounded border"
            >
              🔍 Diagnostic Supabase
            </button>
            <button
              onClick={testDatabaseAccess}
              className="w-full text-left px-3 py-2 text-sm bg-gray-50 hover:bg-gray-100 rounded border"
            >
              🗄️ Test accès base de données
            </button>
          </div>
          
          {diagnosticInfo && (
            <div className="mt-4 p-3 bg-gray-50 rounded text-xs">
              <pre>{JSON.stringify(diagnosticInfo, null, 2)}</pre>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}