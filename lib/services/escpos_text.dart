/// esc_pos_utils abre cada línea con `ESC $ 0 0` (posición absoluta 0). En una
/// impresora normal no hace nada, pero la 480BL (cabezal 4" con área de 80 mm
/// centrada) lo cuenta desde el borde del cabezal y saca el texto del papel.
List<int> withoutAbsolutePosition(List<int> line) => line.length >= 4 &&
        line[0] == 0x1b &&
        line[1] == 0x24 &&
        line[2] == 0 &&
        line[3] == 0
    ? line.sublist(4)
    : line;
