'use client';

import { useState } from 'react';
import { RefreshCw, BookOpen, Download, X } from 'lucide-react';
import Link from 'next/link';
import { PlacesTab } from '@/components/PlacesTab';
import pb from '@/lib/pb';
import type { PlaceVisit, Reservation } from '@/lib/types';
import type { LegacyVisit } from '@/lib/places-service';
import { fmtTimeBRT, fmtDateBRT, todayBRT } from '@/lib/tz';

interface BackupRow {
  data: string;
  hora_entrada: string;
  local: string;
  tipo: string;
  colecao: string;
  grupo: string;
  origem: string;
  pax: number;
  hora_saida: string;
  duracao_min: string;
  status: string;
}

function pbDate(s: string | null | undefined): Date {
  if (!s) return new Date(NaN);
  return new Date(s.replace(' ', 'T'));
}

// Usa helpers BRT: datas e horas no CSV refletem horário de Brasília
function fmtDate(d: Date): string { return fmtDateBRT(d); }
function fmtTime(d: Date): string { return fmtTimeBRT(d); }

function toCsv(rows: BackupRow[]): string {
  const header = 'Data,Hora_Entrada,Local,Tipo,Colecao,Grupo,Origem,Pax,Hora_Saida,Duracao_min,Status';
  const lines = rows.map((r) =>
    [
      r.data,
      r.hora_entrada,
      `"${r.local}"`,
      r.tipo,
      r.colecao,
      `"${r.grupo}"`,
      `"${r.origem}"`,
      r.pax,
      r.hora_saida,
      r.duracao_min,
      r.status,
    ].join(','),
  );
  return [header, ...lines].join('\n');
}

async function fetchBackupData(startDate: string, endDate: string): Promise<BackupRow[]> {
  const filter = (field: string) =>
    `${field} >= "${startDate} 00:00:00.000Z" && ${field} <= "${endDate} 23:59:59.999Z"`;

  const [placeVisits, reservations, legacyVisits, places] = await Promise.all([
    pb.collection('place_visits').getFullList<PlaceVisit>({ filter: filter('arrival_time'), sort: 'arrival_time' }).catch(() => [] as PlaceVisit[]),
    pb.collection('reservations').getFullList<Reservation>({ filter: `(${filter('scheduled_time')}) || (${filter('arrival_time')})`, sort: 'scheduled_time' }).catch(() => [] as Reservation[]),
    pb.collection('visits').getFullList<LegacyVisit>({ filter: filter('arrival_time'), sort: 'arrival_time' }).catch(() => [] as LegacyVisit[]),
    pb.collection('places').getFullList<{ id: string; name: string; type: string }>({ filter: 'status = "active"' }).catch(() => [] as { id: string; name: string; type: string }[]),
  ]);

  const placeMap = new Map(places.map((p) => [p.id, p]));
  const rows: BackupRow[] = [];

  for (const v of placeVisits) {
    const p = placeMap.get(v.place_id);
    const arr = pbDate(v.arrival_time);
    const ex = pbDate(v.exit_time ?? undefined);
    const dur = !isNaN(arr.getTime()) && !isNaN(ex.getTime())
      ? String(Math.floor((ex.getTime() - arr.getTime()) / 60000))
      : '';
    rows.push({
      data: fmtDate(arr),
      hora_entrada: fmtTime(arr),
      local: p?.name ?? v.place_id,
      tipo: p?.type ?? '',
      colecao: 'place_visits',
      grupo: v.group_name ?? '',
      origem: v.origin_city ?? '',
      pax: v.pax_qty,
      hora_saida: fmtTime(ex),
      duracao_min: dur,
      status: v.status,
    });
  }

  for (const r of reservations) {
    const p = placeMap.get(r.place_id);
    const arr = pbDate(r.arrival_time ?? r.scheduled_time);
    const ex = pbDate(r.exit_time ?? undefined);
    const dur = r.arrival_time && r.exit_time
      ? String(Math.floor((ex.getTime() - arr.getTime()) / 60000))
      : '';
    rows.push({
      data: fmtDate(pbDate(r.scheduled_time)),
      hora_entrada: fmtTime(arr),
      local: p?.name ?? r.place_id,
      tipo: p?.type ?? '',
      colecao: 'reservations',
      grupo: r.guest_name ?? '',
      origem: r.origin_city ?? '',
      pax: r.pax_qty,
      hora_saida: fmtTime(ex),
      duracao_min: dur,
      status: r.status,
    });
  }

  for (const v of legacyVisits) {
    const arr = pbDate(v.arrival_time);
    const ex = pbDate(v.exit_time ?? undefined);
    const dur = v.entry_time && v.exit_time
      ? String(Math.floor((pbDate(v.exit_time).getTime() - pbDate(v.entry_time).getTime()) / 60000))
      : '';
    rows.push({
      data: fmtDate(arr),
      hora_entrada: fmtTime(arr),
      local: v.atrativo,
      tipo: 'fervedouro',
      colecao: 'visits (legado)',
      grupo: '',
      origem: '',
      pax: v.pax_qty,
      hora_saida: fmtTime(ex),
      duracao_min: dur,
      status: v.status,
    });
  }

  rows.sort((a, b) => (a.data + a.hora_entrada).localeCompare(b.data + b.hora_entrada));
  return rows;
}

