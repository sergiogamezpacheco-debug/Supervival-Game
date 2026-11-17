# Supervival — Hoja de ruta

13 de noviembre de 2026 · Lost Anarchy Games

**Principios**
1. **Offline primero.** Todo el juego funciona sin conexión. El online se deja preparado en el código, pero apagado.
2. **Primero un bucle principal divertido, después más contenido.** Recolectar → fabricar → construir → explorar → volver más fuerte.
3. **Monetización justa.** Sin energía que bloquee jugar, sin cajas de botín de pago al azar, y todo lo que da ventaja también se consigue jugando.
4. **Cada versión sale en un APK probado.** Tests automáticos, capturas y Releases en GitHub, trabajando solo desde el móvil.

---

## 1. Dónde estamos (v0.1.4)

| Hecho | Estado |
|---|---|
| Movimiento, recolección con herramientas y durabilidad, inventario, fabricación a mano | ✅ |
| Hambre, sed, vida, veneno, muerte con mochila en el suelo y guardado automático | ✅ |
| Refugio: construcción en cuadrícula (madera/piedra/metal), mejorar y desmontar | ✅ |
| Estaciones con tiempo real (banco, carpintería, cantería, hoguera, horno, costura) y cofres | ✅ |
| Criaturas: infectado, minero, acorazado, víbora, lobo, jabalí, ciervo, conejo | ✅ |
| Viaje entre zonas (coste de comida y agua): Refugio, Bosque, Cantera | ✅ |
| Superviviente low poly realista: creación de personaje (hombre/mujer, 5 opciones de pelo, ojos, nariz, boca, piel y colores) | ✅ |
| Ropa equipable (11 prendas, defensa y desgaste) cosida en la mesa de costura o encontrada | ✅ |
| Inventario a pantalla completa con el superviviente en 3D, 8 bolsillos y 3 niveles de mochila (16/24/32), iconos propios | ✅ |
| Físico que evoluciona (fuerza y resistencia), aguante para correr y gimnasio | ✅ |
| Día y noche de 24 min (infectados nocturnos, linterna), lluvia, sigilo (agacharse, ruido, golpe por sorpresa x3) | ✅ |
| Reparar herramientas (banco) y ropa (costura); barra de vida, números de daño y destello al golpear | ✅ |
| Diseños: mapa antiguo, HUD y tienda · Documentos: zonas y tienda | ✅ |
| HUD con iconos: barras con porcentaje, botones redondos y acción con borde de estado | ✅ |
| Mapa del Valle en papel antiguo dentro del juego, esquivar, sonido (efectos, ambiente, música) y ajustes | ✅ |
| Pinos y rocas facetados; 9 tipos de infectado con habilidades (docs/infectados.md), coloso como jefe | ✅ |
| 611 tests y APK automático | ✅ |
| Materiales del diseño: cobre, cuero, azufre, pólvora y componentes (docs/materiales.md) | ✅ |

---

## 2. Qué enseñan los juegos del género

| Juego | Qué copiar (la mecánica, nunca el arte) | Qué evitar |
|---|---|---|
| **Last Day on Earth** | Historia por actos y misiones que van enseñando el juego; búnkeres de varias plantas con tarjetas; vehículos y mascota para llegar más lejos; día y noche con tiempo atmosférico; pase de temporada a 9,99 € y premium+20 a 19,99 € | Quejas de monetización agresiva e inestabilidad técnica; durabilidad tan baja que obliga a llevar varios juegos de equipo |
| **Grim Soul** | Ambiente muy marcado; castillo como meta de la base; cartas y pergaminos con la historia | La energía que limita las partidas, el grindeo, los anuncios y el desgaste rápido del equipo están entre lo más criticado |
| **Dawn of Zombies** | Las misiones de historia desbloquean funciones poco a poco; suscripción «Golden Status» | Almacenamiento demasiado escaso |
| **Westland Survival** | Encargos del sheriff, recompensas por bandidos, cuevas peligrosas y defender la base de bandidos | — |
| **Prey Day** (online) | — | Los jugadores piden modo sin conexión: el offline es una ventaja |

