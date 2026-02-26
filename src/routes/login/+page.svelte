<script lang="ts">
    import { goto } from "$app/navigation";
    import { onMount } from "svelte";
    import { supabase } from "$lib/supabaseClient";
    import { openUrl } from "@tauri-apps/plugin-opener";
    import { onOpenUrl } from "@tauri-apps/plugin-deep-link";

    let email = "";
    let isSending = false;
    let message: string | null = null;
    let showOtpModal = false;
    let otpCode = "";
    let isVerifying = false;

    // Prevent double OAuth handling
    let oauthHandled = false;

    function goBack() {
        goto("/");
    }

    /* ---------------- EMAIL OTP ---------------- */

    async function openOtpModal() {
        message = null;

        if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
            message = "Моля въведете валиден имейл.";
            return;
        }

        isSending = true;

        try {
            const { error } = await supabase.auth.signInWithOtp({ email });
            if (error) throw error;

            showOtpModal = true;
            message = "Провете имейла си за кода и го въведете в полето.";
        } catch (e) {
            console.error("Error sending OTP:", e);
            message = "Грешка при изпращане. Моля опитайте отново.";
        } finally {
            isSending = false;
        }
    }

    function closeOtpModal() {
        showOtpModal = false;
        otpCode = "";
    }

    async function verifyOtp() {
        message = null;

        if (!otpCode) {
            message = "Моля въведете OTP кода.";
            return;
        }

        isVerifying = true;

        try {
            const { error } = await supabase.auth.verifyOtp({
                email,
                token: otpCode,
                type: "email",
            });

            if (error) throw error;

            closeOtpModal();
            goto("/");
        } catch (e) {
            console.error("Error verifying OTP:", e);
            message = "Грешка при верификация. Моля опитайте отново.";
        } finally {
            isVerifying = false;
        }
    }

    /* ---------------- GOOGLE OAUTH ---------------- */

    async function signInWithGoogle() {
        const { data, error } = await supabase.auth.signInWithOAuth({
            provider: "google",
            options: {
                redirectTo: "snacker://auth",
                skipBrowserRedirect: true,
            },
        });

        if (error) {
            console.error("Google sign in error:", error);
            return;
        }

        // Open system browser (required for Google)
        await openUrl(data.url);
    }

    /* ---------------- DEEP LINK HANDLER ---------------- */

    onMount(() => {
        const setup = async () => {
            const unlisten = await onOpenUrl(async (urls) => {
                if (oauthHandled) return;

                const url = urls[0];
                if (!url) return;

                try {
                    const parsed = new URL(url);
                    const code = parsed.searchParams.get("code");

                    if (!code) return;

                    oauthHandled = true;

                    const { error } = await supabase.auth.exchangeCodeForSession(code);

                    if (error) {
                        console.error("Session exchange failed:", error);
                        oauthHandled = false;
                        return;
                    }

                    // IMPORTANT: Navigate immediately
                    goto("/");
                } catch (err) {
                    console.error("Deep link handling error:", err);
                    oauthHandled = false;
                }
            });

            return unlisten;
        };

        let cleanup: any;

        setup().then((unlisten) => {
            cleanup = unlisten;
        });

        return () => {
            if (cleanup) cleanup();
        };
    });
</script>

<main class="container py-4">
    <button class="btn btn-sm btn-link mb-3" on:click={goBack} aria-label="Назад">
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="currentColor" viewBox="0 0 16 16" aria-hidden>
            <path
                fill-rule="evenodd"
                d="M11.354 1.646a.5.5 0 0 1 0 .708L5.707 8l5.647 5.646a.5.5 0 0 1-.708.708l-6-6a.5.5 0 0 1 0-.708l6-6a.5.5 0 0 1 .708 0z"
            />
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
            <button class="btn btn-primary" on:click={openOtpModal} disabled={isSending}>
                {#if isSending}<span class="spinner-border spinner-border-sm me-2"></span>Изпращам...{:else}Вход с имейл{/if}
            </button>
        </div>

        <div class="d-flex align-items-center mb-3">
            <hr class="flex-grow-1" />
            <small class="mx-2 text-muted">или</small>
            <hr class="flex-grow-1" />
        </div>

        <div>
            <button class="btn btn-outline-light" on:click={signInWithGoogle}>Вход с Google</button>
        </div>
    </div>
    {#if showOtpModal}
        <div class="modal-backdrop" style="position:fixed;inset:0;display:flex;align-items:center;justify-content:center;z-index:60;">
            <div class="card p-3" style="max-width:420px;width:100%;">
                <h3>Въведете OTP код</h3>
                <p class="text-muted">Въведете кода, изпратен на {email}</p>
                <div class="mb-3">
                    <input class="form-control" type="text" bind:value={otpCode} placeholder="Код" />
                </div>
                <div class="d-flex gap-2">
                    <button class="btn btn-primary" on:click={verifyOtp} disabled={isVerifying}>
                        {#if isVerifying}<span class="spinner-border spinner-border-sm me-2"></span>Проверка...{:else}Впиши се{/if}
                    </button>
                    <button class="btn btn-secondary" on:click={closeOtpModal} disabled={isVerifying}>Отказ</button>
                </div>
            </div>
        </div>
    {/if}
</main>
