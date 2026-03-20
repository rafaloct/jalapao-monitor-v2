import PocketBase from 'pocketbase';

// URL do PocketBase — configure via variável de ambiente em produção
const PB_URL = process.env.NEXT_PUBLIC_PB_URL ?? 'http://92.112.179.111:8090';

const pb = new PocketBase(PB_URL);

// Desabilita auto-cancellation para evitar que queries paralelas
// no Promise.all do PlacesTab se cancelem mutuamente.
pb.autoCancellation(false);

export default pb;
