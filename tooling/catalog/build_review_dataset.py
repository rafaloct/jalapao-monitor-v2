#!/usr/bin/env python3
"""Gera catalog_review_v1.json/.jsonl a partir da fonte editorial versionada.

Determinístico e somente leitura: lê data/catalog/jalapao_serras_2026/source/ e
reescreve os artefatos derivados no diretório do dataset. Não toca backend,
não consulta rede, não aceita --apply nem qualquer modo de escrita externa.
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

DATASET_DIR = Path(__file__).resolve().parents[2] / "data" / "catalog" / "jalapao_serras_2026"
SOURCE_FILE = DATASET_DIR / "source" / "jalapao_catalogo_62_mais_anteriores.json"
OUT_JSON = DATASET_DIR / "catalog_review_v1.json"
OUT_JSONL = DATASET_DIR / "catalog_review_v1.jsonl"

DATASET_VERSION = "catalog_review_v1"
EXPECTED_SHA256 = "8000419b79b040b7c934a4eb059d7991f4878ad85290db29336ef741272d5a23"
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def _fail(msg: str) -> "None":
    print(f"build_review_dataset: ERRO: {msg}", file=sys.stderr)
    sys.exit(1)


def normalize_record(entry: dict, source_meta: dict) -> dict:
    key = entry["id"]
    if not SLUG_RE.match(key):
        _fail(f"external_key inválida: {key!r}")

    map_name = entry.get("nome_no_mapa")
    canonical = entry["nome_canonico"]
    aliases = [map_name] if map_name and map_name != canonical else []

    photo = entry.get("foto")
    media = {
        "photo_status": entry["foto_status"],
        "photo": None,
        "official_gallery_url": entry.get("imagem_pagina_oficial"),
    }
    if photo:
        media["photo"] = {
            "url": photo.get("url"),
            "source_page": photo.get("arquivo_wikimedia"),
            "file_name": photo.get("arquivo"),
            "author": photo.get("autor"),
            "license": photo.get("licenca"),
            "license_url": photo.get("licenca_url"),
            "review_status": photo.get("status"),
            "attribution": photo.get("atribuir"),
            "observation": photo.get("observacao"),
        }

    note = entry.get("nota_validacao")
    return {
        "external_key": key,
        "editorial_state": "draft",
        "map_number": entry.get("numero_no_mapa"),
        "names": {"map": map_name, "canonical": canonical, "aliases": aliases},
        "category": entry.get("categoria"),
        "map_sector": entry.get("setor_do_mapa"),
        "tourism_region": entry.get("recorte_turistico"),
        "municipality": {"name": entry.get("municipio"), "status": entry.get("municipio_status")},
        "cadastre_status": entry.get("status_cadastro"),
        "location": {
            "latitude": entry.get("latitude"),
            "longitude": entry.get("longitude"),
            "google_maps_search_url": entry.get("google_maps_busca"),
            "google_place_id": entry.get("google_place_id"),
        },
        "media": media,
        "sources": {
            "map": entry.get("fonte_mapa"),
            "institutional": entry.get("fonte_institucional_ou_referencia"),
        },
        "equivalence": {"status": entry.get("equivalencia_com_catalogo_anterior"), "counterpart_key": None},
        "validation_notes": [note] if note else [],
        "visit_authorized": entry.get("visita_autorizada"),
        "operational_binding": None,
        "updated_at": entry.get("data_atualizacao"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()  # sem opções de escrita externa; --apply não existe

    raw = SOURCE_FILE.read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    if sha != EXPECTED_SHA256:
        _fail(f"SHA-256 da fonte diverge: {sha} (esperado {EXPECTED_SHA256})")

    src = json.loads(raw)
    meta = {k: src[k] for k in ("titulo", "data", "versao", "status")}
    records = [normalize_record(e, meta) for e in src["atrativos"]]

    counts = {
        "records": len(records),
        "map_points": sum(1 for r in records if r["map_number"] is not None),
        "previous_catalog_only": sum(1 for r in records if r["equivalence"]["status"] == "original_somente"),
        "licensed_photos": sum(1 for r in records if r["media"]["photo_status"] == "foto_licenciada"),
        "institutional_gallery_pending": sum(
            1 for r in records if r["media"]["photo_status"] == "galeria_institucional_uso_pendente"
        ),
        "without_licensed_photo": sum(1 for r in records if r["media"]["photo_status"] == "sem_foto_licenciada"),
    }

    dataset = {
        "$schema": "../../docs/contracts/catalog/catalog_review_v1.schema.json",
        "dataset": "jalapao_serras_2026_review",
        "dataset_version": DATASET_VERSION,
        "editorial_state": "draft",
        "generated_from": {
            "file": "source/jalapao_catalogo_62_mais_anteriores.json",
            "sha256": sha,
            "source_version": meta["versao"],
            "source_date": meta["data"],
        },
        "counts": counts,
        "warnings": list(src.get("alertas", [])),
        "records": records,
    }

    OUT_JSON.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + "\n")
    with OUT_JSONL.open("w") as fh:
        for rec in records:
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    print(f"OK: {len(records)} registros -> {OUT_JSON.name}, {OUT_JSONL.name} (sha256 fonte {sha[:12]}…)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
