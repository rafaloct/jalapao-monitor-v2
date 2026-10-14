"""Subconjunto mínimo de JSON Schema usado pelo pré-validador do catálogo.

Suporta: type, const, enum, required, properties, additionalProperties=false,
items, minItems/maxItems, minLength, pattern, minimum/maximum e $ref local
("#/$defs/..."). Qualquer keyword fora do subconjunto falha fechado.
"""
import re

_SUPPORTED_OBJECT = {"type", "required", "properties", "additionalProperties", "$defs"}
_SUPPORTED_ANY = {"type", "const", "enum", "$ref", "minLength", "pattern", "minimum", "maximum", "minItems", "maxItems", "items", "$defs", "required", "properties", "additionalProperties"}
_TYPE_CHECKS = {
    "object": lambda v: isinstance(v, dict),
    "array": lambda v: isinstance(v, list),
    "string": lambda v: isinstance(v, str),
    "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
    "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "boolean": lambda v: isinstance(v, bool),
    "null": lambda v: v is None,
}


def validate(instance, schema, root=None, path="$"):
    """Retorna lista de erros (strings). Falha fechado em keyword desconhecida."""
    if root is None:
        root = schema
    errors = []
    unknown = set(schema) - _SUPPORTED_ANY - {"$schema", "$id", "title", "description"}
    if unknown:
        return [f"{path}: keywords não suportadas pelo validador: {sorted(unknown)}"]

    if "$ref" in schema:
        types = schema.get("type")
        types = types if isinstance(types, list) else [types]
        if instance is None and "null" in types:
            return []
        ref = schema["$ref"]
        if not ref.startswith("#/$defs/"):
            return [f"{path}: $ref não local não suportada: {ref}"]
        target = root.get("$defs", {}).get(ref.rsplit("/", 1)[-1])
        if target is None:
            return [f"{path}: $ref não resolvida: {ref}"]
        return validate(instance, target, root, path)

    if "type" in schema:
        types = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
        if not any(_TYPE_CHECKS[t](instance) for t in types):
            return [f"{path}: tipo esperado {types}, obtido {type(instance).__name__}"]

    if "const" in schema and instance != schema["const"]:
        errors.append(f"{path}: esperado const {schema['const']!r}, obtido {instance!r}")
    if "enum" in schema and instance not in schema["enum"]:
        errors.append(f"{path}: valor {instance!r} fora do enum {schema['enum']}")

    if isinstance(instance, str):
        if "minLength" in schema and len(instance) < schema["minLength"]:
            errors.append(f"{path}: string menor que minLength={schema['minLength']}")
        if "pattern" in schema and not re.match(schema["pattern"], instance):
            errors.append(f"{path}: {instance!r} não casa com pattern {schema['pattern']}")
    if isinstance(instance, (int, float)) and not isinstance(instance, bool):
        if "minimum" in schema and instance < schema["minimum"]:
            errors.append(f"{path}: {instance} < minimum={schema['minimum']}")
        if "maximum" in schema and instance > schema["maximum"]:
            errors.append(f"{path}: {instance} > maximum={schema['maximum']}")
    if isinstance(instance, list):
        if "minItems" in schema and len(instance) < schema["minItems"]:
            errors.append(f"{path}: menos itens que minItems={schema['minItems']}")
        if "maxItems" in schema and len(instance) > schema["maxItems"]:
            errors.append(f"{path}: mais itens que maxItems={schema['maxItems']}")
        if "items" in schema:
            for i, item in enumerate(instance):
                errors += validate(item, schema["items"], root, f"{path}[{i}]")
    if isinstance(instance, dict):
        for req in schema.get("required", []):
            if req not in instance:
                errors.append(f"{path}: campo obrigatório ausente: {req}")
        props = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            extra = set(instance) - set(props)
            if extra:
                errors.append(f"{path}: campos não permitidos: {sorted(extra)}")
        for key, subschema in props.items():
            if key in instance:
                errors += validate(instance[key], subschema, root, f"{path}.{key}")
    return errors
