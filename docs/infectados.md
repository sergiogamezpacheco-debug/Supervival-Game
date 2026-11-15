# Infectados

## En el juego

| Tipo | Vida | Velocidad | Daño | Habilidad |
|---|---|---|---|---|
| Infectado común | 45 | 2,3 | 8 cada 1,2 s | Da la alarma: al verte avisa a los infectados a 7 m. |
| Corredora | 28 | 5,3 (tú: 4,5 andando, 6,75 corriendo) | 6 cada 0,7 s | Te ve desde 13 m y embiste al acercarse. |
| Hinchado | 170 | 1,6 | 20 cada 2 s | Golpe demoledor que te lanza hacia atrás; la sorpresa solo le hace x1,5. |
| Minero infectado | 60 | 2,2 | 10 cada 1,3 s | Casco: la sorpresa solo hace x2. Avisa a su cuadrilla (6 m). |

Datos en `data/creatures.json`; modelos y posturas en `scripts/world/infected.gd`.

## Prototipos (modelo hecho, sin comportamiento todavía)

| Tipo | Vida | Idea |
|---|---|---|
| Escupidor | 35 | Escupe ácido a 8 m (veneno). Flojo cuerpo a cuerpo: hay que acercarse en zigzag o esquivar. |
| Gritona | 30 | No ataca: al verte grita y atrae a todos los infectados a 20 m. Objetivo prioritario o sigilo. |
| Acechador | 40 | A cuatro patas, casi invisible de noche y entre la hierba. Salta desde 5 m con daño doble. |
| Purulento | 55 | Al morir revienta: nube de veneno de 3 m. Matarlo y esquivar hacia atrás, o con lanza. |
| Blindado | 90 | Placas de chatarra: por delante recibe un 70 % menos. Vulnerable por la espalda. |
| Coloso (jefe) | 600 | Pisotón en área y lanza rocas. Solo en el Puesto militar; pensado para ir muy equipado. |
