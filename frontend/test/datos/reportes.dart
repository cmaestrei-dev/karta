/// Datos de prueba de los reportes v2, con la forma exacta de las respuestas de la API.
library;

/// El catálogo tal como lo sirve GET /incidents/types (recortado a dos grupos).
final catalogoJson = [
  {
    'clave': 'servicio',
    'nombre': 'Servicio de Transcaribe',
    'tipos': [
      {
        'clave': 'bus_no_pasa',
        'nombre': 'El bus no pasa',
        'vigencia_min': 60,
        'campos': [
          {'clave': 'ruta', 'pregunta': '¿Qué ruta esperas?', 'tipo': 'ruta', 'obligatorio': true, 'opciones': []},
          {
            'clave': 'espera',
            'pregunta': '¿Hace cuánto esperas?',
            'tipo': 'opciones',
            'obligatorio': false,
            'opciones': [
              {'valor': '10', 'etiqueta': '10 min'},
              {'valor': '20', 'etiqueta': '20 min'},
              {'valor': '30', 'etiqueta': '30 min o más'},
            ],
          },
        ],
      },
      {'clave': 'estacion_cerrada', 'nombre': 'Estación cerrada', 'vigencia_min': 240, 'campos': []},
    ],
  },
  {
    'clave': 'via',
    'nombre': 'En la vía',
    'tipos': [
      {
        'clave': 'calle_inundada',
        'nombre': 'Calle inundada',
        'vigencia_min': 180,
        'campos': [
          {
            'clave': 'paso',
            'pregunta': '¿Se puede pasar?',
            'tipo': 'opciones',
            'obligatorio': false,
            'opciones': [
              {'valor': 'con_cuidado', 'etiqueta': 'Con cuidado'},
              {'valor': 'no_se_puede', 'etiqueta': 'No se puede'},
            ],
          },
        ],
      },
      {'clave': 'trancon', 'nombre': 'Trancón', 'vigencia_min': 60, 'campos': []},
    ],
  },
];

Map<String, dynamic> incidenteJson({String tipo = 'bus_no_pasa', Map<String, dynamic>? detalles, int votosSi = 0}) => {
      'id': '665f1c2b9a1e4b0012345678',
      'grupo': tipo == 'bus_no_pasa' ? 'servicio' : 'via',
      'tipo': tipo,
      'detalles': detalles ?? {'ruta': 'T103', 'espera': '20'},
      'latitud': 10.4139,
      'longitud': -75.5243,
      'lugar': 'Estación Bazurto',
      'votos_si': votosSi,
      'votos_no': 0,
      'creado_en': '2026-10-22T18:00:00Z',
      'expira_en': '2026-10-22T19:00:00Z',
    };
