<script lang="ts">
    import { goto } from "$app/navigation";
    import { supabase } from "$lib/supabaseClient";

    let email = "";
    let isSending = false;
    let message: string | null = null;

    function goBack() {
        goto("/");
    }

    async function sendMagicLink() {
        message = null;
        if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
            message = "Моля въведете валиден имейл.";
            return;
        }
        isSending = true;
        try {
            const { error } = await supabase.auth.signInWithOtp({ email });
            if (error) throw error;
            message = "Проверете пощата си за линк за влизане.";
        } catch (e) {
            console.error("Error sending magic link:", e);
            message = "Грешка при изпращане. Моля опитайте отново.";
        } finally {
            isSending = false;
        }
    }

    async function signInWithGoogle() {
        const { error } = await supabase.auth.signInWithOAuth({ provider: "google", options: { redirectTo: `${window.location.origin}` } });
        if (error) console.error("Error signing in:", error);
    }
</script>

<main class="container py-4">
    <button class="btn btn-sm btn-link mb-3" on:click={goBack} aria-label="Назад">
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="currentColor" viewBox="0 0 16 16" aria-hidden>
            <path fill-rule="evenodd" d="M11.354 1.646a.5.5 0 0 1 0 .708L5.707 8l5.647 5.646a.5.5 0 0 1-.708.708l-6-6a.5.5 0 0 1 0-.708l6-6a.5.5 0 0 1 .708 0z"/>
        </svg>
    </button>

    <div class="card register-card mx-auto" style="max-width:520px;">
        <h2 class="register-header">Вход</h2>

        {#if message}
            <div class="mb-3"><div class="text-muted">{message}</div></div>
        {/if}

        <div class="mb-3">
            <label class="form-label">Имейл</label>
            <input class="form-control" type="email" bind:value={email} placeholder="you@example.com" />
        </div>

        <div class="d-flex gap-2 mb-3">
            <button class="btn btn-primary" on:click={sendMagicLink} disabled={isSending}>
                {#if isSending}<span class="spinner-border spinner-border-sm me-2"></span>Изпращам...{:else}Вход с имейл{/if}
            </button>
        </div>

        <div class="d-flex align-items-center mb-3"><hr class="flex-grow-1" /><small class="mx-2 text-muted">или</small><hr class="flex-grow-1" /></div>

        <div>
            <button class="btn btn-outline-light" on:click={signInWithGoogle}>Вход с Google</button>
        </div>
    </div>
</main>
