// 28 huruf hijaiyah standar. Indeks (1-28) dipakai firmware untuk nama folder
// dan file; nama Latin + glyph cuma untuk tampilan. Harus sama dengan array
// HURUF di web_ui.ino (INDEX_HTML).
class Huruf {
  const Huruf(this.index, this.name, this.glyph);

  final int index;
  final String name;
  final String glyph;

  String get label => '$name ($glyph)';
}

const List<Huruf> hurufList = [
  Huruf(1, 'Alif', 'ا'),
  Huruf(2, 'Ba', 'ب'),
  Huruf(3, 'Ta', 'ت'),
  Huruf(4, 'Tsa', 'ث'),
  Huruf(5, 'Jim', 'ج'),
  Huruf(6, 'Ha', 'ح'),
  Huruf(7, 'Kha', 'خ'),
  Huruf(8, 'Dal', 'د'),
  Huruf(9, 'Dzal', 'ذ'),
  Huruf(10, 'Ra', 'ر'),
  Huruf(11, 'Zay', 'ز'),
  Huruf(12, 'Sin', 'س'),
  Huruf(13, 'Syin', 'ش'),
  Huruf(14, 'Shad', 'ص'),
  Huruf(15, 'Dhad', 'ض'),
  Huruf(16, 'Tha', 'ط'),
  Huruf(17, 'Zha', 'ظ'),
  Huruf(18, "'Ain", 'ع'),
  Huruf(19, 'Ghain', 'غ'),
  Huruf(20, 'Fa', 'ف'),
  Huruf(21, 'Qaf', 'ق'),
  Huruf(22, 'Kaf', 'ك'),
  Huruf(23, 'Lam', 'ل'),
  Huruf(24, 'Mim', 'م'),
  Huruf(25, 'Nun', 'ن'),
  Huruf(26, 'Waw', 'و'),
  Huruf(27, 'Ha', 'ه'),
  Huruf(28, 'Ya', 'ي'),
];

Huruf hurufByIndex(int index) => hurufList[index - 1];
