// Glossário UI vs banco (IDEA.md §3): UI usa "cômodo", banco usa `rooms`.
// Tamanho categórico P/M/G (IDEA.md §5.2).
enum RoomSize {
  p('P', 'até 6m²'),
  m('M', '6–12m²'),
  g('G', 'acima de 12m²');

  const RoomSize(this.label, this.hint);

  final String label;
  final String hint;
}
