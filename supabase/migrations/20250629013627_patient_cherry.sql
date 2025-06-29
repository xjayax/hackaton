/*
  # Ensure Required Tables Exist

  1. Create profiles table if missing
  2. Create bot_credentials table if missing
  3. Create user_security_logs table if missing
*/

-- Create profiles table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  role text DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  status text DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create bot_credentials table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.bot_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  bot_name text NOT NULL,
  api_key text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create user_security_logs table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_security_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  action text NOT NULL,
  details jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_security_logs ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(status);
CREATE INDEX IF NOT EXISTS idx_bot_credentials_user_id ON public.bot_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_user_security_logs_user_id ON public.user_security_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_security_logs_created_at ON public.user_security_logs(created_at);