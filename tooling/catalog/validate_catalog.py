#!/usr/bin/env python3
"""Pré-validador fail-closed do catálogo editorial jalapao_serras_2026.

Verifica o dataset contra o JSON Schema contratual e as regras de segurança
editorial: tudo draft, sem coordenadas/capacidades, sem vínculo operacional,
sem PII, fotos somente com licença explícita e proveniência íntegra (SHA-256).

Sem opção --apply nem qualquer escrita: somente leitura, exit 1 em qualquer falha.
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from jsonschema_lite import validate  # noqa: E402

DATASET_DIR = Path(__file__).resolve().parents[2] / "data" / "catalog" / "jalapao_serras_2026"
SCHEMA_FILE = Path(__file__).resolve().parents[2] / "docs" / "contracts" / "catalog" / "catalog_review_v1.schema.json"
SOURCE_FILE = DATASET_DIR / "source" / "jalapao_catalogo_62_mais_anteriores.json"
EXPECTED_SHA256 = "8000419b79b040b7c934a4eb059d7991f4878ad85290db29336ef741272d5a23"

PII_KEYS = {"owner_name", "cpf", "telefone", "phone", "email", "e_mail", "endereco", "documento"}
EMAIL_RE = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")


def _find_forbidden(obj, path="$"):
    hits = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k.lower() in PII_KEYS:
                hits.append(f"{path}.{k}: chave de PII não permitida")
            hits += _find_forbidden(v, f"{path}.{k}")
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            hits += _find_forbidden(v, f"{path}[{i}]")
    elif isinstance(obj, str) and EMAIL_RE.search(obj):
        hits.append(f"{path}: possível e-mail em valor de string")
    return hits


def business_rules(dataset):
    """Regras além do schema: bloqueiam publicação/vínculo/foto sem revisão."""
    errs = []
    records = dataset.get("records", [])
    keys = [r.get("external_key") for r in records]
    if len(keys) != len(set(keys)):
        errs.append("external_key duplicada no dataset")
    nums = sorted(r["map_number"] for r in records if r.get("map_number") is not None)
    if nums != list(range(1, 63)):
        errs.append(f"cobertura do mapa 1..62 quebrada: {nums}")

    for i, r in enumerate(records):
        p = f"records[{i}]({r.get('external_key')})"
        if r.get("editorial_state") != "draft":
            errs.append(f"{p}: editorial_state != draft -> publicação bloqueada")
        if r.get("operational_binding") is not None or r.get("visit_authorized") is not None:
            errs.append(f"{p}: vínculo operacional não permitido")
        loc = r.get("location", {})
        if loc.get("latitude") is not None or loc.get("longitude") is not None or loc.get("google_place_id") is not None:
            errs.append(f"{p}: geocoordenada/place_id presente sem evidência verificada")
        media = r.get("media", {})
        status = media.get("photo_status")
        if media.get("photo") is not None:
            if status != "foto_licenciada":
                errs.append(f"{p}: foto associada com photo_status={status} -> revisão obrigatória")
            else:
                for f in ("author", "license", "url"):
                    if not media["photo"].get(f):
                        errs.append(f"{p}: foto licenciada sem {f}")
        if status == "galeria_institucional_uso_pendente" and media.get("photo") is not None:
            errs.append(f"{p}: galeria institucional não pode ter foto embutida")
        if r.get("equivalence", {}).get("counterpart_key") is not None:
            errs.append(f"{p}: equivalência resolvida automaticamente é proibida")

    gf = dataset.get("generated_from", {})
    if not SOURCE_FILE.exists():
        errs.append("fonte original ausente")
    else:
        sha = hashlib.sha256(SOURCE_FILE.read_bytes()).hexdigest()
        if sha != EXPECTED_SHA256 or gf.get("sha256") != sha:
            errs.append("proveniência quebrada: SHA-256 da fonte diverge")
    errs += _find_forbidden(dataset)
    return errs


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dataset", default=str(DATASET_DIR / "catalog_review_v1.json"))
    ap.add_argument("--jsonl", default=str(DATASET_DIR / "catalog_review_v1.jsonl"))
    args = ap.parse_args()  # --apply não existe: argparse falha em opção desconhecida

    schema = json.loads(SCHEMA_FILE.read_text())
    dataset = json.loads(Path(args.dataset).read_text())
    errors = validate(dataset, schema)
    errors += business_rules(dataset)

    record_schema = {"$ref": "#/$defs/record", "$defs": schema.get("$defs", {})}
    lines = Path(args.jsonl).read_text().splitlines()
    if len(lines) != len(dataset.get("records", [])):
        errors.append(f"jsonl: {len(lines)} linhas != {len(dataset['records'])} registros")
    for i, line in enumerate(lines):
        rec = json.loads(line)
        errors += [f"jsonl[{i}]{e[1:]}" for e in validate(rec, record_schema, record_schema)]
        if rec != dataset["records"][i]:
            errors.append(f"jsonl[{i}]: diverge do registro {i} do JSON")

    if errors:
        for e in errors:
            print(f"FAIL {e}", file=sys.stderr)
        print(f"validate_catalog: {len(errors)} falha(s) — dataset bloqueado", file=sys.stderr)
        return 1
    print(f"PASS validate_catalog: {len(dataset['records'])} registros, schema + regras editoriais OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
