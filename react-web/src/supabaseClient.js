import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://nbbvcufhptrnaiicnfmx.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5iYnZjdWZocHRybmFpaWNuZm14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwOTkyMDcsImV4cCI6MjA5NzY3NTIwN30.rh1XlyAy2T_jNKUzHMQiftL7ehC6Yzr065vCHHQxkgk';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
