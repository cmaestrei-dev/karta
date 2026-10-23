import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:karta/core/api_client.dart';
import 'package:karta/features/places/data/places_repository.dart';
import 'package:karta/features/places/domain/place_models.dart';
import 'package:karta/features/places/presentation/cubit/place_search_cubit.dart';
import 'package:karta/features/places/presentation/cubit/saved_places_cubit.dart';
import 'package:latlong2/latlong.dart';

const _bocagrande = Place(nombre: 'Bocagrande', tipo: 'Barrio', punto: LatLng(10.399, -75.554));

/// Repositorio en memoria: las búsquedas se resuelven a mano para simular respuestas lentas.
class FakePlacesRepository implements PlacesRepository {
  final busquedas = <String, Completer<List<Place>>>{};
  final guardados = <SavedPlace>[];
  String? errorAlGuardar;

  @override
  ApiClient get api => throw UnimplementedError();

  @override
  Future<List<Place>> search(String consulta) => (busquedas[consulta] = Completer<List<Place>>()).future;

  @override
  Future<Place> reverse(LatLng punto) async => _bocagrande;

  @override
  Future<List<SavedPlace>> listSaved() async => List.of(guardados);

  @override
  Future<SavedPlace> addSaved({required String nombre, required SavedPlaceIcon icono, required LatLng punto}) async {
    if (errorAlGuardar != null) throw ApiException(errorAlGuardar!);
    final lugar = SavedPlace(id: 'id-${guardados.length}', nombre: nombre, icono: icono, punto: punto);
    guardados.add(lugar);
    return lugar;
  }

  @override
  Future<SavedPlace> updateSaved(String id, {String? nombre, SavedPlaceIcon? icono}) async {
    final i = guardados.indexWhere((l) => l.id == id);
    guardados[i] = SavedPlace(id: id, nombre: nombre ?? guardados[i].nombre, icono: icono ?? guardados[i].icono, punto: guardados[i].punto);
    return guardados[i];
  }

  @override
  Future<void> deleteSaved(String id) async => guardados.removeWhere((l) => l.id == id);
}

void main() {
  group('PlaceSearchCubit', () {
    test('no busca con menos de dos letras', () {
      final repo = FakePlacesRepository();
      final cubit = PlaceSearchCubit(repository: repo)..onQueryChanged('b');
      expect(cubit.state.status, PlaceSearchStatus.vacio);
      expect(repo.busquedas, isEmpty);
    });

    test('espera a que dejes de escribir y descarta respuestas viejas', () async {
      final repo = FakePlacesRepository();
      final cubit = PlaceSearchCubit(repository: repo);

      cubit.onQueryChanged('bo');
      await Future<void>.delayed(PlaceSearchCubit.espera + const Duration(milliseconds: 50));
      cubit.onQueryChanged('boca');
      await Future<void>.delayed(PlaceSearchCubit.espera + const Duration(milliseconds: 50));

      // La respuesta de "boca" llega primero y la de "bo" después: debe quedar "boca".
      repo.busquedas['boca']!.complete([_bocagrande]);
      await Future<void>.delayed(Duration.zero);
      repo.busquedas['bo']!.complete([]);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.consulta, 'boca');
      expect(cubit.state.status, PlaceSearchStatus.resultados);
      expect(cubit.state.resultados.single.nombre, 'Bocagrande');
    });
  });

  group('SavedPlacesCubit', () {
    test('agrega, renombra y elimina', () async {
      final repo = FakePlacesRepository();
      final cubit = SavedPlacesCubit(repository: repo, onSessionExpired: () {});
      await cubit.load();

      expect(await cubit.add(nombre: 'Casa', icono: SavedPlaceIcon.casa, punto: _bocagrande.punto), isNull);
      final casa = cubit.state.lugares.single;
      expect(await cubit.update(casa, nombre: 'Mi casa'), isNull);
      expect(cubit.state.lugares.single.nombre, 'Mi casa');
      expect(await cubit.delete(cubit.state.lugares.single), isNull);
      expect(cubit.state.lugares, isEmpty);
    });

    test('devuelve el mensaje de la API cuando no se puede guardar', () async {
      final repo = FakePlacesRepository()..errorAlGuardar = 'Ya tienes 10 lugares guardados; elimina uno primero.';
      final cubit = SavedPlacesCubit(repository: repo, onSessionExpired: () {});

      final error = await cubit.add(nombre: 'Uno más', icono: SavedPlaceIcon.favorito, punto: _bocagrande.punto);
      expect(error, 'Ya tienes 10 lugares guardados; elimina uno primero.');
      expect(cubit.state.lugares, isEmpty);
    });
  });
}
