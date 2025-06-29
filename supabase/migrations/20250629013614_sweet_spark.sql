/*
  # Fix RLS Policies

  1. Drop existing problematic policies
  2. Create new secure policies
  3. Ensure proper access control
*/

-- Fix profiles table policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can delete profiles" ON public.profiles;

-- Create new profiles policies
CREATE POLICY "Users can view own profile"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Admins can update all profiles"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete profiles"
  ON public.profiles
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Fix bot_credentials table policies if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bot_credentials') THEN
    DROP POLICY IF EXISTS "Users can manage own bot credentials" ON public.bot_credentials;
    DROP POLICY IF EXISTS "Admins can view all bot credentials" ON public.bot_credentials;
    
    CREATE POLICY "Users can manage own bot credentials"
      ON public.bot_credentials
      FOR ALL
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
    
    CREATE POLICY "Admins can view all bot credentials"
      ON public.bot_credentials
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = 'admin'
        )
      );
  END IF;
END $$;

-- Fix user_security_logs table policies if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_security_logs') THEN
    DROP POLICY IF EXISTS "Users can view own security logs" ON public.user_security_logs;
    DROP POLICY IF EXISTS "Admins can view all security logs" ON public.user_security_logs;
    
    CREATE POLICY "Users can view own security logs"
      ON public.user_security_logs
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
    
    CREATE POLICY "Admins can view all security logs"
      ON public.user_security_logs
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = 'admin'
        )
      );
    
    CREATE POLICY "System can insert security logs"
      ON public.user_security_logs
      FOR INSERT
      TO authenticated
      WITH CHECK (true);
  END IF;
END $$;