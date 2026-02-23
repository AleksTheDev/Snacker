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

    const PHONE_LENGTH = 10;

    async function submitProfile() {
        errorMessage = null;
        const trimmedName = name.trim();
        const trimmedPhone = phone.trim();
        const trimmedLocation = location.trim();

        if (!trimmedName || !trimmedPhone || !trimmedLocation) {
            errorMessage = "Моля попълнете всички задължителни полета.";
            return;
        }

        if (!/^\d+$/.test(trimmedPhone) || trimmedPhone.length !== PHONE_LENGTH) {
            errorMessage = `Моля въведете телефонен номер, съдържащ точно ${PHONE_LENGTH} цифри`;
            return;
        }

        const user = (get(session) as any)?.user;
        if (!user) {
            goto("/login");
            return;
        }

        isSubmitting = true;
        try {
            const payload = {
                user_id: user.id,
                name: trimmedName,
                location: trimmedLocation,
                phone_number: trimmedPhone
            };

            const { data, error } = await supabase.from("profile").insert(payload).select().single();
            if (error) throw error;

            // success -> go home
            goto("/");
        } catch (e) {
            console.error("Error creating profile:", e);
            errorMessage = "Грешка при запис. Моля опитайте отново.";
        } finally {
            isSubmitting = false;
        }
    }

    onMount(async () => {
        // ensure user exists
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
            const { data: profile, error } = await supabase.from("profile").select("id").eq("user_id", user.id).maybeSingle();
            if (error) console.error("Profile lookup error:", error);
            if (profile) {
                // profile exists -> redirect home
                goto("/");
            }
        } catch (e) {
            console.error("Unexpected error while checking profile:", e);
        }
    });
</script>

<main class="register-container">
    <div class="card register-card">
        <h2 class="register-header">Регистрация на профил</h2>

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
            <button class="btn btn-primary" on:click={submitProfile} disabled={isSubmitting}>
                {#if isSubmitting}
                    <span class="spinner-border spinner-border-sm me-2" role="status"></span>Записвам...
                {:else}
                    Създай профил
                {/if}
            </button>
        </div>
    </div>
</main>
