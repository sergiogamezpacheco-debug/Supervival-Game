# Niveles y experiencia

Datos en `data/levels.json` (curva, experiencia por acción, recompensas). El nivel en el que se
desbloquea cada cosa está en su propio archivo: `"unlock"` en `recipes.json`, `stations.json`,
`structures.json` (por material) y `maps.json` (zonas, con `key_item` si piden un objeto clave).

## Estudio: cómo retener jugadores con la progresión

Lo que dicen los estudios y guías de diseño consultados (resumen propio):

1. **Las primeras horas deciden.** En móvil solo vuelve al día siguiente alrededor de una cuarta parte
   de los jugadores, y la mayoría de abandonos ocurre en la primera sesión. Hay que dar una recompensa
   clara en los primeros minutos: aquí, nivel 2 en ~1 min y nivel 5 en ~15 min.
2. **Curva rápida al principio y cada vez más lenta.** Las curvas lineales se quedan cortas al final
   y las exponenciales crean muros. Se usa una polinómica (exponente 1,85): cada nivel cuesta un poco
   más que el anterior, sin saltos bruscos.
3. **Cada nivel debe traer algo.** Retiene más un objetivo visible ("en el nivel 9, recolector de
   agua") que la experiencia sola. Por eso casi todos los niveles hasta el 25 desbloquean algo, el
   panel de niveles enseña los próximos seis hitos y el aviso de subida dice qué has conseguido.
4. **Hitos que respiran.** Los niveles redondos (10, 20, 30…) cuestan un 15 % menos y traen
   recompensa, igual que el 5, 15 y 25: rompen la monotonía de la parte larga.
5. **Varias formas de progresar.** Se gana experiencia recogiendo, luchando, fabricando, construyendo,
   registrando cajas y explorando zonas nuevas, para que cada estilo de juego avance (en Last Day on
   Earth solo cuentan recoger y luchar).
6. **Feedback inmediato.** "+N" junto a la barra de experiencia en cada acción, y al subir de nivel
   aviso grande con sonido y la vida al máximo.
7. **Puertas con sentido.** Las zonas nuevas se abren por nivel y con un objeto clave (a la cantera
   hay que llevar un pico), para que viajar sea una meta y no solo un botón.
8. **Largo plazo.** Llegar al 100 lleva cientos de horas: es para los jugadores más fieles, y deja sitio
   para ir colocando contenido nuevo (zonas, armas, eventos) en los niveles altos.

Fuentes: Game Developer ("Quantitative design – How to define XP thresholds"), Google Play
("Understanding games that retain", "Why the first ten minutes are crucial"), ironSource LevelUp
("Retention framework"), Abratabia ("Player progression"), wiki de Last Day on Earth.

## Curva

XP para pasar del nivel L al L+1 = `30 + 14 · (L-1)^1,85`, redondeado a 5; el paso que llega a un nivel
redondo cuesta un 15 % menos. El tiempo es aproximado, suponiendo `20 + 1,2·nivel` de experiencia por
minuto (las zonas y enemigos mejores dan más).

| Nivel | XP para subir al siguiente | XP acumulada | Tiempo aprox. de juego |
|---|---|---|---|
| 1 | 30 | 0 | 0 min |
| 2 | 45 | 30 | 1 min |
| 3 | 80 | 75 | 3 min |
| 4 | 135 | 155 | 6 min |
| 5 | 210 | 290 | 12 min |
| 6 | 305 | 500 | 20 min |
| 8 | 540 | 1220 | 46 min |
| 10 | 845 | 2345 | 83 min |
| 12 | 1210 | 4210 | 2 h |
| 15 | 1875 | 8480 | 4 h |
| 20 | 3280 | 20080 | 9 h |
| 25 | 5035 | 39850 | 16 h |
| 30 | 7135 | 68090 | 25 h |
| 40 | 12320 | 159950 | 50 h |
| 50 | 18780 | 308480 | 84 h |
| 60 | 26465 | 526025 | 126 h |
| 70 | 35350 | 824525 | 177 h |
| 80 | 45395 | 1215625 | 237 h |
| 90 | 56590 | 1710705 | 305 h |
| 100 | — | 2320940 | 381 h |

## Experiencia por acción

| Acción | XP |
|---|---|
| Recoger material (por unidad) | 1 (vetas de hierro, carbón, cobre y azufre: 2) |
| Abatir | conejo 3, víbora y ciervo 6, lobo 10, infectado, corredora y jabalí 12, gritona 15, minero, acechador y purulento 18, blindado 30, hinchado 45, coloso 250 |
| Fabricar | 1 por cada 10 s que tarda la receta (mín. 1, máx. 15) |
| Construir | pieza 2, mejorarla 4, estación 20, cada fase de obra 10 |
| Registrar una caja | 3 |
| Primera visita a una zona | 40 |

Al subir de nivel: vida al máximo. Recompensas en los niveles 5, 10, 15, 20, 25, 30 y después en
cada nivel redondo.

## Desbloqueos

| Nivel | Qué se desbloquea |
|---|---|
| 1 | Hacha, pico y lanza de piedra, cuerda, banco de trabajo, hoguera, carne asada, construcción de madera |
| 2 | Cofre, garrote |
| 3 | Carpintería, tablones, **viaje al Bosque** |
| 4 | Mesa de costura, vendas, camiseta, pantalón, gorra, guantes |
| 5 | Mesa de cantería, bloques de piedra, mochila de lona |
| 6 | Horno de fundición, lingotes |
| 7 | Secadero, carne seca, construcción de piedra |
| 8 | **Viaje a la Cantera** (llevando un pico), gimnasio |
| 9 | Recolector de agua |
| 10 | Hacha y pico de hierro, cuero, chaqueta de piel |
| 12 | Banco de armas, machete, botas, pantalón cargo |
| 14 | Huerto y cultivos, lingote de cobre |
| 16 | Mesa médica, botiquín, antídoto, mochila de excursión |
| 18 | Chaleco, componentes |
| 20 | Generador, pólvora, construcción de metal |
| 22 | Recicladora |
| 25 | Mochila táctica |
| 26-100 | Reservado para zonas (Puesto militar…), armas y estructuras nuevas |

Las partidas de antes de los niveles empiezan en el nivel 12.
En los tests (`GS.testing`) se empieza en el nivel 100 para que todo esté abierto; los tests de
bloqueos fijan `GS.level` a mano.

# Peso

Cada objeto tiene `"weight"` (kg por unidad) en `items.json`; las mochilas tienen `"carry"`.
Aguantas 35 kg + 15 por cada punto de fuerza + la mochila (lona 10, excursión 20, táctica 30).
Lo puesto y el arma de la mano también pesan.

- Hasta media carga vas a velocidad normal; de media carga a carga llena, hasta un 25 % más lento.
- Con sobrecarga (más de lo que aguantas) no puedes correr, vas aún más lento y andar cansa.
- Correr gasta 5 de energía por segundo sin carga y hasta 11 con la carga llena (la resistencia lo baja).
- En el inventario: peso del objeto junto al nombre y carga total debajo.
