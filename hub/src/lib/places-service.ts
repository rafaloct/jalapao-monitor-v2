import pb from './pb';
import type { Place, PlaceVisit, PlaceWithStats, Reservation } from './types';
import { todayBRT, dateBRTRange, hourBRT, dateBRTStr, lastNDaysBRT } from './tz';

// ── Legacy visits (fervedouro/cachoeira — coleção 'visits') ──────────────────

export interface LegacyVisit {
  id: string;
  group_id: string;
  atrativo: string;
  tablet_id: string;
  pax_qty: number;
  status: 'fila' | 'agua' | 'concluido';
  arrival_time: string;
  entry_time: string | null;
  exit_time: string | null;
  capacity_limit: number;
  group_name?: string | null;
}

export async function fetchTodayLegacyVisits(): Promise<LegacyVisit[]> {
  try {
    const [start, end] = dateBRTRange(todayBRT());
    return await pb.collection('visits').getFullList<LegacyVisit>({
      filter: `arrival_time >= "${start}" && arrival_time <= "${end}"`,
      sort: '-arrival_time',
    });
  } catch {
    return [];
  }
}

export async function fetchWeeklyLegacyVisits(): Promise<LegacyVisit[]> {
  try {
    return await pb.collection('visits').getFullList<LegacyVisit>({
      filter: weekRangeFilter('arrival_time'),
      sort: 'arrival_time',
    });
  } catch {
    return [];
  }
}

/**
 * Converte LegacyVisit[] em PlaceVisit[] resolvendo place_id pelo nome.
 * Só inclui registros onde atrativo bate (case-insensitive) com um place ativo.
 */
export function convertLegacyVisits(
  legacyVisits: LegacyVisit[],
  places: Place[],
): PlaceVisit[] {
  const nameToId = new Map(places.map((p) => [p.name.toLowerCase().trim(), p.id]));
  return legacyVisits
    .map((v): PlaceVisit | null => {
      const placeId = nameToId.get(v.atrativo.toLowerCase().trim());
      if (!placeId) return null;
      return {
        id: `legacy_${v.id}`,
        place_id: placeId,
        pax_qty: v.pax_qty,
        arrival_time: v.arrival_time,
        exit_time: v.exit_time,
        status: v.status === 'agua' ? 'visiting' : v.status === 'fila' ? 'queued' : 'exited',
        tablet_id: v.tablet_id,
        notes: null,
        group_name: null,
        origin_city: null,
      };
    })
    .filter((v): v is PlaceVisit => v !== null);
}

// Desabilita auto-cancellation para evitar que queries paralelas ao mesmo
// collection se cancelem mutuamente no Promise.all do PlacesTab.
pb.autoCancellation(false);

/** PocketBase retorna datas com espaço em vez de T — normaliza para ISO 8601 */
function pbDate(s: string | null | undefined): Date {
  if (!s) return new Date(NaN);
  return new Date(s.replace(' ', 'T'));
}

export async function fetchActivePlaces(): Promise<Place[]> {
  try {
    const records = await pb.collection('places').getFullList<Place>({
      filter: 'status = "active"',
      sort: 'name',
    });
    return records;
  } catch {
    return [];
  }
}

/**
 * Busca TODOS os place_visits do dia (ou de uma data específica).
 * Os visitantes ativos são derivados filtrando status="visiting" no resultado —
 * assim evitamos duas queries concorrentes ao mesmo collection.
 */
export async function fetchAllPlaceVisits(todayOnly = true, dateFilter?: string): Promise<PlaceVisit[]> {
  try {
    const options: Record<string, string> = { sort: '-arrival_time' };
    if (dateFilter) {
      const [start, end] = dateBRTRange(dateFilter);
      options.filter = `arrival_time >= "${start}" && arrival_time <= "${end}"`;
    } else if (todayOnly) {
      const [start, end] = dateBRTRange(todayBRT());
      options.filter = `arrival_time >= "${start}" && arrival_time <= "${end}"`;
    }
    const records = await pb.collection('place_visits').getFullList<PlaceVisit>(options);
    return records;
  } catch {
    return [];
  }
}

/**
 * Retorna somente os place_visits com status=visiting a partir dos dados
 * já buscados — não faz uma nova query ao PocketBase.
 */
export function filterActiveVisits(allVisits: PlaceVisit[]): PlaceVisit[] {
  return allVisits.filter((v) => v.status === 'visiting');
}

// ── Reservations (pousadas / restaurantes) ───────────────────────────────────

