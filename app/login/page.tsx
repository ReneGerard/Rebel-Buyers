"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { z } from "zod";
import { createClient } from "@/lib/supabase/client";

const credentialsSchema = z.object({
  email: z.string().email("Adresse email invalide"),
  password: z.string().min(6, "6 caractères minimum"),
});

type Mode = "login" | "signup";

export default function LoginPage() {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setInfo(null);

    const parsed = credentialsSchema.safeParse({ email, password });
    if (!parsed.success) {
      setError(parsed.error.issues[0].message);
      return;
    }

    setIsSubmitting(true);
    const supabase = createClient();

    if (mode === "login") {
      const { error: signInError } = await supabase.auth.signInWithPassword(
        parsed.data
      );
      setIsSubmitting(false);
      if (signInError) {
        setError(signInError.message);
        return;
      }
      router.push("/");
      router.refresh();
      return;
    }

    const { data, error: signUpError } = await supabase.auth.signUp(parsed.data);
    setIsSubmitting(false);
    if (signUpError) {
      setError(signUpError.message);
      return;
    }
    if (data.session) {
      router.push("/");
      router.refresh();
      return;
    }
    setInfo("Compte créé. Vérifie ta boîte mail pour confirmer ton adresse.");
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-gray-50 px-4">
      <div className="w-full max-w-sm rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
        <div className="mb-6 flex gap-2">
          <button
            type="button"
            onClick={() => setMode("login")}
            className={`flex-1 rounded-md px-3 py-2 text-sm font-medium ${
              mode === "login" ? "bg-gray-900 text-white" : "bg-gray-100 text-gray-600"
            }`}
          >
            Connexion
          </button>
          <button
            type="button"
            onClick={() => setMode("signup")}
            className={`flex-1 rounded-md px-3 py-2 text-sm font-medium ${
              mode === "signup" ? "bg-gray-900 text-white" : "bg-gray-100 text-gray-600"
            }`}
          >
            Inscription
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="email" className="mb-1 block text-sm font-medium text-gray-700">
              Email
            </label>
            <input
              id="email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
            />
          </div>

          <div>
            <label htmlFor="password" className="mb-1 block text-sm font-medium text-gray-700">
              Mot de passe
            </label>
            <input
              id="password"
              type="password"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
            />
          </div>

          {error && <p className="text-sm text-red-600">{error}</p>}
          {info && <p className="text-sm text-green-600">{info}</p>}

          <button
            type="submit"
            disabled={isSubmitting}
            className="w-full rounded-md bg-gray-900 px-3 py-2 text-sm font-medium text-white disabled:opacity-50"
          >
            {isSubmitting ? "..." : mode === "login" ? "Se connecter" : "Créer un compte"}
          </button>
        </form>
      </div>
    </main>
  );
}
