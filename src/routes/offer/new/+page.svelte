<script lang="ts">
    import { onMount } from "svelte";
    import { supabase } from "$lib/supabaseClient";
    import { session } from "$lib/session";
    import { goto } from "$app/navigation";

    let title = "";
    let description = "";
    let price: string = "";
    let isFree: boolean = false;
    let profile: any = null;
    let selectedFiles: File[] = [];
    let isLoading = false;
    let fileInputElement: HTMLInputElement;

    interface FileWithIndex {
        file: File;
        index: number;
    }

    function handleFileSelect(event: Event) {
        const input = event.target as HTMLInputElement;
        if (input.files) {
            selectedFiles = [...selectedFiles, ...Array.from(input.files)];
            input.value = "";
        }
    }

    function removeFile(index: number) {
        selectedFiles = selectedFiles.filter((_, i) => i !== index);
    }

    async function uploadImages(offerId: any, userId: string) {
        const filesWithIndex: FileWithIndex[] = selectedFiles.map((file, idx) => ({ file, index: idx + 1 }));
        for (const { file, index } of filesWithIndex) {
            const mime = file.type || "image/jpeg";
            const ext = mime.split("/").pop() || "jpg";
            const filename = `${crypto.randomUUID()}.${ext}`;
            const storagePath = `${userId}/offer${offerId}/${filename}`;
            const { error: uploadError } = await supabase.storage
                .from("images")
                .upload(storagePath, file, { cacheControl: "3600", upsert: false, contentType: mime } as any);
            if (uploadError) throw uploadError;

            let publicUrl: string | null = null;
            try {
                const { data } = supabase.storage.from("images").getPublicUrl(storagePath);
                publicUrl = (data as any)?.publicUrl || null;
            } catch (e) {}
            if (!publicUrl) {
                try {
                    const { data: sd, error: se } = await supabase.storage.from("images").createSignedUrl(storagePath, 60 * 60 * 24);
                    if (!se && sd?.signedUrl) publicUrl = sd.signedUrl;
                } catch (e) {}
            }
            if (!publicUrl) throw new Error("Could not obtain URL for uploaded image");
            const { error: insertError } = await supabase.from("image").insert({ offer_id: offerId, index, url: publicUrl });
            if (insertError) throw insertError;
        }
    }

    async function handleSubmit() {
        if (!title.trim() || !description.trim()) {
            alert("Моля попълнете всички полета");
            return;
        }
        const user = $session?.user;
        if (!user) {
            alert("Трябва да сте логнати");
            return;
        }
        isLoading = true;
        try {
            // Ensure we have the user's profile (fetched on mount or fetch now)
            let prof = profile;
            if (!prof) {
                const { data: p, error: profileError } = await supabase.from("profile").select("id").eq("user_id", user.id).maybeSingle();
                if (profileError) throw profileError;
                if (!p) {
                    alert("Няма регистриран профил. Моля първо създайте профил.");
                    goto("/register");
                    return;
                }
                prof = p;
            }

            // validate price
            let priceValue = 0;
            if (!isFree) {
                if (!price || isNaN(Number(price)) || Number(price) < 0) {
                    alert("Моля въведете валидна цена (неотрицателно число, две десетични)");
                    isLoading = false;
                    return;
                }
                priceValue = Math.round(Number(price) * 100) / 100;
            }

            const insertPayload: any = { title: title.trim(), description: description.trim(), profile_id: prof.id, price: priceValue };

            const { data: offerData, error: offerError } = await supabase.from("offer").insert(insertPayload).select().single();
            if (offerError) throw offerError;
            if (selectedFiles.length > 0) await uploadImages(offerData.id, user.id);
            // redirect to created offer
            goto(`/offer/${offerData.id}`);
        } catch (e) {
            console.error("Error creating offer:", e);
            alert("Грешка при създаване на оферта. Моля опитайте отново.");
        } finally {
            isLoading = false;
        }
    }

    onMount(async () => {
        // Ensure we have the current user; if not present, try to get session from Supabase
        let user: any = $session?.user;
        if (!user) {
            try {
                const { data } = await supabase.auth.getSession();
                user = (data as any)?.session?.user || null;
            } catch (e) {
                user = null;
            }
        }

        if (!user) {
            goto("/register");
            return;
        }

        // Load profile row connected to this user for display
        try {
            const { data: prof, error } = await supabase.from("profile").select("id,name,location,phone_number").eq("user_id", user.id).maybeSingle();
            if (error) {
                console.error("Error checking profile:", error);
            }
            if (!prof) {
                goto("/register");
                return;
            }
            profile = prof;
        } catch (e) {
            console.error("Unexpected error checking profile:", e);
        }
    });
</script>

<main class="container py-4">
    <h2>Нова обява</h2>
    <div class="card p-3 bg-transparent border-0 shadow-none">
        <div class="mb-3">
            <label class="form-label">Название</label>
            <input class="form-control" bind:value={title} placeholder="Въведете название" disabled={isLoading} />
        </div>
        <div class="mb-3">
            <label class="form-label">Описание</label>
            <textarea class="form-control" rows={4} bind:value={description} disabled={isLoading}></textarea>
        </div>
        <div class="mb-3">
            <label class="form-label">Профил</label>
            <input class="form-control" value={profile?.name ?? ""} disabled />
        </div>
        <div class="mb-3">
            <label class="form-label">Изображения</label>
            <input type="file" class="form-control" multiple accept="image/*" bind:this={fileInputElement} on:change={handleFileSelect} disabled={isLoading} />
            <small class="text-muted">Изберете няколко изображения (не e задължително)</small>
        </div>
        <div class="mb-3 form-check">
            <input
                class="form-check-input"
                type="checkbox"
                id="isFree"
                bind:checked={isFree}
                on:change={() => {
                    if (isFree) price = "";
                }}
                disabled={isLoading}
            />
            <label class="form-check-label" for="isFree">Безплатно</label>
        </div>
        {#if !isFree}
            <div class="mb-3">
                <label class="form-label">Цена (€)</label>
                <input class="form-control" type="number" min="0" step="0.01" bind:value={price} placeholder="0.00" disabled={isLoading} />
                <small class="text-muted">Въведете цена в евро (напр. 3.50)</small>
            </div>
        {/if}

        {#if selectedFiles.length > 0}
            <div class="mb-3">
                <div class="image-preview-container">
                    {#each selectedFiles as file, idx}
                        <div class="image-preview-item">
                            <div class="image-preview-index">{idx + 1}</div>
                            <img src={URL.createObjectURL(file)} class="image-preview" />
                            <button class="btn btn-sm btn-danger" on:click={() => removeFile(idx)} disabled={isLoading}>Премахни</button>
                            <small class="text-muted">{file.name}</small>
                        </div>
                    {/each}
                </div>
            </div>
        {/if}

        <div class="d-flex justify-content-end gap-2">
            <button class="btn btn-outline-light" on:click={() => goto("/profile/edit")} disabled={isLoading}>Редактирай профил</button>
            <button class="btn btn-secondary" on:click={() => goto("/")} disabled={isLoading}>Отказ</button>
            <button class="btn btn-primary" on:click={handleSubmit} disabled={isLoading}>
                {#if isLoading}<span class="spinner-border spinner-border-sm me-2" role="status"></span>Създавам...{:else}Създай оферта{/if}
            </button>
        </div>
    </div>
</main>