/** Reservas com check-in feito e grupo ainda no local (status = no_local). */
export async function fetchActiveReservations(): Promise<Reservation[]> {
  try {
    const records = await pb.collection('reservations').getFullList<Reservation>({
      filter: 'status = "no_local"',
      sort: '-arrival_time',
    });
    return records;
  } catch {
    return [];
  }
}

/** Todas as reservas do dia (por scheduled_time ou arrival_time). */
export async function fetchTodayReservations(dateFilter?: string): Promise<Reservation[]> {
  try {
    const [start, end] = dateBRTRange(dateFilter ?? todayBRT());
    const filter =
      `(scheduled_time >= "${start}" && scheduled_time <= "${end}")` +
      ` || (arrival_time >= "${start}" && arrival_time <= "${end}")`;
    const records = await pb.collection('reservations').getFullList<Reservation>({
      filter,
      sort: '-scheduled_time',
    });
    return records;
  } catch {
    return [];
  }
}

// ── Enrichment ───────────────────────────────────────────────────────────────

export function enrichPlacesWithStats(
  places: Place[],
  allTodayVisits: PlaceVisit[],
  activeVisits: PlaceVisit[],
  activeReservations: Reservation[] = [],
): PlaceWithStats[] {
  return places.map((place) => {
    // place_visits ativos (fervedouros, cachoeiras, etc.)
    const activeForPlace = activeVisits.filter((v) => v.place_id === place.id);
    // reservas com check-in (pousadas, restaurantes, etc.)
    const reservationsForPlace = activeReservations.filter((r) => r.place_id === place.id);

    const currentOccupancy =
      activeForPlace.reduce((s, v) => s + v.pax_qty, 0) +
      reservationsForPlace.reduce((s, r) => s + r.pax_qty, 0);

    const todayForPlace = allTodayVisits.filter((v) => v.place_id === place.id);
    const todayPax = todayForPlace.reduce((s, v) => s + v.pax_qty, 0);

    const completed = todayForPlace.filter((v) => v.exit_time);
    const avgDurationMinutes =
      completed.length > 0
        ? completed.reduce((s, v) => {
            const dur = (pbDate(v.exit_time!).getTime() - pbDate(v.arrival_time).getTime()) / 60000;
            return s + dur;
          }, 0) / completed.length
        : null;

    return {
      ...place,
      currentOccupancy,
      occupancyRatio: place.capacity_total > 0 ? currentOccupancy / place.capacity_total : 0,
      todayPax,
      todayVisitsCount: todayForPlace.length,
      avgDurationMinutes,
    };
  });
}

export function buildHourlyFlowData(
  visits: PlaceVisit[],
  filterPlaceId?: string,
  filterType?: string,
  places?: Place[],
  reservations?: Reservation[],
) {
  const hourMap: Record<string, { pax: number; visits: number }> = {};
  for (let h = 6; h <= 20; h++) {
    hourMap[`${String(h).padStart(2, '0')}:00`] = { pax: 0, visits: 0 };
  }

  function matchesFilter(placeId: string): boolean {
    if (filterPlaceId && placeId !== filterPlaceId) return false;
    if (filterType && places) {
      const place = places.find((p) => p.id === placeId);
      if (!place || place.type !== filterType) return false;
    }
    return true;
  }

  function addToHour(timeStr: string | null | undefined, paxQty: number) {
    if (!timeStr) return;
    const hour = hourBRT(pbDate(timeStr)); // hora local BRT, não UTC
    if (hour >= 6 && hour <= 20) {
      const key = `${String(hour).padStart(2, '0')}:00`;
      hourMap[key].pax += paxQty;
      hourMap[key].visits += 1;
    }
  }

  for (const v of visits) {
    if (matchesFilter(v.place_id)) addToHour(v.arrival_time, v.pax_qty);
  }

  // Inclui reservações (restaurante, pousada) — usa arrival_time real ou scheduled_time
  for (const r of reservations ?? []) {
    if (matchesFilter(r.place_id)) addToHour(r.arrival_time ?? r.scheduled_time, r.pax_qty);
  }

  return Object.entries(hourMap).map(([hour, { pax, visits }]) => ({ hour, pax, visits }));
}

// ── Heatmap Semanal (item 3.3) ────────────────────────────────────────────────

function weekRangeFilter(field: string): string {
  const days = lastNDaysBRT(7);
  const [start] = dateBRTRange(days[0].key);       // início do dia mais antigo em BRT
  const [, end]  = dateBRTRange(days[days.length - 1].key); // fim de hoje em BRT
  return `${field} >= "${start}" && ${field} <= "${end}"`;
}