**Conclusiones para Supervival**
- El **viaje cuesta comida y agua**, no energía de pago. Ya lo tenemos y nos diferencia.
- **Historia por actos** desde el primer minuto: cada misión enseña y desbloquea una función.
- La **durabilidad** debe ser generosa y con **reparación** desde pronto.
- Mucho almacenamiento desde el principio (cofres baratos).
- **Búnker de varias plantas** como contenido estrella (el de Sector 9 y la mina de la Cantera).
- **Pase de temporada + suscripción + packs con contenido fijo**: el modelo que funciona, pero sin presionar.

---

## 3. Fases

### Fase 1 — Pulir el núcleo · ~2–3 semanas
Objetivo: que la **primera hora** enganche.
- HUD definitivo (diseño aprobado) y mapa antiguo dentro del juego.
- ✅ Superviviente propio (sin fantasma), creación de personaje, ropa y gimnasio. Pendiente: modelos 3D buenos de árboles, rocas e infectado.
- ✅ **Día y noche** (de noche hay más infectados) y lluvia.
- ✅ **Sigilo y ruido**: agachado haces golpes críticos y correr atrae a los infectados.
- Combate con más sensación: ✅ golpe, retroceso y barra de vida del enemigo; ✅ esquivar.
- ✅ **Reparar** herramientas y armas en el banco de trabajo (y ropa en la costura).
- Sonido y música (efectos libres y una pista por zona).
- Ajustes: volumen, calidad gráfica, vibración e idioma (es/en).
- **Hecho cuando:** 5 testers juegan 30 minutos sin bloquearse y quieren volver.

### Fase 2 — Progresión e historia · ~3 semanas
- Niveles y experiencia; las recetas se desbloquean por nivel y por planos encontrados.
- **Acto I** de la historia (8–10 misiones) que enseña: fabricar, construir, viajar, cocinar y el primer jefe.
- Misiones diarias, cofre diario, correo del juego y logros.
- **Notificaciones locales**: «tu horno ha terminado», «el mercader tiene artículos nuevos».
- Mina de la Cantera: el **primer búnker** de 3 plantas, con tarjetas y un jefe.
- **Hecho cuando:** hay 3–4 horas de contenido guiado.

### Fase 3 — Economía y tienda (offline) · ~2 semanas
- Chapas y oro, el **mercader** diario y la pantalla de tienda (diseño aprobado).
- **Google Play Billing**: packs con contenido fijo, oro, pase de temporada y suscripción.
- **AdMob** con anuncios con recompensa (acelerar, revivir con la mochila, duplicar botín) y pocos intersticiales.
- Política de privacidad y ficha de seguridad de datos en Play Console.
- **Hecho cuando:** una compra de prueba en Play Console entrega los objetos y sobrevive a reinstalar (restaurar compras).

### Fase 4 — Mundo I: Marisma y Alcorín · ~3 semanas
- **Marisma**: pesca, agua sucia (hervir), arcilla y ladrillo, y los ahogados.
- **Alcorín** (primer pueblo de la Mancomunidad): personajes, comercio, reputación y tablón de misiones.
- **Huerto y gallinero** en el refugio.
- 🚀 **HITO: prueba cerrada en Google Play** (acceso anticipado con testers).

### Fase 5 — Mundo II: Valdecruces y Fuentecalma · ~4 semanas
- **Valdecruces**, zona temporal: hordas, el gritón, farmacia y gasolinera.
- **Armas de fuego y munición**; el disparo hace ruido.
- **Fuentecalma**: hospital, taller, reparaciones e infección.
- **Moto** (viajes más baratos) y **perro** compañero que lleva carga y avisa.
- **Temporada 1**: pase, evento y cosmética.
- 🚀 **HITO: lanzamiento público en Google Play (acceso anticipado).**

### Fase 6 — Final del juego offline · ~5–6 semanas
- **Torreviga** (milicia, armas, entrenamiento) y **Los Cuervos**: asaltan tu refugio (defensa contra la IA).
- **Sector 9**: búnker militar de varias plantas con el Bruto.
- **Trozos de mapa**: los 3 sectores nuevos de las esquinas arrancadas.
- **Supervivientes reclutables**: trabajan en tus estaciones o **te acompañan** en las expediciones.
- **Central Nuclear, versión offline**: la entrada exige **ir en grupo con 2–3 compañeros reclutados** (IA). En el online, esos huecos los ocupan amigos.
- Radiación, traje e iodo, armas especiales y La Madre.

