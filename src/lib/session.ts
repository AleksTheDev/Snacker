import { writable } from "svelte/store";
import { supabase } from "./supabaseClient";
import type { Session } from "@supabase/supabase-js";

export const session = writable<Session | null>(null);

// Initial load
supabase.auth.getSession().then(({ data }) => {
    session.set(data.session);
});

// Listen for changes
supabase.auth.onAuthStateChange((_event, newSession) => {
    session.set(newSession);
});
