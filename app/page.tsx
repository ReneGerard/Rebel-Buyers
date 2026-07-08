import Link from "next/link";
import { getCurrentUser } from "@/lib/supabase/auth";

export default async function HomePage() {
  const user = await getCurrentUser();

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 px-4 text-center">
      <h1 className="text-2xl font-semibold">Rebel Buyers</h1>
      {user ? (
        <div className="flex flex-col items-center gap-3">
          <p className="text-gray-600">Connecté en tant que {user.email}</p>
          <Link href="/dashboard" className="rounded-md bg-gray-900 px-4 py-2 text-sm font-medium text-white">
            Mon dashboard
          </Link>
        </div>
      ) : (
        <Link href="/login" className="text-sm font-medium text-gray-900 underline">
          Se connecter
        </Link>
      )}
    </main>
  );
}
