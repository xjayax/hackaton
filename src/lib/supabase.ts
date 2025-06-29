import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase environment variables')
  console.log('VITE_SUPABASE_URL:', supabaseUrl)
  console.log('VITE_SUPABASE_ANON_KEY:', supabaseAnonKey ? 'Present' : 'Missing')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
})

// Fonction de diagnostic
export const diagnosticSupabase = async () => {
  console.log('=== DIAGNOSTIC SUPABASE ===')
  
  try {
    // Test de connexion de base
    const { data, error } = await supabase.from('users').select('count').limit(1)
    console.log('✅ Connexion Supabase réussie')
  } catch (error) {
    console.error('❌ Erreur de connexion Supabase:', error)
  }

  // Vérifier la session actuelle
  const { data: session } = await supabase.auth.getSession()
  console.log('Session actuelle:', session)

  // Vérifier l'utilisateur actuel
  const { data: user } = await supabase.auth.getUser()
  console.log('Utilisateur actuel:', user)

  return { session, user }
}