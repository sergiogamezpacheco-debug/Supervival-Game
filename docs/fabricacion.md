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

## Hoguera
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Carbón | Troncos 3 | 1 |
| Carne asada | Carne cruda 1 | 1 |

## Banco de carpintería
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Tablón | Troncos 2 | 3 |
| Mango de herramienta | Troncos 2 | 3 |
| Viga reforzada | Tablón 3, Chatarra 1 | 8 |

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
| Hacha de hierro | Mango de herramienta 1, Lingote de hierro 2, Cuerda 1 | 10 |
| Pico de hierro | Mango de herramienta 1, Lingote de hierro 3, Cuerda 1 | 10 |
| Componentes | Chatarra 4 | 18 |

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
| Chaqueta de piel | Cuero curtido 3, Tela resistente 2, Cuerda 1 | 10 |
| Pantalón cargo | Tela resistente 4, Cuerda 2, Cuero curtido 1 | 12 |
| Botas de piel | Cuero curtido 2, Cuerda 2, Tablón 1 | 12 |
| Chaleco táctico | Tela resistente 3, Acero forjado 2, Cuerda 3 | 18 |
| Mochila de excursión | Mochila de lona 1, Cuero curtido 3, Tela resistente 4, Cuerda 4 | 16 |
| Mochila táctica | Mochila de excursión 1, Tela resistente 6, Cuero curtido 4, Acero forjado 2, Componentes 2 | 25 |

## Mesa de cantería
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Bloque de piedra | Piedra bruta 3 | 5 |

## Secadero de alimentos
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Carne seca | Carne cruda 2 | 7 |

## Mesa médica
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Vendas simples x2 | Tela 2, Fibra vegetal 1 | 16 |
| Botiquín | Vendas simples 2, Seta 2, Tela 1 | 16 |
| Antídoto | Seta 2, Bayas 2, Azufre 1 | 16 |

## Huerto
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Bayas x6 | Bayas 2 | 14 |
| Seta x4 | Seta 1 | 14 |
| Fibra vegetal x8 | Fibra vegetal 2 | 14 |

## Recicladora
| Resultado | Ingredientes | Nivel |
|---|---|---|
| Componentes x2 | Chatarra 4 | 22 |
| Lingote de hierro | Chatarra 3 | 22 |
| Lingote de cobre | Componentes 2 | 22 |

## Pendiente (diseños de estaciones)
Cocina de campo, destilería (agua, alcohol, combustible), banco de electrónica y mesa química; molotov, cantimplora y trampa de pinchos.
