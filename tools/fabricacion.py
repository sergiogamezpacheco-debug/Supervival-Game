# Regenera las tablas de docs/fabricacion.md a partir de data/recipes.json.
#   python3 tools/fabricacion.py
# Se conserva el texto de cabecera (hasta "## A mano") y el final (desde "## Mecánicas").
import json, collections

items = json.load(open("data/items.json"))
stations = json.load(open("data/stations.json"))
recipes = json.load(open("data/recipes.json"))
doc = open("docs/fabricacion.md").read()
head = doc[:doc.index("## A mano")]
tail = doc[doc.index("## Mecánicas"):] if "## Mecánicas" in doc else ""

by = collections.OrderedDict()
for r in recipes:
    by.setdefault(r.get("station", ""), []).append(r)
out = [head.rstrip() + "\n"]
for st, rs in by.items():
    title = "A mano" if st == "" else stations[st]["name"]
    extra = ""
    if st and stations[st].get("burns"):
        extra = " · arde con leña, carbón o combustible"
    if st and stations[st].get("power"):
        extra = " · necesita el generador"
    out.append(f"\n## {title}{extra}\n| Resultado | Ingredientes | Nivel |\n|---|---|---|")
    for r in rs:
        name = items[r["result"]]["name"] + (f" x{r['qty']}" if r.get("qty", 1) > 1 else "")
        if r.get("level", 1) > 1:
            name += f" (estación nv {r['level']})"
        cost = ", ".join(f"{items[k]['name']} {v}" for k, v in r["cost"].items())
        out.append(f"| {name} | {cost} | {r.get('unlock', 1)} |")
open("docs/fabricacion.md", "w").write("\n".join(out) + "\n\n" + tail)
