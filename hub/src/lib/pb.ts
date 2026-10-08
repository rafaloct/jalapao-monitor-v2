import PocketBase from 'pocketbase';

// URL do PocketBase — configure via NEXT_PUBLIC_PB_URL (ver .env.example).
// Sem fallback para endereço de produção: ausente aponta para localhost
// (valor de desenvolvimento não sensível, mesma convenção do app Flutter).
const PB_URL = process.env.NEXT_PUBLIC_PB_URL ?? 'http://localhost:8090';

const pb = new PocketBase(PB_URL);

// Desabilita auto-cancellation para evitar que queries paralelas
// no Promise.all do PlacesTab se cancelem mutuamente.
pb.autoCancellation(false);

export default pb;
