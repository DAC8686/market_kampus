import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://wvmjshmpboquzyqwacxw.supabase.co";
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "sb_publishable_uBli1Mro0fw58WBCEeYv3A_gWv7zwop";

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
