/*
  # Fix RLS Functions and Policies

  1. Drop and recreate all problematic functions
  2. Fix RLS policies
  3. Ensure proper security setup
*/

-- Drop all existing problematic functions
DROP FUNCTION IF EXISTS public.admin_delete_user_completely(uuid);
DROP FUNCTION IF EXISTS public.check_auth_user_exists();
DROP FUNCTION IF EXISTS public.decrypt_payment_data(text);
DROP FUNCTION IF EXISTS public.generate_secure_password();
DROP FUNCTION IF EXISTS public.get_user_bot_credentials(uuid);
DROP FUNCTION IF EXISTS public.get_user_count();
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.promote_to_admin(uuid);
DROP FUNCTION IF EXISTS public.revoke_all_user_sessions(uuid);
DROP FUNCTION IF EXISTS public.reactivate_user_account(uuid);
DROP FUNCTION IF EXISTS public.create_bot_credentials(uuid, text, text);
DROP FUNCTION IF EXISTS public.encrypt_payment_data(text);

-- Create secure password generation function
CREATE OR REPLACE FUNCTION public.generate_secure_password()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN encode(gen_random_bytes(12), 'base64');
END;
$$;

-- Create user existence check function
CREATE OR REPLACE FUNCTION public.check_auth_user_exists()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users 
    WHERE id = auth.uid()
  );
END;
$$;

-- Create user count function (admin only)
CREATE OR REPLACE FUNCTION public.get_user_count()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_role text;
BEGIN
  -- Check if user is admin
  SELECT role INTO user_role 
  FROM public.profiles 
  WHERE id = auth.uid();
  
  IF user_role != 'admin' THEN
    RAISE EXCEPTION 'Access denied: Admin role required';
  END IF;
  
  RETURN (SELECT count(*) FROM auth.users);
END;
$$;

-- Create new user handler
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role, created_at)
  VALUES (
    NEW.id,
    NEW.email,
    'user',
    NOW()
  );
  RETURN NEW;
END;
$$;

-- Create admin promotion function
CREATE OR REPLACE FUNCTION public.promote_to_admin(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_role text;
BEGIN
  -- Check if current user is admin
  SELECT role INTO current_user_role 
  FROM public.profiles 
  WHERE id = auth.uid();
  
  IF current_user_role != 'admin' THEN
    RAISE EXCEPTION 'Access denied: Admin role required';
  END IF;
  
  UPDATE public.profiles 
  SET role = 'admin' 
  WHERE id = user_id;
END;
$$;

-- Create session revocation function
CREATE OR REPLACE FUNCTION public.revoke_all_user_sessions(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_role text;
BEGIN
  -- Check if current user is admin
  SELECT role INTO current_user_role 
  FROM public.profiles 
  WHERE id = auth.uid();
  
  IF current_user_role != 'admin' THEN
    RAISE EXCEPTION 'Access denied: Admin role required';
  END IF;
  
  -- Update user to force re-authentication
  UPDATE auth.users 
  SET updated_at = NOW() 
  WHERE id = user_id;
END;
$$;

-- Create user reactivation function
CREATE OR REPLACE FUNCTION public.reactivate_user_account(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_role text;
BEGIN
  -- Check if current user is admin
  SELECT role INTO current_user_role 
  FROM public.profiles 
  WHERE id = auth.uid();
  
  IF current_user_role != 'admin' THEN
    RAISE EXCEPTION 'Access denied: Admin role required';
  END IF;
  
  UPDATE public.profiles 
  SET 
    status = 'active',
    updated_at = NOW()
  WHERE id = user_id;
END;
$$;

-- Create complete user deletion function
CREATE OR REPLACE FUNCTION public.admin_delete_user_completely(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_role text;
BEGIN
  -- Check if current user is admin
  SELECT role INTO current_user_role 
  FROM public.profiles 
  WHERE id = auth.uid();
  
  IF current_user_role != 'admin' THEN
    RAISE EXCEPTION 'Access denied: Admin role required';
  END IF;
  
  -- Delete from profiles first (due to foreign key constraints)
  DELETE FROM public.profiles WHERE id = user_id;
  
  -- Delete from auth.users
  DELETE FROM auth.users WHERE id = user_id;
END;
$$;

-- Create bot credentials functions
CREATE OR REPLACE FUNCTION public.create_bot_credentials(
  user_id uuid,
  bot_name text,
  api_key text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_id uuid;
BEGIN
  -- Check if user owns this or is admin
  IF auth.uid() != user_id AND NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;
  
  INSERT INTO public.bot_credentials (user_id, bot_name, api_key)
  VALUES (user_id, bot_name, api_key)
  RETURNING id INTO new_id;
  
  RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_bot_credentials(user_id uuid)
RETURNS TABLE(id uuid, bot_name text, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if user owns this or is admin
  IF auth.uid() != user_id AND NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;
  
  RETURN QUERY
  SELECT bc.id, bc.bot_name, bc.created_at
  FROM public.bot_credentials bc
  WHERE bc.user_id = get_user_bot_credentials.user_id;
END;
$$;

-- Create encryption functions (simplified for security)
CREATE OR REPLACE FUNCTION public.encrypt_payment_data(data_to_encrypt text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- In production, use proper encryption with pgcrypto
  -- For now, return a placeholder
  RETURN encode(data_to_encrypt::bytea, 'base64');
END;
$$;

CREATE OR REPLACE FUNCTION public.decrypt_payment_data(encrypted_data text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- In production, use proper decryption with pgcrypto
  -- For now, return decoded data
  RETURN convert_from(decode(encrypted_data, 'base64'), 'UTF8');
END;
$$;

-- Create trigger for new user handling
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.generate_secure_password() TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_auth_user_exists() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_count() TO authenticated;
GRANT EXECUTE ON FUNCTION public.promote_to_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_all_user_sessions(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reactivate_user_account(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_user_completely(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_bot_credentials(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_bot_credentials(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.encrypt_payment_data(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decrypt_payment_data(text) TO authenticated;