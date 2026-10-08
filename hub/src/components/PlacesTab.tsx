'use client';

import { useEffect, useState, useCallback } from 'react';
import pb from '@/lib/pb';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts';
import { RefreshCw } from 'lucide-react';
import {
  fetchActivePlaces,
  fetchAllPlaceVisits,
  filterActiveVisits,
  fetchActiveReservations,
  fetchTodayReservations,
  enrichPlacesWithStats,
  buildHourlyFlowData,
  fetchWeeklyPlaceVisits,
  fetchWeeklyReservations,
  buildWeeklyHeatmap,
  fetchTodayLegacyVisits,
  fetchWeeklyLegacyVisits,
  convertLegacyVisits,
  buildOriginCityData,
} from '@/lib/places-service';
import type { LegacyVisit } from '@/lib/places-service';
import type { Place, PlaceVisit, Reservation, PlaceWithStats, PlaceType } from '@/lib/types';
import { PLACE_TYPE_CONFIG } from '@/lib/types';
import { todayBRT, fmtTimeBRT } from '@/lib/tz';

function occupancyColor(ratio: number): string {
  if (ratio >= 1.0) return '#D32F2F';
  if (ratio >= 0.7) return '#FF9800';
  return '#00ACC1';
}

/** PocketBase retorna datas com espaço em vez de T — normaliza para ISO 8601 */
function pbDate(s: string | null | undefined): Date {
  if (!s) return new Date(NaN);
  return new Date(s.replace(' ', 'T'));
}

function fmtTime(s: string | null | undefined): string {
  return fmtTimeBRT(pbDate(s)); // hora local BRT
}

/** Normaliza uma Reservation no_local para exibição na tabela de ativos */
function reservationToRow(r: Reservation, place: PlaceWithStats) {
  return {
    id: r.id,
    place,
    paxQty: r.pax_qty,
    arrivalTime: pbDate(r.arrival_time ?? r.scheduled_time),
    label: r.guest_name || 'Grupo',
    isReservation: true,
  };
}

/** Normaliza um PlaceVisit para exibição na tabela de ativos */
function visitToRow(v: PlaceVisit, place: PlaceWithStats) {
  return {
    id: v.id,
    place,
    paxQty: v.pax_qty,
    arrivalTime: pbDate(v.arrival_time),
    label: v.group_name ?? null as string | null,
    isReservation: false,
  };
}