function BackupModal({ onClose }: { onClose: () => void }) {
  const today = todayBRT();
  const weekAgo = fmtDateBRT(new Date(Date.now() - 6 * 86400000));
  const [startDate, setStartDate] = useState(weekAgo);
  const [endDate, setEndDate] = useState(today);
  const [loading, setLoading] = useState(false);
  const [rowCount, setRowCount] = useState<number | null>(null);

  async function handleExport() {
    setLoading(true);
    try {
      const rows = await fetchBackupData(startDate, endDate);
      setRowCount(rows.length);
      const csv = toCsv(rows);
      const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `jalapao_backup_${startDate}_${endDate}.csv`;
      a.click();
      URL.revokeObjectURL(url);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl p-8 max-w-md w-full space-y-6">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-black text-jalapao-text uppercase tracking-wide">
            Exportar Backup CSV
          </h2>
          <button onClick={onClose} className="text-jalapao-text/40 hover:text-jalapao-text">
            <X className="w-5 h-5" />
          </button>
        </div>

        <p className="text-sm text-jalapao-text/60">
          Exporta todas as coleções (<code className="bg-gray-100 px-1 rounded">place_visits</code>,{' '}
          <code className="bg-gray-100 px-1 rounded">reservations</code>,{' '}
          <code className="bg-gray-100 px-1 rounded">visits</code>) no intervalo selecionado.
        </p>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-bold text-jalapao-text/60 mb-1 uppercase">
              Data início
            </label>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              className="w-full border border-jalapao-border rounded-lg px-3 py-2 text-sm text-jalapao-text"
            />
          </div>
          <div>
            <label className="block text-xs font-bold text-jalapao-text/60 mb-1 uppercase">
              Data fim
            </label>
            <input
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              className="w-full border border-jalapao-border rounded-lg px-3 py-2 text-sm text-jalapao-text"
            />
          </div>
        </div>

        {rowCount !== null && !loading && (
          <p className="text-sm text-green-700 font-semibold">
            ✅ {rowCount} registros exportados
          </p>
        )}

        <div className="flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-3 border border-jalapao-border rounded-xl text-jalapao-text/60 font-bold hover:bg-gray-50"
          >
            Cancelar
          </button>
          <button
            onClick={handleExport}
            disabled={loading || !startDate || !endDate || startDate > endDate}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-jalapao-primary text-white rounded-xl font-bold disabled:opacity-50 hover:bg-jalapao-primary/90"
          >
            <Download className="w-4 h-4" />
            {loading ? 'Exportando...' : 'Exportar CSV'}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function DashboardPage() {
  const [refreshKey, setRefreshKey] = useState(0);
  const [showBackup, setShowBackup] = useState(false);

  return (
    <main className="min-h-screen p-8 max-w-7xl mx-auto space-y-8 text-jalapao-text">
      <header className="flex flex-col md:flex-row justify-between items-start md:items-end gap-6">
        <div>
          <h1 className="text-4xl font-black tracking-tight text-jalapao-primary uppercase">
            Jalapão Monitor Hub
          </h1>
          <p className="text-jalapao-text/60 mt-2 font-medium">
            Monitoramento de fluxo e capacidade — todos os locais
          </p>
        </div>
        <div className="flex gap-4">
          <button
            onClick={() => setRefreshKey((k) => k + 1)}
            className="p-3 premium-card hover:bg-jalapao-primary/10 text-jalapao-primary"
            title="Forçar atualização completa"
          >
            <RefreshCw className="w-5 h-5" />
          </button>
          <button
            onClick={() => setShowBackup(true)}
            className="flex items-center gap-2 px-4 py-3 bg-white border border-jalapao-border text-jalapao-text font-bold rounded-xl hover:bg-jalapao-terra transition-all shadow-sm"
            title="Exportar backup CSV"
          >
            <Download className="w-5 h-5 text-jalapao-primary" />
            Backup CSV
          </button>
          <Link
            href="/docs"
            className="flex items-center gap-2 px-4 py-3 bg-white border border-jalapao-border text-jalapao-text font-bold rounded-xl hover:bg-jalapao-terra transition-all shadow-sm"
          >
            <BookOpen className="w-5 h-5 text-jalapao-secondary" />
            Docs
          </Link>
        </div>
      </header>

      <PlacesTab key={refreshKey} />

      {showBackup && <BackupModal onClose={() => setShowBackup(false)} />}
    </main>
  );
}
