#!/usr/bin/env python3
"""Reconciliador read-only: catálogo editorial vs. export sanitizado de places.

Entrada: JSON array [{"id","name","status"}] exportado manualmente do PocketBase
(campos mínimos, sem PII). Saída: relatório de CANDIDATOS a verificação manual.
Nunca escreve no backend, nunca modifica entradas, não possui --apply.
"""
import argparse
import json
import sys
import unicodedata
from pathlib import Path

DATASET_DIR = Path(__file__).resolve().parents[2] / "data" / "catalog" / "jalapao_serras_2026"

STOPWORDS = {"do", "da", "de", "dos", "das", "e", "o", "a"}


def normalize(name: str) -> str:
    nfkd = unicodedata.normalize("NFKD", name.lower())
    return "".join(c for c in nfkd if not unicodedata.combining(c))


def tokens(name: str) -> set:
    return {t for t in normalize(name).replace("-", " ").split() if t not in STOPWORDS}


def similarity(a: str, b: str) -> float:
    if normalize(a) == normalize(b):
        return 1.0
    ta, tb = tokens(a), tokens(b)
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / len(ta | tb)


def load_places(path: str) -> list:
    data = json.loads(Path(path).read_text())
    if not isinstance(data, list):
        raise ValueError("export de places deve ser um array")
    out = []
    for i, p in enumerate(data):
        if set(p) - {"id", "name", "status"} or not {"id", "name", "status"} <= set(p):
            raise ValueError(f"places[{i}]: esperado apenas id/name/status, obtido {sorted(p)}")
        out.append({"id": str(p["id"]), "name": str(p["name"]), "status": str(p["status"])})
    return out


def reconcile(records, places, threshold=0.6):
    candidates = []
    for r in records:
        names = [r["names"]["canonical"]] + r["names"]["aliases"] + ([r["names"]["map"]] if r["names"]["map"] else [])
        best = None
        for p in places:
            score = max(similarity(n, p["name"]) for n in names)
            if score >= threshold and (best is None or score > best["score"]):
                best = {"place_id": p["id"], "place_name": p["name"], "place_status": p["status"], "score": round(score, 3)}
        if best:
            candidates.append({
                "external_key": r["external_key"],
                "catalog_name": r["names"]["canonical"],
                **best,
                "action": "manual_review_required",
            })
    return candidates


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("places_export", help="JSON sanitizado: [{'id','name','status'}]")
    ap.add_argument("--dataset", default=str(DATASET_DIR / "catalog_review_v1.json"))
    ap.add_argument("--out", help="arquivo de saída do relatório (default: stdout)")
    ap.add_argument("--threshold", type=float, default=0.6)
    args = ap.parse_args()  # sem --apply: opção inexistente falha via argparse

    records = json.loads(Path(args.dataset).read_text())["records"]
    places = load_places(args.places_export)
    report = {
        "dataset": "jalapao_serras_2026_review",
        "places_export": Path(args.places_export).name,
        "places_count": len(places),
        "threshold": args.threshold,
        "candidates": reconcile(records, places, args.threshold),
        "disclaimer": "Somente candidatos a verificação manual. Nenhuma escrita executada; nenhum vínculo criado.",
    }
    text = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.out:
        Path(args.out).write_text(text)
        print(f"OK: {len(report['candidates'])} candidato(s) -> {args.out}")
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
