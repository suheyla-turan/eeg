/**
 * One-shot: delete all Firestore `videos` documents.
 * Storage files cannot be deleted via unauthenticated REST (403) —
 * use the app's "Tümünü sil" button (delete_sweep) for Storage cleanup.
 * Usage: node tools/wipe_videos.mjs
 */
const PROJECT = 'eeg-mobil';
const BUCKET = 'eeg-mobil.firebasestorage.app';

async function listFirestoreVideos() {
  const docs = [];
  let pageToken;
  do {
    const params = new URLSearchParams({ pageSize: '300' });
    if (pageToken) params.set('pageToken', pageToken);
    const url =
      `https://firestore.googleapis.com/v1/projects/${PROJECT}` +
      `/databases/(default)/documents/videos?${params}`;
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(`Firestore list failed: ${res.status} ${await res.text()}`);
    }
    const data = await res.json();
    docs.push(...(data.documents ?? []));
    pageToken = data.nextPageToken;
  } while (pageToken);
  return docs;
}

async function deleteFirestoreDoc(name) {
  const res = await fetch(`https://firestore.googleapis.com/v1/${name}`, {
    method: 'DELETE',
  });
  if (!res.ok && res.status !== 404) {
    throw new Error(`Firestore delete failed: ${res.status} ${await res.text()}`);
  }
}

async function listStorage(prefix) {
  const items = [];
  let pageToken;
  do {
    const params = new URLSearchParams({ prefix, maxResults: '1000' });
    if (pageToken) params.set('pageToken', pageToken);
    const url = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o?${params}`;
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(`Storage list failed: ${res.status} ${await res.text()}`);
    }
    const data = await res.json();
    items.push(...(data.items ?? []));
    pageToken = data.nextPageToken;
  } while (pageToken);
  return items;
}

async function deleteStorageObject(name) {
  const encoded = encodeURIComponent(name);
  const url = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encoded}`;
  const res = await fetch(url, { method: 'DELETE' });
  if (!res.ok && res.status !== 404) {
    throw new Error(
      `Storage delete failed (${name}): ${res.status} ${await res.text()}`,
    );
  }
}

async function main() {
  console.log('Listing Firestore videos…');
  const docs = await listFirestoreVideos();
  console.log(`Found ${docs.length} Firestore document(s).`);

  for (const doc of docs) {
    const id = doc.name.split('/').pop();
    process.stdout.write(`  delete firestore ${id}… `);
    await deleteFirestoreDoc(doc.name);
    console.log('ok');
  }

  console.log('Listing Storage videos/…');
  const objects = await listStorage('videos/');
  console.log(`Found ${objects.length} Storage object(s).`);

  for (const obj of objects) {
    process.stdout.write(`  delete storage ${obj.name}… `);
    await deleteStorageObject(obj.name);
    console.log('ok');
  }

  console.log('Done. All videos removed from Firestore and Storage.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
