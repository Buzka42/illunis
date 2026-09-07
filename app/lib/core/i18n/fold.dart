/// Fold Latin letters with diacritics to ASCII so a dictated "owsiankę"
/// still hits oatmeal. Idempotent; leaves digits and punctuation alone.
String foldLatin(String raw) {
  final b = StringBuffer();
  for (final r in raw.toLowerCase().runes) {
    b.writeCharCode(_fold(r));
  }
  return b.toString();
}

int _fold(int r) {
  switch (r) {
    case 0x00E0: // à
    case 0x00E1: // á
    case 0x00E2: // â
    case 0x00E3: // ã
    case 0x00E4: // ä
    case 0x00E5: // å
    case 0x0105: // ą
      return 0x61; // a
    case 0x00E7: // ç
    case 0x0107: // ć
      return 0x63; // c
    case 0x00E8: // è
    case 0x00E9: // é
    case 0x00EA: // ê
    case 0x00EB: // ë
    case 0x0119: // ę
      return 0x65; // e
    case 0x00EC: // ì
    case 0x00ED: // í
    case 0x00EE: // î
    case 0x00EF: // ï
      return 0x69; // i
    case 0x0142: // ł
      return 0x6C; // l
    case 0x00F1: // ñ
    case 0x0144: // ń
      return 0x6E; // n
    case 0x00F2: // ò
    case 0x00F3: // ó
    case 0x00F4: // ô
    case 0x00F5: // õ
    case 0x00F6: // ö
      return 0x6F; // o
    case 0x00F9: // ù
    case 0x00FA: // ú
    case 0x00FB: // û
    case 0x00FC: // ü
      return 0x75; // u
    case 0x015B: // ś
      return 0x73; // s
    case 0x017A: // ź
    case 0x017C: // ż
      return 0x7A; // z
    default:
      return r;
  }
}