/** Busca place_visits dos últimos 7 dias (inclusive hoje). */
export async function fetchWeeklyPlaceVisits(): Promise<PlaceVisit[]> {
  try {
    const records = await pb.collection('place_visits').getFullList<PlaceVisit>({
      filter: weekRangeFilter('arrival_time'),
      sort: 'arrival_time',
    });
    return records;
  } catch {
    return [];
  }
}

/** Busca reservations dos últimos 7 dias (por scheduled_time ou arrival_time). */
export async function fetchWeeklyReservations(): Promise<Reservation[]> {
  try {
    const rangeScheduled = weekRangeFilter('scheduled_time');
    const rangeArrival = weekRangeFilter('arrival_time');
    const records = await pb.collection('reservations').getFullList<Reservation>({
      filter: `(${rangeScheduled}) || (${rangeArrival})`,
      sort: 'scheduled_time',
    });
    return records;
  } catch {
    return [];
  }
}

export interface HeatmapData {
  days: string[];    // labels "Seg 17/03"
  hours: string[];   // "06:00" … "20:00"
  /** data[dayLabel][hourKey] = total pax */
  data: Record<string, Record<string, number>>;
  maxPax: number;
}

export function buildWeeklyHeatmap(
  visits: PlaceVisit[],
  filterPlaceId?: string,
  filterType?: string,
  places?: Place[],
  reservations?: Reservation[],
): HeatmapData {
  // Usa dias em BRT para garantir que virada de meia-noite local seja respeitada
  const brtDays = lastNDaysBRT(7);
  const dayKeys   = brtDays.map((d) => d.key);
  const dayLabels = brtDays.map((d) => d.label);

  const hours: string[] = [];
  for (let h = 6; h <= 20; h++) {
    hours.push(`${String(h).padStart(2, '0')}:00`);
  }

  const data: Record<string, Record<string, number>> = {};
  for (const label of dayLabels) {
    data[label] = {};
    for (const h of hours) data[label][h] = 0;
  }

  function matchesFilter(placeId: string): boolean {
    if (filterPlaceId && placeId !== filterPlaceId) return false;
    if (filterType && places) {
      const place = places.find((p) => p.id === placeId);
      if (!place || place.type !== filterType) return false;
    }
    return true;
  }

  let maxPax = 0;

  function addEntry(placeId: string, timeStr: string | null | undefined, paxQty: number) {
    if (!timeStr || !matchesFilter(placeId)) return;
    const d = pbDate(timeStr);
    if (isNaN(d.getTime())) return;
    // Usa data e hora em BRT para evitar deslocamento de 3h no histograma
    const dayStr = dateBRTStr(d);
    const idx = dayKeys.indexOf(dayStr);
    if (idx === -1) return;
    const hour = hourBRT(d);
    if (hour < 6 || hour > 20) return;
    const hourKey = `${String(hour).padStart(2, '0')}:00`;
    data[dayLabels[idx]][hourKey] += paxQty;
    if (data[dayLabels[idx]][hourKey] > maxPax) maxPax = data[dayLabels[idx]][hourKey];
  }

  for (const v of visits) addEntry(v.place_id, v.arrival_time, v.pax_qty);
  for (const r of reservations ?? []) addEntry(r.place_id, r.arrival_time ?? r.scheduled_time, r.pax_qty);

  return { days: dayLabels, hours, data, maxPax };
}

// ── Origin City Chart ─────────────────────────────────────────────────────────

export interface OriginCityEntry {
  city: string;
  pax: number;
}

/**
 * Agrega origem dos visitantes de todas as fontes (place_visits + reservations).
 * Retorna top N cidades por pax, excluindo registros sem city informada.
 */
export function buildOriginCityData(
  visits: PlaceVisit[],
  reservations: Reservation[] = [],
  legacyVisits: PlaceVisit[] = [],
  topN = 10,
): OriginCityEntry[] {
  const cityMap: Record<string, number> = {};

  function addCity(city: string | null | undefined, pax: number) {
    if (!city || city.trim() === '') return;
    const key = city.trim();
    cityMap[key] = (cityMap[key] ?? 0) + pax;
  }

  for (const v of [...visits, ...legacyVisits]) addCity(v.origin_city, v.pax_qty);
  for (const r of reservations) addCity(r.origin_city, r.pax_qty);

  return Object.entries(cityMap)
    .map(([city, pax]) => ({ city, pax }))
    .sort((a, b) => b.pax - a.pax)
    .slice(0, topN);
}
