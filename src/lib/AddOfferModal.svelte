<script lang="ts">
    import { goto } from "$app/navigation";
    import { session } from "$lib/session";
    import { supabase } from "$lib/supabaseClient";
    import { onMount } from "svelte";

    let hasProfile = false;

    onMount(() => {
        async function checkProfile() {
            if (!$session) {
                hasProfile = false;
                return;
            }

            const { data: profileData, error: profileError } = await supabase.from("profile").select("*").eq("user_id", $session.user.id).single();
            if (profileError) {
                console.error("Error checking profile:", profileError);
            } else {
                hasProfile = !!profileData; // Set hasProfile based on whether profile exists
            }
        }

        checkProfile();
    });

    function handleClick() {
        if ($session) {
            if (!hasProfile) {
                goto("/register");
            } else {
                goto("/offer/new");
            }
        } else {
            goto("/login");
        }
    }
</script>

<!-- Floating add button that navigates to /offer/new -->
<button class="btn btn-primary rounded-circle p-0 add-offer-btn" on:click={handleClick} aria-label="Добави обява">
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 16 16" aria-hidden>
        <path d="M8 4a.5.5 0 0 1 .5.5V7.5H11.5a.5.5 0 0 1 0 1H8.5V11.5a.5.5 0 0 1-1 0V8.5H4.5a.5.5 0 0 1 0-1H7.5V4.5A.5.5 0 0 1 8 4z" />
    </svg>
</button>
