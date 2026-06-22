import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/supabase/auth";

export default async function WishlistDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/login");
  }

  const { id } = await params;

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-2 px-4 text-center">
      <h1 className="text-xl font-semibold">À venir</h1>
      <p className="text-sm text-gray-500">Wishlist #{id}</p>
    </main>
  );
}
