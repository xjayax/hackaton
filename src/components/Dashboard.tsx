import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { User, LogOut, Database } from 'lucide-react'

export default function Dashboard() {
  const [user, setUser] = useState<any>(null)
  const [profile, setProfile] = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    getProfile()
  }, [])

  const getProfile = async () => {
    try {
      setLoading(true)
      
      const { data: { user } } = await supabase.auth.getUser()
      setUser(user)

      if (user) {
        // Essayer de récupérer le profil depuis la table users
        const { data: userData, error: userError } = await supabase
          .from('users')
          .select('*')
          .eq('id', user.id)
          .single()

        if (userError) {
          console.log('Erreur lors de la récupération du profil users:', userError)
        } else {
          setProfile(userData)
        }

        // Si pas de profil dans users, essayer dans profiles
        if (!userData) {
          const { data: profileData, error: profileError } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .single()

          if (profileError) {
            console.log('Erreur lors de la récupération du profil profiles:', profileError)
          } else {
            setProfile(profileData)
          }
        }
      }
    } catch (error) {
      console.error('Erreur:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleLogout = async () => {
    const { error } = await supabase.auth.signOut()
    if (error) {
      console.error('Erreur lors de la déconnexion:', error)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Chargement...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <Database className="h-8 w-8 text-blue-600 mr-3" />
              <h1 className="text-xl font-bold text-gray-900">TradingPros Dashboard</h1>
            </div>
            <button
              onClick={handleLogout}
              className="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:text-gray-900 border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
            >
              <LogOut className="h-4 w-4" />
              Déconnexion
            </button>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Informations utilisateur */}
            <div className="bg-white overflow-hidden shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <div className="flex items-center">
                  <User className="h-8 w-8 text-blue-600 mr-3" />
                  <h2 className="text-lg font-medium text-gray-900">Informations utilisateur</h2>
                </div>
                <div className="mt-4 space-y-3">
                  <div>
                    <span className="text-sm font-medium text-gray-500">Email:</span>
                    <p className="text-sm text-gray-900">{user?.email}</p>
                  </div>
                  <div>
                    <span className="text-sm font-medium text-gray-500">ID:</span>
                    <p className="text-sm text-gray-900 font-mono">{user?.id}</p>
                  </div>
                  <div>
                    <span className="text-sm font-medium text-gray-500">Créé le:</span>
                    <p className="text-sm text-gray-900">
                      {user?.created_at ? new Date(user.created_at).toLocaleString('fr-FR') : 'N/A'}
                    </p>
                  </div>
                </div>
              </div>
            </div>

            {/* Profil */}
            <div className="bg-white overflow-hidden shadow rounded-lg">
              <div className="px-4 py-5 sm:p-6">
                <h2 className="text-lg font-medium text-gray-900 mb-4">Profil</h2>
                {profile ? (
                  <div className="space-y-3">
                    <div>
                      <span className="text-sm font-medium text-gray-500">Nom d'affichage:</span>
                      <p className="text-sm text-gray-900">{profile.display_name || profile.full_name || 'Non défini'}</p>
                    </div>
                    <div>
                      <span className="text-sm font-medium text-gray-500">Rôle:</span>
                      <p className="text-sm text-gray-900">{profile.role || 'user'}</p>
                    </div>
                    <div>
                      <span className="text-sm font-medium text-gray-500">Statut:</span>
                      <p className="text-sm text-gray-900">{profile.status || profile.subscription_tier || 'Actif'}</p>
                    </div>
                  </div>
                ) : (
                  <p className="text-sm text-gray-500">Aucun profil trouvé</p>
                )}
              </div>
            </div>
          </div>

          {/* Informations de debug */}
          <div className="mt-6 bg-white overflow-hidden shadow rounded-lg">
            <div className="px-4 py-5 sm:p-6">
              <h2 className="text-lg font-medium text-gray-900 mb-4">Informations de debug</h2>
              <div className="bg-gray-50 p-4 rounded-lg">
                <pre className="text-xs text-gray-600 overflow-auto">
                  {JSON.stringify({ user, profile }, null, 2)}
                </pre>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}