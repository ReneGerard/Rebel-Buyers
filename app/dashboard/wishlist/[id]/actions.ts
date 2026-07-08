"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { getCurrentUser } from "@/lib/supabase/auth";
import { createClient } from "@/lib/supabase/server";

export type LinkMetadata = {
  title?: string;
  imageUrl?: string;
  price?: string;
};

export async function fetchLinkMetadata(rawUrl: string): Promise<LinkMetadata | null> {
  try {
    const url = new URL(rawUrl);
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 5000);

    let res: Response;
    try {
      res = await fetch(url.toString(), {
        signal: controller.signal,
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; RebelBuyers/1.0)",
          Accept: "text/html,application/xhtml+xml",
        },
      });
    } finally {
      clearTimeout(timer);
    }

    if (!res.ok) return null;

    const reader = res.body?.getReader();
    if (!reader) return null;

    const decoder = new TextDecoder();
    let html = "";
    while (html.length < 50_000) {
      const { done, value } = await reader.read();
      if (done) break;
      html += decoder.decode(value, { stream: true });
      if (html.includes("</head>")) break;
    }
    reader.cancel().catch(() => {});

    return parseMeta(html);
  } catch (err) {
    console.error("[fetchLinkMetadata]", err instanceof Error ? err.message : String(err));
    return null;
  }
}

function truncateAtWord(raw: string, max: number): string {
  if (raw.length <= max) return raw;
  const cut = raw.slice(0, max).replace(/\s+\S*$/, "");
  return (cut || raw.slice(0, max)) + "…";
}

function parseMeta(html: string): LinkMetadata {
  const head = html.match(/<head[\s\S]*?<\/head>/i)?.[0] ?? html.slice(0, 50_000);
  const tags: Record<string, string> = {};
  const metaRe = /<meta\s+([^>]+?)\/?>/gi;
  let m: RegExpExecArray | null;
  while ((m = metaRe.exec(head)) !== null) {
    const attrs = m[1];
    const key = /(?:property|name)=["']([^"']+)["']/i.exec(attrs)?.[1]?.toLowerCase();
    const content = /content=["']([^"']*)["']/i.exec(attrs)?.[1];
    if (key && content !== undefined) tags[key] = content;
  }
  const rawPrice = tags["og:price:amount"] ?? tags["product:price:amount"] ?? tags["og:price"];
  const priceMatch = rawPrice?.match(/\d+(?:[.,]\d+)?/);
  const rawTitle = tags["og:title"];
  return {
    title: rawTitle ? truncateAtWord(rawTitle, 80) : undefined,
    imageUrl: tags["og:image"] || undefined,
    price: priceMatch ? priceMatch[0].replace(",", ".") : undefined,
  };
}

const itemSchema = z.object({
  title: z.string().trim().min(1, "Le titre est obligatoire").max(120, "120 caractères maximum"),
  merchantUrl: z.string().trim().url("URL invalide").optional(),
  price: z.coerce.number().positive("Le prix doit être positif").optional(),
  imageUrl: z.string().trim().url("URL d'image invalide").optional(),
  note: z.string().trim().max(500, "500 caractères maximum").optional(),
});

export type ItemActionState = { error: string | null; success: boolean };

function emptyToUndefined(value: FormDataEntryValue | null) {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed === "" ? undefined : trimmed;
}

function parseItemForm(formData: FormData) {
  return itemSchema.safeParse({
    title: formData.get("title"),
    merchantUrl: emptyToUndefined(formData.get("merchantUrl")),
    price: emptyToUndefined(formData.get("price")),
    imageUrl: emptyToUndefined(formData.get("imageUrl")),
    note: emptyToUndefined(formData.get("note")),
  });
}

async function assertOwnsWishlist(wishlistId: string, ownerId: string) {
  const supabase = await createClient();
  const { data } = await supabase
    .from("wishlists")
    .select("id")
    .eq("id", wishlistId)
    .eq("owner_id", ownerId)
    .maybeSingle();
  return Boolean(data);
}

export async function createItem(
  wishlistId: string,
  _prevState: ItemActionState,
  formData: FormData
): Promise<ItemActionState> {
  const user = await getCurrentUser();
  if (!user) {
    return { error: "Tu dois être connecté.", success: false };
  }

  if (!(await assertOwnsWishlist(wishlistId, user.id))) {
    return { error: "Wishlist introuvable.", success: false };
  }

  const parsed = parseItemForm(formData);
  if (!parsed.success) {
    return { error: parsed.error.issues[0].message, success: false };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("items").insert({
    wishlist_id: wishlistId,
    title: parsed.data.title,
    merchant_url: parsed.data.merchantUrl ?? null,
    price: parsed.data.price ?? null,
    image_url: parsed.data.imageUrl ?? null,
    note: parsed.data.note ?? null,
  });

  if (error) {
    return { error: error.message, success: false };
  }

  revalidatePath(`/dashboard/wishlist/${wishlistId}`);
  return { error: null, success: true };
}

export async function updateItem(
  wishlistId: string,
  itemId: string,
  _prevState: ItemActionState,
  formData: FormData
): Promise<ItemActionState> {
  const user = await getCurrentUser();
  if (!user) {
    return { error: "Tu dois être connecté.", success: false };
  }

  if (!(await assertOwnsWishlist(wishlistId, user.id))) {
    return { error: "Wishlist introuvable.", success: false };
  }

  const parsed = parseItemForm(formData);
  if (!parsed.success) {
    return { error: parsed.error.issues[0].message, success: false };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("items")
    .update({
      title: parsed.data.title,
      merchant_url: parsed.data.merchantUrl ?? null,
      price: parsed.data.price ?? null,
      image_url: parsed.data.imageUrl ?? null,
      note: parsed.data.note ?? null,
    })
    .eq("id", itemId)
    .eq("wishlist_id", wishlistId);

  if (error) {
    return { error: error.message, success: false };
  }

  revalidatePath(`/dashboard/wishlist/${wishlistId}`);
  return { error: null, success: true };
}

export async function deleteItem(
  wishlistId: string,
  itemId: string,
  _prevState: ItemActionState,
  _formData: FormData
): Promise<ItemActionState> {
  const user = await getCurrentUser();
  if (!user) {
    return { error: "Tu dois être connecté.", success: false };
  }

  if (!(await assertOwnsWishlist(wishlistId, user.id))) {
    return { error: "Wishlist introuvable.", success: false };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("items")
    .delete()
    .eq("id", itemId)
    .eq("wishlist_id", wishlistId);

  if (error) {
    return { error: error.message, success: false };
  }

  revalidatePath(`/dashboard/wishlist/${wishlistId}`);
  return { error: null, success: true };
}
