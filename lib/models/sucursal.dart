
class Sucursal {
  final int id;
  final double lat, lng;

  Sucursal({required this.id, required this.lat, required this.lng});

  factory Sucursal.fromJson(Map<String, dynamic> json) {
    return Sucursal(
      id: json['id'] as int,
      lat: (json['latitud'] as num).toDouble(),
      lng: (json['longitud'] as num).toDouble(),
    );
  }
}
