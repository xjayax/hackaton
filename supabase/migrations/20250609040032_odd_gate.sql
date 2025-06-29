/*
  # Nettoyage complet de la base de données

  1. Suppression des tables
    - Supprime toutes les tables personnalisées créées pour les bots
    - Supprime toutes les vues personnalisées
    - Supprime toutes les fonctions personnalisées
    - Supprime tous les triggers personnalisés
    - Garde uniquement les tables essentielles de l'application

  2. Recréation des tables essentielles
    - `users` - Profils utilisateurs
    - `trades` - Historique des trades
    - `alerts` - Alertes de prix
    - `portfolios` - Données de portfolio
    - `exchange_keys` - Clés d'API des exchanges
    - `bot_configs` - Configurations des bots
    - `user_bot_credentials` - Identifiants des bots
    - `payment_methods` - Méthodes de paiement
    - `user_security_logs` - Logs de sécurité

  3. Sécurité
    - Enable RLS sur toutes les tables
    - Recréation des politiques de sécurité appropriées
*/

-- Désactiver temporairement RLS pour le nettoyage
SET session_replication_role = replica;

-- Supprimer toutes les vues personnalisées
DROP VIEW IF EXISTS admin_user_overview CASCADE;

-- Supprimer tous les triggers personnalisés
DROP TRIGGER IF EXISTS create_bot_credentials_trigger ON users CASCADE;

-- Supprimer toutes les fonctions personnalisées
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS create_bot_credentials_trigger() CASCADE;
DROP FUNCTION IF EXISTS user_is_active(uuid) CASCADE;
DROP FUNCTION IF EXISTS change_site_password(text) CASCADE;
DROP FUNCTION IF EXISTS change_bot_password(text) CASCADE;
DROP FUNCTION IF EXISTS add_payment_method(text, jsonb, boolean) CASCADE;
DROP FUNCTION IF EXISTS remove_payment_method(uuid) CASCADE;
DROP FUNCTION IF EXISTS delete_user_completely(uuid) CASCADE;
DROP FUNCTION IF EXISTS disable_user_account(uuid) CASCADE;

-- Supprimer toutes les tables dans l'ordre correct (en tenant compte des dépendances)
DROP TABLE IF EXISTS user_security_logs CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;
DROP TABLE IF EXISTS user_bot_credentials CASCADE;
DROP TABLE IF EXISTS bot_configs CASCADE;
DROP TABLE IF EXISTS portfolios CASCADE;
DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS trades CASCADE;
DROP TABLE IF EXISTS exchange_keys CASCADE;
DROP TABLE IF EXISTS coinbase_accounts CASCADE;
DROP TABLE IF EXISTS wallets CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Réactiver RLS
SET session_replication_role = DEFAULT;

-- Recréer la table users
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text,
  avatar_url text,
  email text,
  role text DEFAULT 'user'::text CHECK (role = ANY (ARRAY['user'::text, 'admin'::text])),
  subscription_tier text DEFAULT 'free'::text CHECK (subscription_tier = ANY (ARRAY['free'::text, 'premium'::text, 'pro'::text])),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  is_active boolean DEFAULT true
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Politiques pour users
CREATE POLICY "Users can read their own profile"
  ON users
  FOR SELECT
  TO authenticated
  USING ((auth.uid() = id) AND is_active = true);

CREATE POLICY "Users can insert their own profile"
  ON users
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON users
  FOR UPDATE
  TO authenticated
  USING ((auth.uid() = id) AND is_active = true)
  WITH CHECK ((auth.uid() = id) AND is_active = true);

CREATE POLICY "Admins can read all user data"
  ON users
  FOR SELECT
  TO authenticated
  USING ((auth.uid() = id) OR (COALESCE(((auth.jwt() -> 'user_metadata'::text) ->> 'role'::text), ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text)) = 'admin'::text));

-- Recréer la table trades
CREATE TABLE IF NOT EXISTS trades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  symbol text NOT NULL,
  entry numeric NOT NULL,
  exit numeric,
  stop_loss numeric,
  take_profit numeric,
  quantity numeric NOT NULL,
  side text NOT NULL CHECK (side = ANY (ARRAY['long'::text, 'short'::text])),
  status text DEFAULT 'open'::text CHECK (status = ANY (ARRAY['open'::text, 'closed'::text])),
  entry_date timestamptz DEFAULT now(),
  exit_date timestamptz,
  notes text,
  pnl numeric,
  fees numeric DEFAULT 0,
  exchange text,
  bot_generated boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE trades ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own trades"
  ON trades
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can read all trades via JWT"
  ON trades
  FOR SELECT
  TO authenticated
  USING (COALESCE(((auth.jwt() -> 'user_metadata'::text) ->> 'role'::text), ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text)) = 'admin'::text);

