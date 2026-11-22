# Fabricación

Camino: **materia prima → procesado → componente → herramienta/arma/ropa**. A mano solo se hace lo
justo para empezar; todo lo demás pide un banco del refugio (como en LDoE, pero con más bancos de por medio).
Pantalla: botón *Fabricar* (`scripts/ui/craft_screen.gd`): todas las recetas en tarjetas; las de banco dicen dónde se hacen.
Datos: `data/recipes.json` (`station` vacío = a mano) y `"tier"` en `data/items.json` (bruto / procesado / componente).


## A mano
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Cuerda | Fibra vegetal 3 | 1 |
| Hacha improvisada | Troncos 5, Piedra bruta 3 | 1 |
| Pico improvisado | Troncos 5, Piedra bruta 5 | 1 |
| Lanza de madera | Troncos 8, Fibra vegetal 2 | 1 |
| Antorcha | Troncos 2, Fibra vegetal 2 | 1 |
| Vendas simples | Tela 2 | 1 |

## Banco de carpintería
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Tablón | Troncos 2 | 3 |
| Mango de herramienta | Troncos 2 | 3 |
| Viga reforzada | Tablón 3, Chatarra 1 | 8 |
| Trampa de pinchos | Tablón 4, Clavos 10, Cuerda 2 | 8 |

## Hoguera
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Carbón | Troncos 3 | 1 |
| Carne asada | Carne cruda 1 | 1 |

## Horno de fundición
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Carbón x2 | Troncos 2 | 6 |
| Lingote de hierro | Mena de hierro 3, Carbón 1 | 6 |
| Lingote de hierro | Mena de hierro 3, Troncos 3 | 6 |
| Lingote de hierro | Chatarra 4, Carbón 1 | 6 |
| Lingote de cobre | Mena de cobre 3, Carbón 1 | 14 |
| Acero forjado | Lingote de hierro 2, Carbón 2 | 12 |

## Banco de trabajo
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Clavos x6 | Chatarra 2 | 2 |
| Clavos x12 | Lingote de hierro 1 | 6 |
| Garrote con clavos | Mango de herramienta 1, Clavos 5 | 3 |
| Hacha de hierro (estación nv 2) | Mango de herramienta 1, Lingote de hierro 2, Cuerda 1 | 10 |
| Pico de hierro (estación nv 2) | Mango de herramienta 1, Lingote de hierro 3, Cuerda 1 | 10 |
| Componentes (estación nv 2) | Chatarra 4 | 18 |

## Banco de armas
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Machete | Acero forjado 2, Mango de herramienta 1, Cuero curtido 1 | 12 |
| Pólvora x2 | Carbón 2, Azufre 1 | 20 |

## Mesa de costura
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Tela resistente | Tela 2, Fibra vegetal 2 | 4 |
| Cuero curtido | Piel 2, Fibra vegetal 1 | 10 |
| Camiseta | Tela resistente 2 | 4 |
| Pantalón de tela | Tela resistente 3, Cuerda 2 | 4 |
| Gorra | Tela resistente 1, Fibra vegetal 3 | 4 |
| Guantes de trabajo | Piel 1, Tela resistente 1, Cuerda 1 | 4 |
| Mochila de lona | Tela resistente 3, Cuerda 3, Piel 3 | 5 |
| Chaqueta de piel (estación nv 2) | Cuero curtido 3, Tela resistente 2, Cuerda 1 | 10 |
| Pantalón cargo (estación nv 2) | Tela resistente 4, Cuerda 2, Cuero curtido 1 | 12 |
| Botas de piel (estación nv 2) | Cuero curtido 2, Cuerda 2, Tablón 1 | 12 |
| Chaleco táctico (estación nv 2) | Tela resistente 3, Acero forjado 2, Cuerda 3 | 18 |
| Mochila de excursión (estación nv 2) | Mochila de lona 1, Cuero curtido 3, Tela resistente 4, Cuerda 4 | 16 |
| Mochila táctica (estación nv 3) | Mochila de excursión 1, Tela resistente 6, Cuero curtido 4, Acero forjado 2, Componentes 2 | 25 |

## Mesa de cantería
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Bloque de piedra | Piedra bruta 3 | 5 |

## Secadero de alimentos
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Carne seca | Carne cruda 2 | 7 |

## Huerto
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Bayas x6 | Bayas 2 | 14 |
| Seta x4 | Seta 1 | 14 |
| Fibra vegetal x8 | Fibra vegetal 2 | 14 |

## Mesa médica
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Vendas simples x2 | Tela 2, Fibra vegetal 1 | 16 |
| Botiquín | Vendas simples 2, Seta 2, Tela 1 | 16 |
| Antídoto | Seta 2, Bayas 2, Azufre 1 | 16 |