### Fase 7 — Activar el online (cuando haya jugadores)
- Cuenta (Google / Play Games), **guardado en la nube** y paso de un móvil a otro.
- **Cooperativo** para la Central y los búnkeres (2–4 jugadores).
- **Asaltos asíncronos** a refugios de otros jugadores (atacas una copia de su base).
- Clanes, chat y ranking.
- Compras validadas en el servidor y dos monederos separados (offline y online) para evitar trampas.

---

## 4. El online, preparado pero apagado

Desde ya se programa así, sin que el jugador lo note:

| Pieza | Qué hacemos ahora | Para qué servirá |
|---|---|---|
| `data/balance.json → online_enabled: false` | Un interruptor general | Encender el online sin publicar otra versión (Firebase Remote Config) |
| Autoload **`Online`** con `OfflineBackend` | Funciones vacías: `login()`, `upload_save()`, `fetch_raid_target()`… | Se sustituye por `FirebaseBackend` sin tocar el resto del juego |
| **Acciones como comandos** (fabricar, colocar, atacar, comprar) | Cada acción es un objeto serializable | Enviarlas por red y repetir partidas |
| **IDs únicos** para objetos, estructuras y criaturas | Ya existe un formato de guardado; se le añade un `uid` | Sincronizar y detectar duplicados |
| **Guardado versionado** con migraciones | `version` en el archivo y funciones de actualización | Subir y bajar partidas de la nube sin romperlas |
| **Reloj abstracto** `GS.now()` | Ya existe | Usar la hora del servidor (contra trampas de cambiar la hora) |
| **Copia del refugio** exportable (`base.to_list()`) | Ya existe | Asaltos asíncronos |
| **Compañeros IA** con la misma interfaz que un jugador | Fase 6 | Cambiar un compañero IA por un amigo real |

---

## 5. Calendario orientativo

| Fecha | Hito |
|---|---|
| Diciembre 2026 | Fases 1 y 2: núcleo pulido, Acto I y primer búnker |
| Enero 2027 | Fase 3 (tienda) y Fase 4 (Marisma y Alcorín) · **prueba cerrada** |
| Febrero–marzo 2027 | Fase 5 y Temporada 1 · **lanzamiento público en acceso anticipado** |
| Abril–mayo 2027 | Fase 6: Torreviga, Sector 9, Los Cuervos y la Central offline |
| Cuando haya comunidad | Fase 7: online |

Después del lanzamiento: **una actualización al mes** y una **temporada cada 6–8 semanas**.

---

## 6. Riesgos y cómo los cubrimos

| Riesgo | Plan |
|---|---|
| Querer hacerlo todo a la vez | Cada fase tiene su «hecho cuando» y no se empieza la siguiente sin cumplirlo |
| Arte 3D (no hay editor en el móvil) | Modelos .glb libres (Kenney, Quaternius), tu fantasma con Mixamo y estilo low-poly coherente |
| Rendimiento en móviles modestos | Renderer de compatibilidad, pocas luces y una prueba de FPS en cada versión |
| Partida corrupta | Guardado con copia de seguridad y migraciones con tests |
| Monetización mal vista | Packs fijos, sin energía, ofertas sin acoso y todo conseguible jugando |
| Normas de Google Play | Ficha de seguridad de datos, versión de Android objetivo al día, probabilidades visibles si algún día hay sorteos |
| Equilibrio | Valores en JSON, partidas de prueba y ajustes rápidos sin tocar código |

**Cómo trabajamos:** tú pides cambios desde el móvil, yo programo, pruebo (tests y capturas) y GitHub
compila el APK. Las decisiones de diseño grandes las vemos antes en el lienzo de diseño.

---

## 7. Fuentes
- Last Day on Earth: análisis en marlvel.ai; App Store (compras integradas, mascotas y vehículos); levelwinner.com (historia por actos, día y noche, energía); fandom (búnkeres); droidharvest (viaje en tiempo real).
- Grim Soul: gamebrain.co (opiniones sobre la energía y la durabilidad).
- Dawn of Zombies: levelwinner.com (misiones de historia), marlvel.ai (Golden Status).
- Westland Survival: App Store (funciones).
- Prey Day: marlvel.ai (petición de modo offline).
- wayline.io: bucles de retención en juegos de supervivencia.
