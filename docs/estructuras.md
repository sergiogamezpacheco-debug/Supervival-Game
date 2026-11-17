# Estructuras del refugio

Modelos según la lámina `docs/diseno_estructuras.jpg` (`scripts/world/station_models.gd`).
Datos en `data/stations.json`; recetas en `data/recipes.json`.

## Obra por fases

Las estructuras grandes se construyen en varias fases (`"phases"` en `stations.json`):
al colocarlas se paga la primera y quedan **en obra** (con andamio). Tocándolas se abre la lista
de fases con los materiales (tengo/necesito) y el botón **Añadir** para pagar la siguiente.
Cada fase enseña su parte del modelo. Desmontar una obra devuelve la mitad de lo pagado.

| Estructura | Fases | Qué hace |
|---|---|---|
| Banco de armas | Mesa de metal → Tornillo de banco y herramientas | Machete y pólvora |
| Recolector de agua | (de una vez) | Junta 20 de agua por hora, ×4 con lluvia. Se bebe de él |
| Secadero de alimentos | (de una vez) | 2 carne cruda → carne seca (llena 35, sin fuego) |
| Huerto | Cajón → Tierra y abono | Bayas, setas y fibra. Con recolector en el refugio, el doble de rápido |
| Mesa médica | (de una vez) | Vendas, botiquín (cura 60 y veneno), antídoto |
| Generador | Chasis → Motor → Depósito y escape | Carbón (+5 min) o troncos (+1:30) de energía |
| Recicladora | Estructura → Tolva → Cinta y motor | Necesita energía: chatarra → componentes, hierro; componentes → cobre |

Las estaciones que ya había (carpintería, horno, hoguera) usan también los modelos de la lámina.