-- Recréer la table alerts
CREATE TABLE IF NOT EXISTS alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  symbol text NOT NULL,
  price numeric NOT NULL,
  condition text NOT NULL CHECK (condition = ANY (ARRAY['above'::text, 'below'::text])),
  message text NOT NULL,
  active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  triggered_at timestamptz
);

ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own alerts"
  ON alerts
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Recréer la table portfolios
CREATE TABLE IF NOT EXISTS portfolios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  balance numeric DEFAULT 10000,
  equity numeric DEFAULT 10000,
  daily_pnl numeric DEFAULT 0,
  total_pnl numeric DEFAULT 0,
  max_drawdown numeric DEFAULT 0,
  win_rate numeric DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE portfolios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own portfolio"
  ON portfolios
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own portfolio"
  ON portfolios
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own portfolio"
  ON portfolios
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Recréer la table exchange_keys
CREATE TABLE IF NOT EXISTS exchange_keys (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  exchange text NOT NULL,
  api_key text,
  api_secret text,
  PRIMARY KEY (user_id, exchange)
);

ALTER TABLE exchange_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read own exchange_keys"
  ON exchange_keys
  FOR SELECT
  TO public
  USING (auth.uid() = user_id);

CREATE POLICY "Allow insert own exchange_keys"
  ON exchange_keys
  FOR INSERT
  TO public
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow update own exchange_keys"
  ON exchange_keys
  FOR UPDATE
  TO public
  USING (auth.uid() = user_id);

CREATE POLICY "Allow delete own exchange_keys"
  ON exchange_keys
  FOR DELETE
  TO public
  USING (auth.uid() = user_id);

-- Recréer la table bot_configs
CREATE TABLE IF NOT EXISTS bot_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  strategy text NOT NULL,
  parameters jsonb DEFAULT '{}'::jsonb,
  active boolean DEFAULT false,
  exchange text NOT NULL,
  symbols text[] NOT NULL,
  risk_percentage numeric DEFAULT 2,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE bot_configs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own bot configs"
  ON bot_configs
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Recréer la table user_bot_credentials
CREATE TABLE IF NOT EXISTS user_bot_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  bot_username text NOT NULL UNIQUE,
  bot_password_hash text NOT NULL,
  bot_password_salt text NOT NULL,
  is_active boolean DEFAULT true,
  last_used_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

COMMENT ON TABLE user_bot_credentials IS 'Identifiants séparés pour les bots de trading - Mots de passe cryptés avec bcrypt';

-- Index pour user_bot_credentials
CREATE INDEX IF NOT EXISTS idx_user_bot_credentials_user_id ON user_bot_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_user_bot_credentials_username ON user_bot_credentials(bot_username);

ALTER TABLE user_bot_credentials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own bot credentials"
  ON user_bot_credentials
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own bot credentials"
  ON user_bot_credentials
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Recréer la table payment_methods
CREATE TABLE IF NOT EXISTS payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  method_type text NOT NULL CHECK (method_type = ANY (ARRAY['stripe'::text, 'paypal'::text, 'binance'::text, 'cb'::text, 'crypto'::text])),
  encrypted_data text,
  is_default boolean DEFAULT false,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

COMMENT ON TABLE payment_methods IS 'Méthodes de paiement avec chiffrement AES-256 - AUCUNE donnée sensible en clair';

-- Index pour payment_methods
CREATE INDEX IF NOT EXISTS idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_methods_type ON payment_methods(method_type);

ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own payment methods"
  ON payment_methods
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Recréer la table user_security_logs
CREATE TABLE IF NOT EXISTS user_security_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  action_type text NOT NULL,
  ip_address inet,
  user_agent text,
  success boolean DEFAULT true,
  details jsonb,
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE user_security_logs IS 'Logs de sécurité pour audit et surveillance';

-- Index pour user_security_logs
CREATE INDEX IF NOT EXISTS idx_security_logs_user_id ON user_security_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_security_logs_action ON user_security_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_security_logs_created_at ON user_security_logs(created_at);

ALTER TABLE user_security_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own security logs"
  ON user_security_logs
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert security logs"
  ON user_security_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Recréer les fonctions essentielles
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, display_name, avatar_url, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Utilisateur'),
    NEW.raw_user_meta_data->>'avatar_url',
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recréer le trigger pour les nouveaux utilisateurs
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Recréer la vue admin
CREATE OR REPLACE VIEW admin_user_overview AS
SELECT 
  u.id,
  u.display_name,
  u.email,
  u.role,
  u.subscription_tier,
  u.created_at,
  u.updated_at,
  ubc.bot_username,
  ubc.is_active as bot_active,
  ubc.last_used_at as bot_last_used,
  (SELECT COUNT(*) FROM payment_methods pm WHERE pm.user_id = u.id AND pm.is_active = true) as payment_methods_count,
  (SELECT COUNT(*) FROM user_security_logs usl WHERE usl.user_id = u.id) as security_logs_count
FROM users u
LEFT JOIN user_bot_credentials ubc ON u.id = ubc.user_id;