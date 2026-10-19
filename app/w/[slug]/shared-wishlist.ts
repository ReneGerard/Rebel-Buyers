import { z } from "zod";

// Shape returned by the get_shared_wishlist() database function. `taken` is null for the creator.
const sharedItemSchema = z.object({
  id: z.string(),
  title: z.string(),
  merchant_url: z.string().nullable(),
  price: z.number().nullable(),
  image_url: z.string().nullable(),
  note: z.string().nullable(),
  created_at: z.string(),
  taken: z.boolean().nullable(),
});

export const sharedWishlistSchema = z.object({
  id: z.string(),
  title: z.string(),
  description: z.string().nullable(),
  is_owner: z.boolean(),
  items: z.array(sharedItemSchema),
});

export type SharedWishlist = z.infer<typeof sharedWishlistSchema>;
export type SharedItem = z.infer<typeof sharedItemSchema>;
