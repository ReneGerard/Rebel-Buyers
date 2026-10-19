"use server";

import { z } from "zod";
import { createClient } from "@/lib/supabase/server";

const purchaseSchema = z.object({
  itemId: z.string().uuid("Item invalide"),
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
    itemId,
    purchasedByName: formData.get("purchasedByName"),
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0].message, success: false };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("reserve_item", {
    p_item_id: parsed.data.itemId,
    p_buyer_name: parsed.data.purchasedByName,
  });

  if (error) {
    if (error.code === "23505") {
      return { error: "Cet item a déjà été marqué comme acheté.", success: false };
    }
    // Every other failure (creator, unknown item, ...) gets the same message on purpose.
    return { error: "Impossible de réserver cet item.", success: false };
  }

  return { error: null, success: true };
}
