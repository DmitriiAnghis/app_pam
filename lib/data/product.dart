class Product {
  final int id;
  final String sku;
  final String name;
  final String category;
  final String unit;
  final int quantity;
  final int locationId;
  final String imageUrl;

  const Product(this.id, this.sku, this.name, this.category, this.unit,
      this.quantity, this.locationId, this.imageUrl);

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        j['id'] as int,
        j['sku'] as String,
        j['name'] as String,
        j['category'] as String? ?? '',
        j['unit'] as String? ?? 'шт',
        j['quantity'] as int? ?? 0,
        j['locationId'] as int? ?? 0,
        j['imageUrl'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'name': name,
        'category': category,
        'unit': unit,
        'quantity': quantity,
        'locationId': locationId == 0 ? null : locationId,
        'imageUrl': imageUrl,
      };

  Product copyWith({int? id, int? quantity, int? locationId}) => Product(
      id ?? this.id,
      sku,
      name,
      category,
      unit,
      quantity ?? this.quantity,
      locationId ?? this.locationId,
      imageUrl);
}
