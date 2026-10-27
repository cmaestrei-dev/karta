import 'package:equatable/equatable.dart';

/// «Tu impacto»: lo que el viajero le ha aportado a la comunidad.
class Impacto extends Equatable {
  final int reportes;
  final int confirmaciones;
  final int gracias;
  final int vistas;

  /// Paraderos que marcó y la comunidad confirmó (Kartógrafo).
  final int paraderos;

  const Impacto({this.reportes = 0, this.confirmaciones = 0, this.gracias = 0, this.vistas = 0, this.paraderos = 0});

  factory Impacto.fromJson(Map<String, dynamic>? json) => Impacto(
        reportes: json?['reportes'] as int? ?? 0,
        confirmaciones: json?['confirmaciones'] as int? ?? 0,
        gracias: json?['gracias'] as int? ?? 0,
        vistas: json?['vistas'] as int? ?? 0,
        paraderos: json?['paraderos'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'reportes': reportes, 'confirmaciones': confirmaciones, 'gracias': gracias, 'vistas': vistas, 'paraderos': paraderos};

  @override
  List<Object> get props => [reportes, confirmaciones, gracias, vistas, paraderos];
}

/// Una insignia ganada con aportes que la comunidad validó.
class Insignia extends Equatable {
  final String clave;
  final String nombre;
  final String descripcion;

  const Insignia({required this.clave, required this.nombre, required this.descripcion});

  factory Insignia.fromJson(Map<String, dynamic> json) => Insignia(
        clave: json['clave'] as String,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'clave': clave, 'nombre': nombre, 'descripcion': descripcion};

  @override
  List<Object> get props => [clave, nombre, descripcion];
}

/// La insignia sin ganar más cercana: «Ojo de halcón: 3 de 10 confirmaciones».
class AvanceDeInsignia extends Equatable {
  final Insignia insignia;
  final int llevas;
  final int meta;
  final String unidad;

  const AvanceDeInsignia({required this.insignia, required this.llevas, required this.meta, required this.unidad});

  factory AvanceDeInsignia.fromJson(Map<String, dynamic> json) => AvanceDeInsignia(
        insignia: Insignia.fromJson(json['insignia'] as Map<String, dynamic>),
        llevas: json['llevas'] as int,
        meta: json['meta'] as int,
        unidad: json['unidad'] as String,
      );

  Map<String, dynamic> toJson() => {'insignia': insignia.toJson(), 'llevas': llevas, 'meta': meta, 'unidad': unidad};

  double get fraccion => meta == 0 ? 1 : (llevas / meta).clamp(0.0, 1.0);

  @override
  List<Object> get props => [insignia, llevas, meta, unidad];
}

/// Los marcos del avatar por nivel, con nombres de Cartagena (el nivel 1 aún no tiene).
const marcosPorNivel = {2: 'Muralla', 3: 'Bahía', 4: 'Castillo', 5: 'La Popa'};

/// Un viajero. [sinCuenta]: la cuenta invisible del teléfono, sin nombre ni correo; registrarse le pone correo
/// a esa misma cuenta.
class Usuario extends Equatable {
  final String id;
  final String? email;
  final String? nombre;
  final String? tipoViajero;
  final int reputacion;
  final bool sinCuenta;
  final Impacto impacto;
  final List<Insignia> insignias;
  final AvanceDeInsignia? siguienteInsignia;

  /// Nombre corto que ven los demás viajeros en los reportes («Ana P.»).
  final String alias;

  /// Nivel de 1 a 5 según la reputación: sube cuando la comunidad confirma tus reportes.
  final int nivel;

  /// La última versión de la política de datos que aceptó, y la vigente. Si no coinciden, la app vuelve a mostrar el
  /// aviso de privacidad (Ley 1581).
  final String? autorizacion;
  final String? politicaVigente;

  const Usuario({
    required this.id,
    required this.email,
    required this.nombre,
    required this.tipoViajero,
    required this.reputacion,
    required this.alias,
    required this.nivel,
    this.sinCuenta = false,
    this.impacto = const Impacto(),
    this.insignias = const [],
    this.siguienteInsignia,
    this.autorizacion,
    this.politicaVigente,
  });

  /// Le falta aceptar la versión vigente de la política de datos.
  bool get debeAceptarPolitica => politicaVigente != null && autorizacion != politicaVigente;

  /// El marco del avatar según el nivel («Bahía»), o null en el nivel 1.
  String? get marco => marcosPorNivel[nivel.clamp(1, 5)];

  /// Las iniciales del avatar: «Camilo Maestre» → «CM». Vacías sin cuenta (el avatar muestra un ícono).
  String get iniciales {
    final partes = (nombre ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }

  /// Reputación que falta para el siguiente nivel, o null en el nivel máximo.
  int? get faltaParaSubir {
    final siguiente = umbralesDeNivel.where((u) => u > reputacion).firstOrNull;
    return siguiente == null ? null : siguiente - reputacion;
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final nombre = json['nombre'] as String?;
    final reputacion = json['reputacion'] as int;
    return Usuario(
      id: json['id'] as String,
      email: json['email'] as String?,
      nombre: nombre,
      tipoViajero: json['tipo_viajero'] as String?,
      reputacion: reputacion,
      // Un perfil guardado antes de los reportes v2 no trae alias ni nivel: se calculan igual que el backend.
      alias: json['alias'] as String? ?? (nombre != null ? aliasPublico(nombre) : 'Viajero sin cuenta'),
      nivel: json['nivel'] as int? ?? nivelPorReputacion(reputacion),
      sinCuenta: json['sin_cuenta'] as bool? ?? json['email'] == null,
      impacto: Impacto.fromJson(json['impacto'] as Map<String, dynamic>?),
      insignias: [
        for (final i in json['insignias'] as List? ?? const []) Insignia.fromJson(i as Map<String, dynamic>),
      ],
      siguienteInsignia: json['siguiente_insignia'] == null
          ? null
          : AvanceDeInsignia.fromJson(json['siguiente_insignia'] as Map<String, dynamic>),
      autorizacion: json['autorizacion'] as String?,
      politicaVigente: json['politica_vigente'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nombre': nombre,
        'tipo_viajero': tipoViajero,
        'reputacion': reputacion,
        'alias': alias,
        'nivel': nivel,
        'sin_cuenta': sinCuenta,
        'impacto': impacto.toJson(),
        'insignias': [for (final i in insignias) i.toJson()],
        if (siguienteInsignia != null) 'siguiente_insignia': siguienteInsignia!.toJson(),
        'autorizacion': autorizacion,
        'politica_vigente': politicaVigente,
      };

  @override
  List<Object?> get props =>
      [id, email, nombre, tipoViajero, reputacion, alias, nivel, sinCuenta, impacto, insignias, siguienteInsignia,
       autorizacion, politicaVigente];
}

/// Reputación con la que empieza cada nivel, del 2 al 5 (todos arrancan en 100, nivel 1).
const umbralesDeNivel = [150, 200, 300, 450];

int nivelPorReputacion(int reputacion) => 1 + umbralesDeNivel.where((u) => reputacion >= u).length;

/// «Ana María Pérez» → «Ana M.»: el primer nombre y la inicial del siguiente.
String aliasPublico(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return 'Viajero';
  return partes.length > 1 ? '${partes[0]} ${partes[1][0].toUpperCase()}.' : partes[0];
}
