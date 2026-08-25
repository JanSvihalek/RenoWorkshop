/// Provedený nebo plánovaný úkon na zakázce.
class WorkItem {
  const WorkItem({
    required this.id,
    required this.title,
    required this.isDone,
    this.estimatedHours,
  });

  final String id;
  final String title;

  /// `true` = provedeno, `false` = plánováno.
  final bool isDone;

  /// Normohodiny podle sazebníku, pokud jsou známé.
  final double? estimatedHours;

  WorkItem copyWith({bool? isDone}) => WorkItem(
    id: id,
    title: title,
    isDone: isDone ?? this.isDone,
    estimatedHours: estimatedHours,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkItem && other.id == id && other.isDone == isDone);

  @override
  int get hashCode => Object.hash(id, isDone);
}
