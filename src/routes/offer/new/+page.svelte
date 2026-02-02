<script lang="ts">
    import { supabase } from '$lib/supabaseClient';
    import { session } from '$lib/session';
    import { onMount } from 'svelte';
    import { goto } from '$app/navigation';

    let title = '';
    let description = '';
    let selectedFiles: File[] = [];
    let isLoading = false;
    let fileInputElement: HTMLInputElement;

    interface FileWithIndex { file: File; index: number }

    function handleFileSelect(event: Event) {
        const input = event.target as HTMLInputElement;
        if (input.files) {
            selectedFiles = [...selectedFiles, ...Array.from(input.files)];
            input.value = '';
        }
    }

    function removeFile(index: number) {
        selectedFiles = selectedFiles.filter((_, i) => i !== index);
    }

    async function uploadImages(offerId: any, userId: string) {
        const filesWithIndex: FileWithIndex[] = selectedFiles.map((file, idx) => ({ file, index: idx + 1 }));
        for (const { file, index } of filesWithIndex) {
            const mime = file.type || 'image/jpeg';
            const ext = mime.split('/').pop() || 'jpg';
            const filename = `${crypto.randomUUID()}.${ext}`;
            const storagePath = `${userId}/offer${offerId}/${filename}`;
            const { error: uploadError } = await supabase.storage.from('images').upload(storagePath, file, { cacheControl: '3600', upsert: false, contentType: mime } as any);
            if (uploadError) throw uploadError;

            let publicUrl: string | null = null;
            try { const { data } = supabase.storage.from('images').getPublicUrl(storagePath); publicUrl = (data as any)?.publicUrl || null; } catch (e) { }
            if (!publicUrl) {
                try { const { data: sd, error: se } = await supabase.storage.from('images').createSignedUrl(storagePath, 60 * 60 * 24); if (!se && sd?.signedUrl) publicUrl = sd.signedUrl; } catch (e) { }
            }
            if (!publicUrl) throw new Error('Could not obtain URL for uploaded image');
            const { error: insertError } = await supabase.from('image').insert({ offer_id: offerId, index, url: publicUrl, user_id: userId });
            if (insertError) throw insertError;
        }
    }

    async function handleSubmit() {
        if (!title.trim() || !description.trim()) { alert('Моля попълнете всички полета'); return; }
        const user = $session?.user;
        if (!user) { alert('Трябва да сте логнати'); return; }
        isLoading = true;
        try {
            const { data: offerData, error: offerError } = await supabase.from('offer').insert({ title: title.trim(), description: description.trim(), user_id: user.id }).select().single();
            if (offerError) throw offerError;
            if (selectedFiles.length > 0) await uploadImages(offerData.id, user.id);
            // redirect to created offer
            goto(`/offer/${offerData.id}`);
        } catch (e) {
            console.error('Error creating offer:', e);
            alert('Грешка при създаване на оферта. Моля опитайте отново.');
        } finally { isLoading = false; }
    }
</script>

<main class="container py-4">
    <h2>Нова обява</h2>
    <div class="card p-3">
        <div class="mb-3">
            <label class="form-label">Название</label>
            <input class="form-control" bind:value={title} placeholder="Въведете название" disabled={isLoading} />
        </div>
        <div class="mb-3">
            <label class="form-label">Описание</label>
            <textarea class="form-control" rows={4} bind:value={description} disabled={isLoading}></textarea>
        </div>
        <div class="mb-3">
            <label class="form-label">Изображения</label>
            <input type="file" class="form-control" multiple accept="image/*" bind:this={fileInputElement} onchange={handleFileSelect} disabled={isLoading} />
            <small class="text-muted">Изберете няколко изображения (не е задължително)</small>
        </div>

        {#if selectedFiles.length > 0}
            <div class="mb-3">
                <div class="image-preview-container">
                    {#each selectedFiles as file, idx}
                        <div class="image-preview-item">
                            <div class="image-preview-index">{idx + 1}</div>
                            <img src={URL.createObjectURL(file)} class="image-preview" />
                            <button class="btn btn-sm btn-danger" onclick={() => removeFile(idx)} disabled={isLoading}>Премахни</button>
                            <small class="text-muted">{file.name}</small>
                        </div>
                    {/each}
                </div>
            </div>
        {/if}

        <div class="d-flex justify-content-end gap-2">
            <button class="btn btn-secondary" onclick={() => goto('/')} disabled={isLoading}>Отказ</button>
            <button class="btn btn-primary" onclick={handleSubmit} disabled={isLoading}>
                {#if isLoading}<span class="spinner-border spinner-border-sm me-2" role="status"></span>Създавам...{:else}Създай оферта{/if}
            </button>
        </div>
    </div>
</main>

<style>
.image-preview-container{display:flex;gap:1rem;flex-wrap:wrap}
.image-preview-item{display:flex;flex-direction:column;align-items:center}
.image-preview{width:120px;height:120px;object-fit:cover;border:1px solid #dee2e6;border-radius:4px}
.image-preview-index{position:relative;top:-110px;left:40px;background:#007bff;color:#fff;border-radius:50%;width:24px;height:24px;display:flex;align-items:center;justify-content:center}
</style>
