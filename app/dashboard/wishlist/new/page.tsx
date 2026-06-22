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
    <main className="flex min-h-screen items-center justify-center bg-gray-50 px-4">
      <div className="w-full max-w-sm rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
        <div className="mb-6 flex items-center justify-between">
          <h1 className="text-lg font-semibold">Nouvelle wishlist</h1>
          <Link href="/dashboard" className="text-sm text-gray-500 underline">
            Annuler
          </Link>
        </div>
        <WishlistForm />
      </div>
    </main>
  );
}