## Recicladora · necesita el generador
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Componentes x2 | Chatarra 4 | 22 |
| Lingote de hierro | Chatarra 3 | 22 |
| Lingote de cobre | Componentes 2 | 22 |

## Cocina de campo · arde con leña, carbón o combustible
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Plato cocinado | Carne cruda 2, Seta 1 | 9 |
| Guiso de setas | Seta 4, Agua sucia 1 | 9 |
| Conserva de carne | Carne cruda 3, Lata vacía 1, Sal 1 | 9 |
| Conserva de bayas | Bayas 5, Lata vacía 1, Sal 1 | 9 |
| Sal | Agua sucia 2 | 9 |
| Tarro esterilizado | Tarro de cristal 1, Agua sucia 1 | 9 |
| Conserva de carne | Carne cruda 3, Tarro esterilizado 1 | 9 |
| Conserva de bayas | Bayas 5, Tarro esterilizado 1 | 9 |
| Agua hervida | Agua sucia 1 | 9 |
| Cantimplora vacía | Lingote de hierro 1, Cuero curtido 1, Cuerda 1 | 9 |
| Cantimplora | Cantimplora vacía 1, Agua sucia 2 | 9 |

## Destilería · arde con leña, carbón o combustible
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Agua purificada | Agua sucia 2 | 11 |
| Alcohol | Bayas 6, Agua purificada 1 | 11 |
| Carbón x3 | Troncos 3 | 11 |
| Combustible (estación nv 2) | Alcohol 2, Carbón 2 | 13 |

## Banco de electrónica · necesita el generador
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Cable de cobre x4 | Lingote de cobre 1 | 23 |
| Circuito básico | Componentes 2, Cable de cobre 2 | 23 |
| Circuito avanzado | Circuito básico 2, Cable de cobre 3, Lingote de cobre 1 | 23 |
| Batería | Lingote de cobre 1, Ácido 1, Componentes 1 | 23 |

## Mesa química · necesita el generador
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Vendas avanzadas x2 | Tela resistente 1, Alcohol 1 | 21 |
| Antídoto x2 | Agua purificada 1, Seta 2 | 21 |
| Estimulante | Agua purificada 1, Bayas 3, Azufre 1 | 21 |
| Cóctel molotov | Botella vacía 1, Combustible 1, Tela 1 | 21 |
| Ácido | Azufre 2, Agua purificada 1 | 21 |

## Mecánicas
- **Fuego propio** (cocina de campo y destilería): pestaña *Fuego* para echar troncos (1 min), carbón (3 min) o
  combustible (10 min); lo que fabricas gasta el fuego que dura. La barra *Energía* (llama) es ese fuego (máx. 30 min).
- **Generador** (mesa química, banco de electrónica, recicladora): barra *Energía* con la batería. El combustible le da 20 min.
- **Agua**: el recolector llena botellas vacías (10 de agua cada una) → *agua sucia* (sed +15, vida −4). Se hierve en la
  cocina (agua hervida, +30) o se destila (agua purificada, +45, base de medicinas). Las botellas, la cantimplora y el
  agua dejan el envase vacío al beber.
- **Cantimplora**: se hace vacía en la cocina y se llena con 2 de agua sucia (que hierve); da +60 y vuelve vacía.
- **Cóctel molotov**: se equipa como arma; el botón dice *Lanzar* y apunta al enemigo más cercano a menos de 11 m.
  Deja un charco de fuego de 2,6 m que quema 14 por segundo durante 5 s (a ti no te quema).
- **Trampa de pinchos**: desde el inventario, *Colocar* (delante de ti). Hace 40 a lo que la pise (una vez por criatura
  cada 1,2 s) y aguanta 4 golpes; con enemigos lejos se puede *Recoger* con los golpes que le queden. Se guarda por zona.
- **Comida que caduca** (tiempo real, también con el juego cerrado y dentro de los cofres): carne cruda 48 h,
  carne asada 72 h, plato cocinado y guiso 5 días, bayas y setas 5 días, carne seca 7 días. Al juntar un montón se queda la
  fecha de la más vieja; caducada se vuelve *comida podrida* (vida −10). En el inventario pone cuánto le queda.
- **Conservas (no caducan)**: en la cocina, lata vacía + **sal** (sale de hervir 2 de agua sucia) o un **tarro de
  cristal esterilizado** (tarro + agua sucia hervidos). Latas y tarros salen en cofres, taquillas y cajas.
- **Recolectar con herramienta**: pinos solo con hacha; rocas y vetas solo con pico. A mano: ramas secas (madera),
  piedras sueltas (piedra), hierba, arbustos, setas y restos metálicos. El botón muestra la herramienta que toca
  (en gris si no la llevas).
- **Pendiente**: pestaña *Dispositivos* del banco de electrónica (linterna táctica, alarma de movimiento, torreta),
  que usarán los circuitos y baterías.
