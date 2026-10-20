class Location {
  final int id;
  final String code;
  final String zone;
  final int capacity;
  final int used;
  final int itemCount;

  const Location(this.id, this.code, this.zone, this.capacity,
      {this.used = 0, this.itemCount = 0});

  int get free => capacity - used;
  double get fill => capacity == 0 ? 0 : used / capacity;

  Location copyWith({int? used, int? itemCount}) => Location(
      id, code, zone, capacity,
      used: used ?? this.used, itemCount: itemCount ?? this.itemCount);
}
