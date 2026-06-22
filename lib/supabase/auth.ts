import type { User } from "@supabase/supabase-js";
import { createClient } from "./server";

export async function getCurrentUser(): Promise<User | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getUser();

  if (error) {
    return null;
  }

  return data.user;
}
