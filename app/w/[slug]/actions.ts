"use server";

import { z } from "zod";
import { createClient } from "@/lib/supabase/server";

const purchaseSchema = z.object({
  purchasedByName: z
    .string()
    .trim()
    .min(1, "Le nom est obligatoire")
    .max(100, "100 caractères maximum"),
});

export type PurchaseActionState = { error: string | null; success: boolean };

export async function markAsPurchased(
  itemId: string,
  _prevState: PurchaseActionState,
  formData: FormData
): Promise<PurchaseActionState> {
  const parsed = purchaseSchema.safeParse({
    purchasedByName: formData.get("purchasedByName"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0].message, success: false };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("purchases").insert({
    item_id: itemId,
    purchased_by_name: parsed.data.purchasedByName,
  });

  if (error) {
    if (error.code === "23505") {
      return { error: "Cet item a déjà été marqué comme acheté.", success: false };
    }
    return { error: error.message, success: false };
  }

  return { error: null, success: true };
}
