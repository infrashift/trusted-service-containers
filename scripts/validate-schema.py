#!/usr/bin/env python3
"""Validate versions.json against schemas/versions.schema.json.

JSON Schema catches SHAPE (a digest that is not a digest, a track that is not
anchored, a build entry missing its crosscheck block). The rego repo gate
catches MEANING (a track that does not contain its own pin, a lockstep list
that disagrees with the images pointing at it). Both run; neither is redundant.
"""
import json
import sys

try:
    import jsonschema
except ImportError:
    print("error: jsonschema not installed (pip install jsonschema)", file=sys.stderr)
    sys.exit(1)

schema = json.load(open("schemas/versions.schema.json"))
data = json.load(open("versions.json"))

errors = sorted(jsonschema.Draft202012Validator(schema).iter_errors(data),
                key=lambda e: list(e.path))
if errors:
    for e in errors:
        path = "/".join(str(p) for p in e.path) or "<root>"
        print(f"  X {path}: {e.message}", file=sys.stderr)
    print(f"error: versions.json failed schema validation ({len(errors)} error(s))", file=sys.stderr)
    sys.exit(1)

n = len(data.get("images", {}))
mirror = sum(1 for v in data["images"].values() if v["kind"] == "mirror")
print(f"OK: versions.json matches schema ({n} images: {mirror} mirror, {n - mirror} build)")
