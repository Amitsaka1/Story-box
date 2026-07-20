/// Data structure for a story category. Backend se aane wale JSON ko
/// isi shape mein map karte hain.
class CategoryModel {
  final String id;
  final String name;

  const CategoryModel({required this.id, required this.name});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}