export function PlacesTab() {
  const [places, setPlaces] = useState<PlaceWithStats[]>([]);
  const [activeVisits, setActiveVisits] = useState<PlaceVisit[]>([]);
  const [activeReservations, setActiveReservations] = useState<Reservation[]>([]);
  const [todayVisits, setTodayVisits] = useState<PlaceVisit[]>([]);
  const [todayReservations, setTodayReservations] = useState<Reservation[]>([]);
  const [rawPlaces, setRawPlaces] = useState<Place[]>([]);
  const [filterType, setFilterType] = useState<string>('all');
  const [filterPlace, setFilterPlace] = useState<string>('all');
  const [historyDate, setHistoryDate] = useState<string>(todayBRT());
  const [historyVisits, setHistoryVisits] = useState<PlaceVisit[]>([]);
  const [historyReservations, setHistoryReservations] = useState<Reservation[]>([]);
  const [weeklyVisits, setWeeklyVisits] = useState<PlaceVisit[]>([]);
  const [weeklyReservations, setWeeklyReservations] = useState<Reservation[]>([]);
  const [legacyToday, setLegacyToday] = useState<LegacyVisit[]>([]);
  const [legacyWeekly, setLegacyWeekly] = useState<LegacyVisit[]>([]);
  const [loading, setLoading] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());

  const fetchData = useCallback(async () => {
    const [rawP, today, activeRes, todayRes, legacy] = await Promise.all([
      fetchActivePlaces(),
      fetchAllPlaceVisits(true),
      fetchActiveReservations(),
      fetchTodayReservations(),
      fetchTodayLegacyVisits(),
    ]);
    const active = filterActiveVisits(today);

    // Converte legado e mescla: fervedouros/cachoeiras passam a ter dados reais
    const legacyAsVisits = convertLegacyVisits(legacy, rawP);
    const legacyActiveVisits = legacyAsVisits.filter((v) => v.status === 'visiting');

    const mergedToday = [...today, ...legacyAsVisits];
    const mergedActive = [...active, ...legacyActiveVisits];

    setRawPlaces(rawP);
    setTodayVisits(mergedToday);
    setActiveVisits(mergedActive);
    setActiveReservations(activeRes);
    setTodayReservations(todayRes);
    setLegacyToday(legacy);
    setPlaces(enrichPlacesWithStats(rawP, mergedToday, mergedActive, activeRes));
    setLastUpdate(new Date());
    setLoading(false);
  }, []);

  const fetchHistory = useCallback(async (date: string) => {
    const [visits, reservations, legacy] = await Promise.all([
      fetchAllPlaceVisits(false, date),
      fetchTodayReservations(date),
      // Reutiliza fetchTodayLegacyVisits com filtro de data manual via PB
      pb.collection('visits').getFullList({
        filter: `arrival_time >= "${date} 00:00:00.000Z" && arrival_time <= "${date} 23:59:59.999Z"`,
        sort: '-arrival_time',
      }).catch(() => [] as LegacyVisit[]),
    ]);
    const legacyConverted = convertLegacyVisits(legacy as LegacyVisit[], rawPlaces);
    setHistoryVisits([...visits, ...legacyConverted]);
    setHistoryReservations(reservations);
  }, [rawPlaces]);

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 30000);
    return () => clearInterval(interval);
  }, [fetchData]);

  useEffect(() => {
    fetchHistory(historyDate);
  }, [historyDate, fetchHistory]);

  // Heatmap semanal — carrega 1x ao montar (dados dos últimos 7 dias)
  useEffect(() => {
    Promise.all([
      fetchWeeklyPlaceVisits(),
      fetchWeeklyReservations(),
      fetchWeeklyLegacyVisits(),
    ]).then(([visits, reservations, legacy]) => {
      setWeeklyReservations(reservations);
      setLegacyWeekly(legacy);
      // Merge legado no weekly — places ainda não carregados aqui,
      // será mesclado no useMemo abaixo quando rawPlaces estiver disponível
      setWeeklyVisits(visits);
    });
  }, []);

  // ── Métricas dos cards ───────────────────────────────────────────────────
  const totalActive = places.length;
  const visitorsNow =
    activeVisits.reduce((s, v) => s + v.pax_qty, 0) +
    activeReservations.reduce((s, r) => s + r.pax_qty, 0);
  const visitsToday =
    todayVisits.reduce((s, v) => s + v.pax_qty, 0) +
    todayReservations.reduce((s, r) => s + r.pax_qty, 0);
  const typesMonitored = new Set(places.map((p) => p.type)).size;

  const placesByType = places.reduce<Record<string, PlaceWithStats[]>>((acc, p) => {
    acc[p.type] = acc[p.type] ?? [];
    acc[p.type].push(p);
    return acc;
  }, {});

  // 3.2: Histograma usa os dados do dia selecionado no picker histórico
  // Inclui reservações para restaurantes/pousadas
  const today = todayBRT();
  const chartSourceVisits = historyDate === today ? todayVisits : historyVisits;
  const chartSourceReservations = historyDate === today ? todayReservations : historyReservations;
  const chartData = buildHourlyFlowData(
    chartSourceVisits,
    filterPlace !== 'all' ? filterPlace : undefined,
    filterType !== 'all' ? filterType : undefined,
    rawPlaces,
    chartSourceReservations,
  );

  // 3.3: Heatmap semanal — inclui place_visits + reservations + legado (fervedouros)
  const mergedWeeklyVisits = rawPlaces.length > 0
    ? [...weeklyVisits, ...convertLegacyVisits(legacyWeekly, rawPlaces)]
    : weeklyVisits;
  const heatmap = buildWeeklyHeatmap(
    mergedWeeklyVisits,
    filterPlace !== 'all' ? filterPlace : undefined,
    filterType !== 'all' ? filterType : undefined,
    rawPlaces,
    weeklyReservations,
  );

  // Origem dos visitantes — agrega todas as fontes
  const mergedLegacyAsVisits = rawPlaces.length > 0 ? convertLegacyVisits(legacyToday, rawPlaces) : [];
  const originCityData = buildOriginCityData(todayVisits, todayReservations, mergedLegacyAsVisits);

  // 3.5: Locais próximos da capacidade (70–99%)
  const nearCapacityPlaces = places.filter((p) => p.occupancyRatio >= 0.7 && p.occupancyRatio < 1.0);

  // Fervedouro pipeline — usa legacyToday raw para grupos individuais + tempo
  const nowMs = Date.now();
  const fervedouroData = rawPlaces
    .filter((p) => p.type === 'fervedouro' && p.status === 'active')
    .map((place) => {
      const visits = legacyToday.filter(
        (v) => v.atrativo.toLowerCase().trim() === place.name.toLowerCase().trim(),
      );
      const inQueue = visits
        .filter((v) => v.status === 'fila')
        .map((v) => ({
          id: v.id,
          pax: v.pax_qty,
          label: v.group_name || v.group_id || 'Grupo',
          waitMin: Math.floor((nowMs - pbDate(v.arrival_time).getTime()) / 60000),
        }))
        .sort((a, b) => b.waitMin - a.waitMin);
      const inWater = visits
        .filter((v) => v.status === 'agua')
        .map((v) => ({
          id: v.id,
          pax: v.pax_qty,
          label: v.group_name || v.group_id || 'Grupo',
          stayMin: Math.floor(
            (nowMs - pbDate(v.entry_time ?? v.arrival_time).getTime()) / 60000,
          ),
        }))
        .sort((a, b) => b.stayMin - a.stayMin);
      const waterPax = inWater.reduce((s, v) => s + v.pax, 0);
      const queuePax = inQueue.reduce((s, v) => s + v.pax, 0);
      return { place, inQueue, inWater, waterPax, queuePax };
    })
    .filter((d) => d.inQueue.length > 0 || d.inWater.length > 0);

  // ── Tabela de ativos: merge place_visits + reservations no_local ─────────
  const activeRows = [
    ...activeVisits
      .map((v) => {
        const place = places.find((p) => p.id === v.place_id);
        return place ? visitToRow(v, place) : null;
      })
      .filter(Boolean),
    ...activeReservations
      .map((r) => {
        const place = places.find((p) => p.id === r.place_id);
        return place ? reservationToRow(r, place) : null;
      })
      .filter(Boolean),
  ] as ReturnType<typeof visitToRow>[];

  activeRows.sort((a, b) => a.arrivalTime.getTime() - b.arrivalTime.getTime());

  const overcrowdedPlaces = places.filter((p) => p.occupancyRatio >= 1.0);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-jalapao-text gap-3">
        <RefreshCw className="w-6 h-6 animate-spin text-jalapao-primary" />
        <span>Carregando dados de locais...</span>
      </div>
    );
  }

  if (places.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-64 text-jalapao-text gap-4">
        <span className="text-5xl">📍</span>
        <p className="text-lg font-semibold">Nenhum local ativo cadastrado.</p>
        <p className="text-sm text-jalapao-text/60">
          Cadastre e aprove locais no app Flutter para ver o monitoramento aqui.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Last update */}
      <div className="text-xs text-jalapao-text/50 text-right">
        Atualizado: {fmtTimeBRT(lastUpdate)} (BRT) · auto-refresh 30s
      </div>

      {/* Summary cards */}
      <section className="grid grid-cols-2 md:grid-cols-4 gap-6">
        {[
          { label: 'Locais Ativos', value: totalActive, icon: '📍', color: '#D87D4A' },
          { label: 'Visitantes Agora', value: visitorsNow, icon: '👥', color: '#00ACC1' },
          { label: 'Visitas Hoje (PAX)', value: visitsToday, icon: '📊', color: '#D87D4A' },
          { label: 'Tipos Monitorados', value: typesMonitored, icon: '🗂️', color: '#00ACC1' },
        ].map((card) => (
          <div key={card.label} className="premium-card p-6 flex flex-col items-center gap-2">
            <span className="text-3xl">{card.icon}</span>
            <span className="text-3xl font-black" style={{ color: card.color }}>
              {card.value}
            </span>
            <span className="text-xs text-jalapao-text/60 font-semibold text-center">
              {card.label}
            </span>
          </div>
        ))}
      </section>

      {/* 🚨 Superlotação >= 100% */}
      {overcrowdedPlaces.length > 0 && (
        <div className="rounded-xl border-2 border-red-400 bg-red-50 p-4 animate-pulse">
          <div className="flex items-center gap-3 mb-2">
            <span className="text-2xl">🚨</span>
            <h3 className="font-black text-red-700 uppercase tracking-wide">
              Superlotação Detectada — {overcrowdedPlaces.length} local{overcrowdedPlaces.length > 1 ? 'is' : ''}
            </h3>
          </div>
          <div className="flex flex-wrap gap-2">
            {overcrowdedPlaces.map((p) => {
              const config = PLACE_TYPE_CONFIG[p.type as PlaceType];
              return (
                <span
                  key={p.id}
                  className="bg-red-100 border border-red-300 text-red-700 text-xs font-bold px-3 py-1 rounded-full"
                >
                  {config?.icon} {p.name} — {p.currentOccupancy}/{p.capacity_total} ({Math.round(p.occupancyRatio * 100)}%)
                </span>
              );
            })}
          </div>
        </div>
      )}

      {/* ⚠️ 3.5: Alerta de capacidade próxima 70–99% */}
      {nearCapacityPlaces.length > 0 && (
        <div className="rounded-xl border-2 border-orange-300 bg-orange-50 p-4">
          <div className="flex items-center gap-3 mb-2">
            <span className="text-2xl">⚠️</span>
            <h3 className="font-black text-orange-700 uppercase tracking-wide">
              Capacidade Alta — {nearCapacityPlaces.length} local{nearCapacityPlaces.length > 1 ? 'is' : ''} acima de 70%
            </h3>
          </div>
          <div className="flex flex-wrap gap-2">
            {nearCapacityPlaces.map((p) => {
              const config = PLACE_TYPE_CONFIG[p.type as PlaceType];
              const pct = Math.round(p.occupancyRatio * 100);
              return (
                <span
                  key={p.id}
                  className="bg-orange-100 border border-orange-300 text-orange-700 text-xs font-bold px-3 py-1 rounded-full"
                >
                  {config?.icon} {p.name} — {p.currentOccupancy}/{p.capacity_total} ({pct}%)
                </span>
              );
            })}
          </div>
        </div>
      )}

      {/* Real-time occupancy by type */}
      <div className="premium-card p-6">
        <h2 className="text-lg font-black text-jalapao-text mb-4 uppercase tracking-wide">
          Ocupação em Tempo Real
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {Object.entries(placesByType).map(([type, typePlaces]) => {
            const config = PLACE_TYPE_CONFIG[type as PlaceType] ?? {
              label: type,
              icon: '📍',
              unit: 'unidades',
            };
            const totalCap = typePlaces.reduce((s, p) => s + p.capacity_total, 0);
            const totalOcc = typePlaces.reduce((s, p) => s + p.currentOccupancy, 0);
            const typeRatio = totalCap > 0 ? totalOcc / totalCap : 0;

            return (
              <div
                key={type}
                className="rounded-xl border border-jalapao-border p-4 bg-white/50"
              >
                <div className="flex items-center justify-between mb-3">
                  <span className="font-bold text-jalapao-text">
                    {config.icon} {config.label}
                  </span>
                  <span className="text-xs text-jalapao-text/60 bg-jalapao-terra px-2 py-1 rounded-full">
                    {typePlaces.length} local{typePlaces.length > 1 ? 'is' : ''}
                  </span>
                </div>

                <div className="space-y-2">
                  {typePlaces.map((place) => {
                    const color = occupancyColor(place.occupancyRatio);
                    const pct = Math.min(100, Math.round(place.occupancyRatio * 100));
                    return (
                      <div key={place.id}>
                        <div className="flex justify-between text-xs mb-1">
                          <span
                            className="text-jalapao-text truncate max-w-[60%]"
                            title={place.name}
                          >
                            {place.name}
                          </span>
                          <span className="font-bold" style={{ color }}>
                            {place.currentOccupancy}/{place.capacity_total} {config.unit}
                          </span>
                        </div>
                        <div className="w-full bg-jalapao-border rounded-full h-2">
                          <div
                            className="h-2 rounded-full transition-all duration-500"
                            style={{ width: `${pct}%`, backgroundColor: color }}
                          />
                        </div>
                        {place.avgDurationMinutes !== null && (
                          <div className="text-[10px] text-jalapao-text/50 mt-0.5">
                            ⌛ {Math.round(place.avgDurationMinutes)}min médio
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>

                <div
                  className="mt-3 text-xs font-semibold text-right"
                  style={{ color: occupancyColor(typeRatio) }}
                >
                  Total: {totalOcc}/{totalCap} {config.unit} ({Math.round(typeRatio * 100)}%)
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Fervedouros — Pipeline Fila → Água */}
      {fervedouroData.length > 0 && (
        <div className="premium-card p-6">
          <h2 className="text-lg font-black text-jalapao-text mb-1 uppercase tracking-wide">
            🌊 Fervedouros — Fluxo em Tempo Real
          </h2>
          <p className="text-xs text-jalapao-text/50 mb-5">
            Grupos aguardando na fila e grupos dentro da água agora · atualiza a cada 30s
          </p>
          <div className="space-y-4">
            {fervedouroData.map(({ place, inQueue, inWater, waterPax, queuePax }) => {
              const cap = place.capacity_total || 1;
              const waterRatio = waterPax / cap;
              const waterColor = occupancyColor(waterRatio);
              const waterPct = Math.min(100, Math.round(waterRatio * 100));
              return (
                <div key={place.id} className="rounded-xl border-2 border-jalapao-border bg-white/60 overflow-hidden">
                  {/* Header */}
                  <div className="flex items-center justify-between px-5 py-3 bg-jalapao-terra/30 border-b border-jalapao-border">
                    <span className="font-black text-jalapao-text text-sm">🌊 {place.name}</span>
                    <div className="flex items-center gap-3 text-xs">
                      <span className="text-jalapao-text/50">Cap: <b>{cap}</b> pessoas</span>
                      <span
                        className="font-bold px-2 py-0.5 rounded-full"
                        style={{ color: waterColor, backgroundColor: `${waterColor}18` }}
                      >
                        {waterPax}/{cap} na água ({waterPct}%)
                      </span>
                    </div>
                  </div>

                  {/* Pipeline: Fila → Água */}
                  <div className="grid grid-cols-[1fr_auto_1fr]">
                    {/* Coluna FILA */}
                    <div className="p-4">
                      <div className="flex items-center gap-2 mb-3">
                        <span className="text-amber-500 font-black text-xs uppercase tracking-widest">⏳ Aguardando</span>
                        {queuePax > 0 && (
                          <span className="bg-amber-100 text-amber-700 text-[10px] font-bold px-1.5 py-0.5 rounded-full">
                            {queuePax} pax
                          </span>
                        )}
                      </div>
                      {inQueue.length === 0 ? (
                        <p className="text-xs text-jalapao-text/30 italic">Fila vazia</p>
                      ) : (
                        <div className="space-y-2">
                          {inQueue.map((g) => (
                            <div
                              key={g.id}
                              className="flex items-center justify-between rounded-lg bg-amber-50 border border-amber-200 px-3 py-2"
                            >
                              <div>
                                <div className="text-xs font-semibold text-amber-800 truncate max-w-[120px]">
                                  {g.label}
                                </div>
                                <div className="text-[10px] text-amber-600">{g.pax} pax</div>
                              </div>
                              <div className="text-xs font-black text-amber-600 whitespace-nowrap">
                                {g.waitMin}min
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>

                    {/* Seta central */}
                    <div className="flex items-center justify-center px-2 text-jalapao-text/20">
                      <div className="flex flex-col items-center gap-1">
                        <div className="w-px h-8 bg-jalapao-border" />
                        <span className="text-lg">→</span>
                        <div className="w-px h-8 bg-jalapao-border" />
                      </div>
                    </div>

                    {/* Coluna ÁGUA */}
                    <div className="p-4">
                      <div className="flex items-center gap-2 mb-2">
                        <span className="font-black text-xs uppercase tracking-widest" style={{ color: waterColor }}>
                          💧 Na Água
                        </span>
                        {waterPax > 0 && (
                          <span
                            className="text-[10px] font-bold px-1.5 py-0.5 rounded-full"
                            style={{ color: waterColor, backgroundColor: `${waterColor}18` }}
                          >
                            {waterPax}/{cap}
                          </span>
                        )}
                      </div>
                      {/* Barra de capacidade */}
                      <div className="w-full bg-jalapao-border rounded-full h-1.5 mb-3">
                        <div
                          className="h-1.5 rounded-full transition-all duration-500"
                          style={{ width: `${waterPct}%`, backgroundColor: waterColor }}
                        />
                      </div>
                      {inWater.length === 0 ? (
                        <p className="text-xs text-jalapao-text/30 italic">Ninguém na água</p>
                      ) : (
                        <div className="space-y-2">
                          {inWater.map((g) => {
                            const over = g.stayMin > 30;
                            const warn = g.stayMin > 20;
                            return (
                              <div
                                key={g.id}
                                className={`flex items-center justify-between rounded-lg px-3 py-2 border ${
                                  over
                                    ? 'bg-red-50 border-red-300'
                                    : warn
                                      ? 'bg-orange-50 border-orange-200'
                                      : 'bg-blue-50 border-blue-200'
                                }`}
                              >
                                <div>
                                  <div className={`text-xs font-semibold truncate max-w-[120px] ${over ? 'text-red-800' : warn ? 'text-orange-800' : 'text-blue-800'}`}>
                                    {g.label}
                                  </div>
                                  <div className={`text-[10px] ${over ? 'text-red-600' : warn ? 'text-orange-600' : 'text-blue-600'}`}>
                                    {g.pax} pax
                                  </div>
                                </div>
                                <div className={`text-xs font-black whitespace-nowrap ${over ? 'text-red-600' : warn ? 'text-orange-500' : 'text-blue-600'}`}>
                                  {over ? '🔴' : warn ? '🟡' : ''} {g.stayMin}min
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* 3.2: Histograma de fluxo — usa data do picker histórico */}
      <div className="premium-card p-6">
        <div className="flex items-center justify-between mb-4 flex-wrap gap-2">
          <h2 className="text-lg font-black text-jalapao-text uppercase tracking-wide">
            Fluxo por Horário
            <span className="ml-2 text-sm font-normal text-jalapao-text/50 normal-case">
              {historyDate === today ? 'Hoje' : historyDate}
            </span>
          </h2>
          <div className="flex gap-2 flex-wrap">
            <select
              value={filterType}
              onChange={(e) => setFilterType(e.target.value)}
              className="text-sm border border-jalapao-border rounded-lg px-3 py-1.5 text-jalapao-text bg-white"
            >
              <option value="all">Todos os tipos</option>
              {Object.entries(PLACE_TYPE_CONFIG).map(([k, v]) => (
                <option key={k} value={k}>
                  {v.icon} {v.label}
                </option>
              ))}
            </select>
            <select
              value={filterPlace}
              onChange={(e) => setFilterPlace(e.target.value)}
              className="text-sm border border-jalapao-border rounded-lg px-3 py-1.5 text-jalapao-text bg-white"
            >
              <option value="all">Todos os locais</option>
              {places.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </div>
        </div>
        <ResponsiveContainer width="100%" height={250}>
          <BarChart data={chartData} margin={{ top: 5, right: 20, left: 0, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#D7CCC8" />
            <XAxis dataKey="hour" tick={{ fill: '#5D4037', fontSize: 11 }} />
            <YAxis tick={{ fill: '#5D4037', fontSize: 11 }} />
            <Tooltip
              formatter={(value, name) => [
                typeof value === 'number' ? value : 0,
                name === 'pax' ? 'Visitantes' : 'Visitas',
              ]}
              contentStyle={{
                background: '#FBE9E7',
                border: '1px solid #D7CCC8',
                borderRadius: '0.5rem',
              }}
            />
            <Bar dataKey="pax" name="pax" fill="#D87D4A" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* 3.3: Heatmap semanal dia × hora */}
      <div className="premium-card p-6">
        <h2 className="text-lg font-black text-jalapao-text mb-1 uppercase tracking-wide">
          Heatmap Semanal
        </h2>
        <p className="text-xs text-jalapao-text/50 mb-4">
          Visitantes por hora nos últimos 7 dias · filtros de tipo/local aplicados
        </p>
        {heatmap.maxPax === 0 ? (
          <p className="text-sm text-jalapao-text/40 text-center py-6">
            Sem dados nos últimos 7 dias para o filtro selecionado.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="text-xs w-full border-collapse">
              <thead>
                <tr>
                  <th className="text-left pr-2 pb-1 text-jalapao-text/50 font-semibold w-20">Dia</th>
                  {heatmap.hours.map((h) => (
                    <th key={h} className="text-center pb-1 text-jalapao-text/40 font-normal min-w-[36px]">
                      {h.replace(':00', 'h')}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {heatmap.days.map((day) => (
                  <tr key={day}>
                    <td className="pr-2 py-0.5 text-jalapao-text/70 font-medium whitespace-nowrap">{day}</td>
                    {heatmap.hours.map((hour) => {
                      const val = heatmap.data[day]?.[hour] ?? 0;
                      const ratio = heatmap.maxPax > 0 ? val / heatmap.maxPax : 0;
                      const alpha = val === 0 ? 0 : 0.15 + ratio * 0.85;
                      const textDark = ratio > 0.6;
                      return (
                        <td
                          key={hour}
                          title={`${day} ${hour}: ${val} visitantes`}
                          className="text-center py-0.5 px-0.5 rounded"
                          style={{
                            backgroundColor:
                              val === 0
                                ? 'rgba(215,204,200,0.12)'
                                : ratio >= 0.8
                                  ? `rgba(211,47,47,${alpha})`
                                  : `rgba(216,125,74,${alpha})`,
                            color: textDark ? '#fff' : '#5D4037',
                            fontWeight: val > 0 ? 600 : 400,
                          }}
                        >
                          {val > 0 ? val : ''}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="flex items-center gap-3 mt-3 text-[10px] text-jalapao-text/50">
              <span>Escala:</span>
              {[0.1, 0.3, 0.5, 0.7, 0.9].map((r) => (
                <span key={r} className="flex items-center gap-1">
                  <span
                    className="inline-block w-4 h-4 rounded"
                    style={{
                      backgroundColor:
                        r >= 0.8 ? `rgba(211,47,47,${0.15 + r * 0.85})` : `rgba(216,125,74,${0.15 + r * 0.85})`,
                    }}
                  />
                  {Math.round(r * heatmap.maxPax)}
                </span>
              ))}
              <span className="ml-1">visitantes/hora</span>
            </div>
          </div>
        )}
      </div>

      {/* Origem dos Visitantes */}
      {originCityData.length > 0 && (
        <div className="premium-card p-6">
          <h2 className="text-lg font-black text-jalapao-text mb-1 uppercase tracking-wide">
            Origem dos Visitantes
          </h2>
          <p className="text-xs text-jalapao-text/50 mb-4">
            Cidades informadas hoje · todas as fontes de dados
          </p>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={originCityData} layout="vertical" margin={{ top: 0, right: 24, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#D7CCC8" horizontal={false} />
              <XAxis type="number" tick={{ fill: '#5D4037', fontSize: 11 }} allowDecimals={false} />
              <YAxis
                type="category"
                dataKey="city"
                width={110}
                tick={{ fill: '#5D4037', fontSize: 11 }}
              />
              <Tooltip
                formatter={(value) => [typeof value === 'number' ? value : 0, 'Visitantes']}
                contentStyle={{ background: '#FBE9E7', border: '1px solid #D7CCC8', borderRadius: '0.5rem' }}
              />
              <Bar dataKey="pax" name="pax" fill="#00ACC1" radius={[0, 4, 4, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Active visits + reservations table */}
      {activeRows.length > 0 && (
        <div className="premium-card p-6">
          <h2 className="text-lg font-black text-jalapao-text mb-4 uppercase tracking-wide">
            Visitas Ativas Agora
          </h2>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b-2 border-jalapao-border text-jalapao-text/60 text-xs uppercase">
                  <th className="text-left py-2 pr-4">Local</th>
                  <th className="text-left py-2 pr-4">Tipo</th>
                  <th className="text-left py-2 pr-4">Grupo</th>
                  <th className="text-center py-2 pr-4">Visitantes</th>
                  <th className="text-center py-2 pr-4">Entrada</th>
                  <th className="text-center py-2 pr-4">Tempo Ativo</th>
                  <th className="text-center py-2">Ocupação</th>
                </tr>
              </thead>
              <tbody>
                {activeRows.map((row) => {
                  const elapsedMin = Math.floor((Date.now() - row.arrivalTime.getTime()) / 60000);
                  const config = PLACE_TYPE_CONFIG[row.place.type as PlaceType];
                  const color = occupancyColor(row.place.occupancyRatio);
                  return (
                    <tr
                      key={row.id}
                      className="border-b border-jalapao-border hover:bg-jalapao-terra/40"
                    >
                      <td className="py-2 pr-4 font-medium text-jalapao-text">{row.place.name}</td>
                      <td className="py-2 pr-4 text-jalapao-text/70">
                        {config?.icon} {config?.label ?? row.place.type}
                      </td>
                      <td className="py-2 pr-4 text-jalapao-text/60 text-xs">
                        {row.label ? (
                          <span className={`px-2 py-0.5 rounded-full font-semibold ${row.isReservation ? 'bg-jalapao-primary/10 text-jalapao-primary' : 'bg-jalapao-secondary/10 text-jalapao-secondary'}`}>
                            {row.isReservation ? '🏷️' : '👥'} {row.label}
                          </span>
                        ) : (
                          <span className="text-jalapao-text/30">—</span>
                        )}
                      </td>
                      <td className="py-2 pr-4 text-center font-bold text-jalapao-primary">
                        {row.paxQty}
                      </td>
                      <td className="py-2 pr-4 text-center text-jalapao-text/70">
                        {fmtTimeBRT(row.arrivalTime)}
                      </td>
                      <td className="py-2 pr-4 text-center">
                        <span
                          className={`font-bold ${elapsedMin > 60 ? 'text-red-600' : 'text-jalapao-text'}`}
                        >
                          {elapsedMin}min
                        </span>
                      </td>
                      <td className="py-2 text-center">
                        <span className="font-bold" style={{ color }}>
                          {row.place.currentOccupancy}/{row.place.capacity_total}
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Daily history table — place_visits + reservations */}
      <div className="premium-card p-6">
        <div className="flex items-center justify-between mb-4 flex-wrap gap-2">
          <h2 className="text-lg font-black text-jalapao-text uppercase tracking-wide">
            Histórico
          </h2>
          <div className="flex items-center gap-2 flex-wrap">
            <input
              type="date"
              value={historyDate}
              onChange={(e) => setHistoryDate(e.target.value)}
              className="text-sm border border-jalapao-border rounded-lg px-3 py-1.5 text-jalapao-text bg-white"
            />
            <button
              onClick={() => {
                // place_visits rows
                const visitRows = historyVisits.map((v) => {
                  const p = places.find((pl) => pl.id === v.place_id);
                  const dur = v.exit_time
                    ? Math.floor((pbDate(v.exit_time).getTime() - pbDate(v.arrival_time).getTime()) / 60000)
                    : '';
                  return [
                    v.arrival_time,
                    p?.name ?? v.place_id,
                    p?.type ?? '',
                    '',
                    v.pax_qty,
                    v.exit_time ?? '',
                    dur,
                    v.status,
                  ].join(',');
                });
                // reservation rows
                const resRows = historyReservations.map((r) => {
                  const p = places.find((pl) => pl.id === r.place_id);
                  const arrival = r.arrival_time ?? r.scheduled_time;
                  const dur =
                    r.arrival_time && r.exit_time
                      ? Math.floor((pbDate(r.exit_time).getTime() - pbDate(r.arrival_time).getTime()) / 60000)
                      : '';
                  return [
                    arrival,
                    p?.name ?? r.place_id,
                    p?.type ?? '',
                    r.guest_name,
                    r.pax_qty,
                    r.exit_time ?? '',
                    dur,
                    r.status,
                  ].join(',');
                });
                const csv = [
                  'Entrada,Local,Tipo,Grupo,Visitantes,Saida,Duracao_min,Status',
                  ...visitRows,
                  ...resRows,
                ].join('\n');
                const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `places_${historyDate}.csv`;
                a.click();
              }}
              className="flex items-center gap-2 px-4 py-2 bg-jalapao-secondary hover:bg-jalapao-secondary/90 text-white rounded-xl font-bold text-sm transition-all"
            >
              Exportar CSV
            </button>
          </div>
        </div>
        <div className="text-xs text-jalapao-text/50 mb-3">
          {historyVisits.length + historyReservations.length} registro{(historyVisits.length + historyReservations.length) !== 1 ? 's' : ''} em {historyDate}
          {historyReservations.length > 0 && (
            <span className="ml-2 text-jalapao-primary">
              ({historyReservations.length} reserva{historyReservations.length > 1 ? 's' : ''})
            </span>
          )}
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b-2 border-jalapao-border text-jalapao-text/60 text-xs uppercase">
                <th className="text-left py-2 pr-3">Entrada</th>
                <th className="text-left py-2 pr-3">Local</th>
                <th className="text-left py-2 pr-3">Tipo</th>
                <th className="text-left py-2 pr-3">Grupo</th>
                <th className="text-center py-2 pr-3">Pax</th>
                <th className="text-center py-2 pr-3">Saída</th>
                <th className="text-center py-2 pr-3">Duração</th>
                <th className="text-center py-2">Status</th>
              </tr>
            </thead>
            <tbody>
              {/* place_visits */}
              {historyVisits.map((v) => {
                const p = places.find((pl) => pl.id === v.place_id);
                const config = p ? PLACE_TYPE_CONFIG[p.type as PlaceType] : null;
                const dur = v.exit_time
                  ? Math.floor((pbDate(v.exit_time).getTime() - pbDate(v.arrival_time).getTime()) / 60000)
                  : null;
                return (
                  <tr
                    key={`pv-${v.id}`}
                    className="border-b border-jalapao-border hover:bg-jalapao-terra/40"
                  >
                    <td className="py-1.5 pr-3 text-jalapao-text/70">{fmtTime(v.arrival_time)}</td>
                    <td className="py-1.5 pr-3 font-medium text-jalapao-text">
                      {p?.name ?? v.place_id}
                    </td>
                    <td className="py-1.5 pr-3 text-jalapao-text/70">
                      {config ? `${config.icon} ${config.label}` : '—'}
                    </td>
                    <td className="py-1.5 pr-3 text-xs">
                      {v.group_name ? (
                        <span className="text-jalapao-text/70">{v.group_name}</span>
                      ) : (
                        <span className="text-jalapao-text/30">—</span>
                      )}
                      {v.origin_city && (
                        <span className="ml-1 text-jalapao-text/40">· {v.origin_city}</span>
                      )}
                    </td>
                    <td className="py-1.5 pr-3 text-center font-bold text-jalapao-primary">
                      {v.pax_qty}
                    </td>
                    <td className="py-1.5 pr-3 text-center text-jalapao-text/70">
                      {fmtTime(v.exit_time)}
                    </td>
                    <td className="py-1.5 pr-3 text-center text-jalapao-text/70">
                      {dur !== null ? `${dur}min` : '—'}
                    </td>
                    <td className="py-1.5 text-center">
                      <span
                        className={`px-2 py-0.5 rounded-full text-xs font-bold ${
                          v.status === 'visiting'
                            ? 'bg-jalapao-secondary/15 text-jalapao-secondary'
                            : 'bg-jalapao-border text-jalapao-text/60'
                        }`}
                      >
                        {v.status === 'visiting' ? 'Ativo' : 'Concluído'}
                      </span>
                    </td>
                  </tr>
                );
              })}
              {/* reservations */}
              {historyReservations.map((r) => {
                const p = places.find((pl) => pl.id === r.place_id);
                const config = p ? PLACE_TYPE_CONFIG[p.type as PlaceType] : null;
                const arrival = r.arrival_time ?? r.scheduled_time;
                const dur =
                  r.arrival_time && r.exit_time
                    ? Math.floor((pbDate(r.exit_time).getTime() - pbDate(r.arrival_time).getTime()) / 60000)
                    : null;
                const statusLabel: Record<string, string> = {
                  reserva: 'Reservado',
                  no_local: 'No Local',
                  concluida: 'Concluído',
                  cancelada: 'Cancelado',
                };
                const statusColor: Record<string, string> = {
                  reserva: 'bg-blue-100 text-blue-700',
                  no_local: 'bg-jalapao-secondary/15 text-jalapao-secondary',
                  concluida: 'bg-jalapao-border text-jalapao-text/60',
                  cancelada: 'bg-red-100 text-red-600',
                };
                return (
                  <tr
                    key={`res-${r.id}`}
                    className="border-b border-jalapao-border hover:bg-jalapao-terra/40 bg-jalapao-primary/5"
                  >
                    <td className="py-1.5 pr-3 text-jalapao-text/70">{fmtTime(arrival)}</td>
                    <td className="py-1.5 pr-3 font-medium text-jalapao-text">
                      {p?.name ?? r.place_id}
                    </td>
                    <td className="py-1.5 pr-3 text-jalapao-text/70">
                      {config ? `${config.icon} ${config.label}` : '—'}
                    </td>
                    <td className="py-1.5 pr-3 text-xs text-jalapao-primary font-semibold">
                      🏷️ {r.guest_name || '—'}
                      {r.origin_city && (
                        <span className="ml-1 text-jalapao-text/40 font-normal">· {r.origin_city}</span>
                      )}
                    </td>
                    <td className="py-1.5 pr-3 text-center font-bold text-jalapao-primary">
                      {r.pax_qty}
                    </td>
                    <td className="py-1.5 pr-3 text-center text-jalapao-text/70">
                      {fmtTime(r.exit_time)}
                    </td>
                    <td className="py-1.5 pr-3 text-center text-jalapao-text/70">
                      {dur !== null ? `${dur}min` : '—'}
                    </td>
                    <td className="py-1.5 text-center">
                      <span
                        className={`px-2 py-0.5 rounded-full text-xs font-bold ${statusColor[r.status] ?? ''}`}
                      >
                        {statusLabel[r.status] ?? r.status}
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
