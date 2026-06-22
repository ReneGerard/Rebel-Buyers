import Link from "next/link";
import { getCurrentUser } from "@/lib/supabase/auth";

export default async function HomePage() {
  const user = await getCurrentUser();

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 px-4 text-center">
      <h1 className="text-2xl font-semibold">Rebel Buyers</h1>
      {user ? (
        <p className="text-gray-600">Connecté en tant que {user.email}</p>
      ) : (
        <Link href="/login" className="text-sm font-medium text-gray-900 underline">
          Se connecter
        </Link>
      )}
    </main>
  );
}
