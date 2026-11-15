# Infectados

Datos en `data/creatures.json`; modelos, ropa teñida y posturas en `scripts/world/infected.gd`;
habilidades en `scripts/world/creature.gd` (`_special_ai`) y efectos en `scripts/world/hazard.gd`.

| Tipo | Vida | Vel. | Daño | Habilidad | Dónde |
|---|---|---|---|---|---|
| Infectado común | 45 | 2,3 | 8 / 1,2 s | Da la alarma a los infectados a 7 m al verte. | Refugio, bosque, noche |
| Corredora | 28 | 5,3 | 6 / 0,7 s | Te ve desde 13 m y embiste al acercarse. | Bosque, refugio, noche (bosque) |
| Hinchado | 170 | 1,6 | 20 / 2 s | Golpe que te lanza hacia atrás; la sorpresa solo hace x1,5. | Cantera |
| Minero | 60 | 2,2 | 10 / 1,3 s | Casco: sorpresa x2. Avisa a su cuadrilla (6 m). | Cantera, noche (cantera) |
| Gritona | 30 | 3,2 | — | No ataca. Grita cada 9 s y llama a todos los infectados a 22 m; huye si te acercas. | Bosque, cantera |
| Acechador | 40 | 3,6 | 10 / 1,1 s | De noche es invisible a más de 6 m. Salta desde 5,5 m con daño doble. | Bosque, noche (bosque) |
| Purulento | 55 | 1,9 | 9 / 1,4 s | Al morir revienta: nube de veneno de 3 m durante 5 s. | Refugio, cantera |
| Blindado | 90 | 2,0 | 12 / 1,4 s | De frente recibe un 70 % menos; por la espalda, daño completo. | Cantera |
| Coloso (jefe) | 600 | 1,5 | 30 / 2,2 s | Pisotón de 4 m con aviso rojo y rocas a 7–16 m con sombra. Reaparece a los 15 min. | Cantera (pasará al Puesto militar) |

Tú: 4,5 andando, 6,75 corriendo. Esquivar evita golpes, saltos, pisotones y rocas.
