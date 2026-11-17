"""Los datos de referencia (rutas, estaciones, lugares) llegan también a una base que ya existía."""


def test_una_base_existente_recibe_los_datos_que_cambiaron(api):
    from src.infrastructure.database import get_database
    from src.infrastructure.reference_data import cargar_datos_de_referencia
    db = get_database()
    cargar_datos_de_referencia(db)
    assert db.stations.find_one({"_id": "santa-lucia"})["rutas"][:2] == ["A103", "A104"]

    # Una base de antes: le falta una estación y la huella guardada es la de otros archivos.
    db.stations.delete_one({"_id": "santa-lucia"})
    db.reference_data.update_one({"_id": "transcaribe"}, {"$set": {"huella": "de-otra-version"}})
    cargar_datos_de_referencia(db)
    assert db.stations.find_one({"_id": "santa-lucia"}) is not None

    # Sin cambios en los archivos no se vuelve a cargar: lo que se borre a mano sigue borrado.
    db.stations.delete_one({"_id": "portal"})
    cargar_datos_de_referencia(db)
    assert db.stations.find_one({"_id": "portal"}) is None
    cargar_datos_de_referencia(db, forzar=True)
    assert db.stations.find_one({"_id": "portal"}) is not None
