/**
 * Utilitários de timezone — Jalapão Monitor Hub
 *
 * POLÍTICA DE TIMEZONE
 * ────────────────────
 * • Armazenamento: todos os timestamps no PocketBase são UTC (sufixo Z).
 *   O PocketBase normaliza internamente para UTC independente do que for enviado.
 * • Exibição: toda hora/data exibida no Hub usa o fuso de Brasília (BRT = UTC-3,
 *   sem horário de verão — Brasil aboliu o DST em 2019).
 * • Filtros de API: os filtros usam UTC. "Hoje em BRT" começa às 03:00 UTC
 *   (meia-noite BRT). Isso é tratado em todayBRTRange().
 *
 * Justificativa: separar armazenamento universal de exibição local evita ambiguidade
 * em relatórios e permite que futuras integrações (outros fusos) não corrompam dados.
 */

export const TZ = 'America/Sao_Paulo';

/** Locale pt-BR com timezone de Brasília para todos os formatadores. */
const LOCALE = 'pt-BR';

/** Retorna a data atual em BRT como string YYYY-MM-DD (formato sv-SE = ISO date). */
export function todayBRT(): string {
  return new Intl.DateTimeFormat('sv-SE', { timeZone: TZ }).format(new Date());
}

/**
 * Retorna [início, fim] UTC para "hoje em BRT" como strings de filtro do PocketBase.
 * Ex: BRT 2026-03-20 → UTC "2026-03-20 03:00:00.000Z" até "2026-03-21 02:59:59.999Z"
 */
export function todayBRTRange(): [string, string] {
  const today = todayBRT(); // YYYY-MM-DD em BRT
  const tomorrow = new Intl.DateTimeFormat('sv-SE', { timeZone: TZ }).format(
    new Date(Date.now() + 86400000),
  );
  return [`${today} 03:00:00.000Z`, `${tomorrow} 02:59:59.999Z`];
}

/**
 * Retorna [início, fim] UTC para uma data BRT específica (YYYY-MM-DD).
 */
export function dateBRTRange(dateBRT: string): [string, string] {
  const [y, m, d] = dateBRT.split('-').map(Number);
  // meia-noite BRT = 03:00 UTC do mesmo dia
  const start = new Date(Date.UTC(y, m - 1, d, 3, 0, 0, 0));
  const end   = new Date(Date.UTC(y, m - 1, d + 1, 2, 59, 59, 999));
  return [
    start.toISOString().replace('T', ' '),
    end.toISOString().replace('T', ' '),
  ];
}

/** Extrai a hora local BRT (0-23) de um Date. */
export function hourBRT(d: Date): number {
  const s = new Intl.DateTimeFormat(LOCALE, {
    timeZone: TZ,
    hour: 'numeric',
    hour12: false,
  }).format(d);
  return Number(s);
}

/** Extrai a data BRT como YYYY-MM-DD de um Date. */
export function dateBRTStr(d: Date): string {
  return new Intl.DateTimeFormat('sv-SE', { timeZone: TZ }).format(d);
}

/** Formata hora em BRT: "07:30". */
export function fmtTimeBRT(d: Date | null | undefined): string {
  if (!d || isNaN(d.getTime())) return '—';
  return d.toLocaleTimeString(LOCALE, {
    timeZone: TZ,
    hour: '2-digit',
    minute: '2-digit',
  });
}

/** Formata data em BRT: "2026-03-20". */
export function fmtDateBRT(d: Date | null | undefined): string {
  if (!d || isNaN(d.getTime())) return '';
  return new Intl.DateTimeFormat('sv-SE', { timeZone: TZ }).format(d);
}

/** Label de dia da semana BRT: "Qui 20/03". */
export function dayLabelBRT(d: Date): string {
  return d.toLocaleDateString(LOCALE, {
    timeZone: TZ,
    weekday: 'short',
    day: '2-digit',
    month: '2-digit',
  });
}

/**
 * Retorna os últimos N dias em BRT como array [{ key: 'YYYY-MM-DD', label: 'Qui 20/03' }].
 * Índice 0 = mais antigo, último = hoje.
 */
export function lastNDaysBRT(n: number): { key: string; label: string }[] {
  const days: { key: string; label: string }[] = [];
  for (let i = n - 1; i >= 0; i--) {
    const d = new Date(Date.now() - i * 86400000);
    days.push({ key: dateBRTStr(d), label: dayLabelBRT(d) });
  }
  return days;
}
