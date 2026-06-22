"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { getCurrentUser } from "@/lib/supabase/auth";
import { createClient } from "@/lib/supabase/server";

const wishlistSchema = z.object({
  title: z.string().trim().min(1, "Le titre est obligatoire").max(120, "120 caractères maximum"),
  description: z.string().trim().max(500, "500 caractères maximum").optional(),
});

export type CreateWishlistState = { error: string | null };

export async function createWishlist(
  _prevState: CreateWishlistState,
  formData: FormData
): Promise<CreateWishlistState> {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/login");
  }

  const parsed = wishlistSchema.safeParse({
    title: formData.get("title"),
    description: formData.get("description") || undefined,
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0].message };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("wishlists").insert({
    owner_id: user.id,
    title: parsed.data.title,
    description: parsed.data.description ?? null,
  });

  if (error) {
    return { error: error.message };
  }

  redirect("/dashboard");
}
