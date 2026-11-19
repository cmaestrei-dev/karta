import 'package:equatable/equatable.dart';

import '../../places/domain/place_models.dart';

/// Una estación del álbum (docs/plan-juego.md): una lámina con su ilustración.
class EstacionDelAlbum {
  final int numero;
  final String id;
  final String nombre;
  final String tipo;

  const EstacionDelAlbum(this.numero, this.id, this.nombre, this.tipo);

  String get ilustracion => 'assets/album/$id.svg';
}

/// Las 19 láminas, más o menos en el orden de la troncal: del Portal hacia el Centro. Los nombres son los de las
/// estaciones de Karta (data/transcaribe.json del backend).
const estacionesDelAlbum = [
  EstacionDelAlbum(1, 'portal', 'Patio Portal', 'Portal'),
  EstacionDelAlbum(2, 'santa-lucia', 'Santa Lucía', 'Transferencia de alimentadoras'),
  EstacionDelAlbum(3, 'madre-bernarda', 'Madre Bernarda', 'Estación troncal'),
  EstacionDelAlbum(4, 'la-castellana', 'La Castellana', 'Estación troncal'),
  EstacionDelAlbum(5, 'los-angeles', 'Los Ángeles', 'Estación troncal'),
  EstacionDelAlbum(6, 'los-ejecutivos', 'Los Ejecutivos', 'Estación troncal'),
  EstacionDelAlbum(7, 'villa-olimpica', 'Villa Olímpica', 'Estación troncal'),
  EstacionDelAlbum(8, 'cuatro-vientos', 'Cuatro Vientos', 'Estación troncal'),
  EstacionDelAlbum(9, 'republica-del-libano', 'República del Líbano', 'Estación troncal'),
  EstacionDelAlbum(10, 'espana', 'España', 'Estación troncal'),
  EstacionDelAlbum(11, 'maria-auxiliadora', 'María Auxiliadora', 'Estación troncal'),
  EstacionDelAlbum(12, 'el-prado', 'El Prado', 'Estación troncal'),
  EstacionDelAlbum(13, 'bazurto', 'Bazurto', 'Estación troncal'),
  EstacionDelAlbum(14, 'las-delicias', 'Las Delicias', 'Estación troncal'),
  EstacionDelAlbum(15, 'la-popa', 'La Popa', 'Estación troncal'),
  EstacionDelAlbum(16, 'lo-amador', 'Lo Amador', 'Estación troncal'),
  EstacionDelAlbum(17, 'chambacu', 'Chambacú', 'Estación troncal'),
  EstacionDelAlbum(18, 'centro', 'Centro', 'Estación troncal'),
  EstacionDelAlbum(19, 'la-bodeguita', 'La Bodeguita', 'Estación troncal'),
];

/// La lámina de una estación por la que ya pasó.
class Lamina extends Equatable {
  final String id;
  final DateTime conseguida;

  /// La ruta en la que la consiguió («T101»).
  final String? ruta;

  /// Cuántas veces ha pasado por ella en un viaje compartido.
  final int veces;

  const Lamina({required this.id, required this.conseguida, this.ruta, this.veces = 1});

  factory Lamina.fromJson(Map<String, dynamic> json) => Lamina(
        id: json['id'] as String,
        conseguida: DateTime.parse(json['conseguida'] as String),
        ruta: json['ruta'] as String?,
        veces: json['veces'] as int? ?? 1,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'conseguida': conseguida.toIso8601String(), if (ruta != null) 'ruta': ruta, 'veces': veces};

  @override
  List<Object?> get props => [id, conseguida, ruta, veces];
}

/// El álbum de estaciones. Vive solo en el teléfono: por dónde pasa alguien no sale de ahí.
class Album extends Equatable {
  final Map<String, Lamina> laminas;

  /// La última que consiguió, para marcarla «Nueva» hasta que la abra.
  final String? nueva;

  const Album({this.laminas = const {}, this.nueva});

  int get conseguidas => laminas.length;
  int get total => estacionesDelAlbum.length;
  bool get lleno => conseguidas == total;

  /// La estación del álbum con ese nombre («Estación La Popa», «Chambacu», «Patio Portal»); null si no es una.
  static EstacionDelAlbum? estacion(String nombre) {
    var clave = normalizarParaBuscar(nombre.trim());
    if (clave.startsWith('estacion ')) clave = clave.substring('estacion '.length);
    for (final e in estacionesDelAlbum) {
      if (normalizarParaBuscar(e.nombre) == clave || e.id == clave) return e;
    }
    return clave == 'portal' ? estacionesDelAlbum.first : null;
  }

  /// Pasó por [nombre] en un viaje compartido: la lámina nueva (si es la primera vez) o una vez más.
  ({Album album, EstacionDelAlbum? nueva}) pasoPor(String nombre, {String? ruta, required DateTime cuando}) {
    final estacion = Album.estacion(nombre);
    if (estacion == null) return (album: this, nueva: null);
    final antes = laminas[estacion.id];
    final lamina = antes == null
        ? Lamina(id: estacion.id, conseguida: cuando, ruta: ruta)
        : Lamina(id: antes.id, conseguida: antes.conseguida, ruta: antes.ruta, veces: antes.veces + 1);
    return (
      album: Album(laminas: {...laminas, estacion.id: lamina}, nueva: antes == null ? estacion.id : nueva),
      nueva: antes == null ? estacion : null,
    );
  }

  /// Ya vio la lámina nueva.
  Album vista() => Album(laminas: laminas);

  /// La primera estación sin conseguir que viene después de [despuesDe] en el álbum (o la primera que falte).
  EstacionDelAlbum? siguientePorConseguir({String? despuesDe}) {
    final desde = estacionesDelAlbum.indexWhere((e) => e.id == despuesDe);
    final orden = [...estacionesDelAlbum.skip(desde + 1), ...estacionesDelAlbum.take(desde + 1)];
    for (final e in orden) {
      if (!laminas.containsKey(e.id)) return e;
    }
    return null;
  }

  factory Album.fromJson(Map<String, dynamic> json) => Album(
        laminas: {
          for (final l in json['laminas'] as List<dynamic>? ?? const [])
            (l as Map<String, dynamic>)['id'] as String: Lamina.fromJson(l),
        },
        nueva: json['nueva'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'laminas': [for (final l in laminas.values) l.toJson()], if (nueva != null) 'nueva': nueva};

  @override
  List<Object?> get props => [laminas, nueva];
}
