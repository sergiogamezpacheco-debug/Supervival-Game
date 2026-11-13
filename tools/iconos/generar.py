# Genera los iconos SVG del juego (assets/icons). Ejecutar desde tools/iconos:
#   python3 generar.py
from items2 import ICONS
from items import SLOT
base = '../../assets/icons'
for k, v in ICONS.items():
    open(f'{base}/items/{k}.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64">{v}</svg>\n')
for k, v in SLOT.items():
    open(f'{base}/ui/slot_{k}.svg', 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24" fill="none" stroke="#e9dcb8" stroke-opacity="0.4" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">{v}</svg>\n')
print(len(ICONS), 'iconos')
