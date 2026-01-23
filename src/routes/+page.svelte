<script lang="ts">
    import { session } from "$lib/session";
    import { supabase } from "$lib/supabaseClient";
    import AddOfferModal from "$lib/AddOfferModal.svelte";

    async function signInWithGithub() {
        const { data, error } = await supabase.auth.signInWithOAuth({
            provider: "github",
            options: {
                redirectTo: `${window.location.origin}`,
            },
        });
        if (error) {
            console.error("Error signing in:", error);
        }
    }
</script>

{#if !$session}
    <main class="d-flex align-items-center justify-content-center min-vh-100">
        <div class="text-center">
            <h1 class="display-3 fw-bold mb-4">Снакър</h1>
            <button class="btn btn-dark btn-lg" onclick={signInWithGithub}> Влез с Гоогле </button>
        </div>
    </main>
{:else}
    <main class="d-flex flex-column min-vh-100">
        <div class="flex-grow-1 d-flex align-items-center justify-content-center p-4">
            <!-- Landing page content goes here -->
        </div>
        <footer class="border-top py-4">
            <div class="text-center">
                <AddOfferModal />
            </div>
        </footer>
    </main>
{/if}
