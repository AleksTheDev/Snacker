<script lang="ts">
    import { onMount } from "svelte";
    import { supabase } from "$lib/supabaseClient";
    import { session } from "$lib/session";
    import { goto } from "$app/navigation";
    import { get } from "svelte/store";

    let name = "";
    let phone = "";
    let location = "";
    let isSubmitting = false;
    let errorMessage: string | null = null;
    let profileId: number | null = null;
    const PHONE_LENGTH = 10;

    onMount(async () => {
        let user = (get(session) as any)?.user;
        if (!user) {
            try {
                const { data } = await supabase.auth.getSession();
                user = (data as any)?.session?.user || null;
            } catch (e) {
                user = null;
            }
        }

        if (!user) {
            goto("/login");
            return;
        }

        try {
            const { data: profile, error } = await supabase.from("profile").select("*").eq("user_id", user.id).maybeSingle();
            if (error) console.error("Profile lookup error:", error);
            if (!profile) {
                goto("/register");
                return;
            }
            profileId = profile.id;
            name = profile.name || "";
            phone = profile.phone_number || "";
            location = profile.location || "";
        } catch (e) {
            console.error("Unexpected error while loading profile:", e);
            errorMessage = "Грешка при зареждане на профила.";
        }
    });

    async function submitUpdate() {
        errorMessage = null;
        const tn = name.trim();
        const tp = phone.trim();
        const tl = location.trim();

        if (!tn || !tp || !tl) {
            errorMessage = "Моля попълнете всички задължителни полета.";
            return;
        }

        if (!/^\d+$/.test(tp) || tp.length !== PHONE_LENGTH) {
            errorMessage = `Моля въведете телефонен номер, съдържащ точно ${PHONE_LENGTH} цифри`;
            return;
        }

        if (!profileId) {
            errorMessage = "Невалиден профил.";
            return;
        }

        isSubmitting = true;
        try {
            const payload = { name: tn, phone_number: tp, location: tl };
            const { data, error } = await supabase.from("profile").update(payload).eq("id", profileId).select().single();
            if (error) throw error;
            goto("/");
        } catch (e) {
            console.error("Error updating profile:", e);
            errorMessage = "Грешка при запис. Моля опитайте отново.";
        } finally {
            isSubmitting = false;
        }
    }
</script>

<main class="register-container">
    <div class="card register-card">
        <h2 class="register-header">Редакция на профил</h2>

        {#if errorMessage}
            <div class="mb-3">
                <div class="error-text">{errorMessage}</div>
            </div>
        {/if}

        <div class="mb-3">
            <label class="form-label input-required">Име</label>
            <input class="form-control" bind:value={name} placeholder="Вашето име" maxlength={150} />
        </div>

        <div class="mb-3">
            <label class="form-label input-required">Телефон (само цифри)</label>
            <input
                class="form-control"
                bind:value={phone}
                maxlength={PHONE_LENGTH}
                inputmode="numeric"
                on:input={(e) => (phone = (e.target as HTMLInputElement).value.replace(/\D/g, "").slice(0, PHONE_LENGTH))}
                placeholder="0881234567"
            />
        </div>

        <div class="mb-3">
            <label class="form-label input-required">Локация (град или квартал)</label>
            <input class="form-control" bind:value={location} maxlength={150} placeholder="София, Център" />
        </div>

        <div class="form-actions">
            <button class="btn btn-secondary" on:click={() => goto("/")} disabled={isSubmitting}>Отказ</button>
            <button class="btn btn-primary" on:click={submitUpdate} disabled={isSubmitting}>
                {#if isSubmitting}
                    <span class="spinner-border spinner-border-sm me-2" role="status"></span>Записвам...
                {:else}
                    Запази промените
                {/if}
            </button>
        </div>
    </div>
</main>
