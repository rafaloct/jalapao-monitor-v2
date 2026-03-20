// ── Places v2.1 ──────────────────────────────────────────────────────────────

export type PlaceType =
  | "fervedouro" | "cachoeira" | "restaurante" | "pousada"
  | "fazenda" | "chacaras" | "loja" | "atrativo_cultural";

export interface Place {
  id: string;
  name: string;
  type: PlaceType;
  latitude: number;
  longitude: number;
  capacity_total: number;
  owner_name: string;
  contact_phone: string;
  status: "pending" | "active" | "rejected" | "archived";
  description: string;
  operating_hours: string;
  created_at_v2: string;
  approved_at: string;
}

export interface PlaceVisit {
  id: string;
  place_id: string;
  pax_qty: number;
  arrival_time: string;
  exit_time: string | null;
  status: "visiting" | "exited" | "queued";
  tablet_id: string;
  notes: string | null;
  group_name?: string | null;
  origin_city?: string | null;
}

export interface Reservation {
  id: string;
  place_id: string;
  pax_qty: number;
  guest_name: string;
  contact_phone: string | null;
  scheduled_time: string;
  arrival_time: string | null;   // momento real do check-in
  exit_time: string | null;      // momento real do check-out
  status: 'reserva' | 'no_local' | 'concluida' | 'cancelada';
  notes: string | null;
  tablet_id: string | null;
  is_estimated: boolean;
  origin_city?: string | null;
}

export interface PlaceWithStats extends Place {
  currentOccupancy: number;
  occupancyRatio: number;
  todayPax: number;
  todayVisitsCount: number;
  avgDurationMinutes: number | null;
}

export const PLACE_TYPE_CONFIG: Record<PlaceType, { label: string; icon: string; unit: string }> = {
  fervedouro:        { label: "Fervedouros",         icon: "🌊", unit: "pessoas" },
  cachoeira:         { label: "Cachoeiras",           icon: "💧", unit: "pessoas" },
  restaurante:       { label: "Restaurantes",         icon: "🍽️",  unit: "mesas"   },
  pousada:           { label: "Pousadas",             icon: "🏨", unit: "camas"   },
  fazenda:           { label: "Fazendas",             icon: "🌾", unit: "grupos"  },
  chacaras:          { label: "Chácaras",             icon: "🏡", unit: "grupos"  },
  loja:              { label: "Lojas",                icon: "🏪", unit: "pessoas" },
  atrativo_cultural: { label: "Atrativos Culturais",  icon: "🎭", unit: "pessoas" },
};

// ── Fervedouros (existing) ────────────────────────────────────────────────────

export interface RecordVisit {
    id: string;
    collectionId: string;
    collectionName: string;
    created: string;
    updated: string;
    pax_qty: number;
    status: 'fila' | 'agua' | 'concluido';
    arrival_time: string;
    entry_time: string | null;
    exit_time: string | null;
    atrativo: string;
    tablet_id: string;
    group_id: string;
    capacity_limit: number;
}

export interface VisitorGroup {
    groupId: string;
    atrativo: string;
    tabletId: string;
    originalArrivalTime: Date;
    totalPax: number;
    capacityLimit: number;
    status: 'fila' | 'agua' | 'concluido' | 'misto';
    fragments: RecordVisit[];
    // Calculated metrics
    averageWaitTimeMin?: number;
    totalStayDurationMin?: number;
}

export interface DashboardMetrics {
    totalVisitors: number;
    averageStayMin: number;
    activeInWater: number;
    avgGroupSize: number;
}
