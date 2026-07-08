import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/supabase/auth";
import { WishlistForm } from "./wishlist-form";

export default async function NewWishlistPage() {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/login");
  }

  return (
    <main className="flex min-h-[calc(100dvh-3.5rem)] items-center justify-center px-4 py-12">
      <div className="card w-full max-w-sm p-8">
        <div className="mb-6 flex items-center justify-between">
          <h1 className="font-display text-2xl font-bold text-warm-900">Nouvelle wishlist</h1>
          <Link href="/dashboard" className="btn-ghost">
            Annuler
          </Link>
        </div>
        <WishlistForm />
      </div>
    </main>
  );
}
