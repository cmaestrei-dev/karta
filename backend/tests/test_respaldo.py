"""La copia de seguridad propia (plan de calidad, D2): ida y vuelta sin perder tipos, y sin los datos de referencia."""
import gzip
from datetime import datetime, timedelta, timezone

from bson import ObjectId

from src.infrastructure.respaldo import SIN_RESPALDO, colecciones_a_respaldar, respaldar, restaurar


def test_la_copia_va_y_vuelve_igual_y_no_lleva_lo_de_referencia(api, registrar):
    from src.infrastructure.database import get_database
    db = get_database()
    registrar()  # al menos un usuario
    # Mongo guarda las fechas al milisegundo: sin microsegundos, la copia vuelve idéntica.
    vence = (datetime.now(timezone.utc) + timedelta(days=1)).replace(microsecond=0)
    marca = {"_id": ObjectId(), "ruta": "T103", "en": datetime(2026, 11, 18, 12, 30, tzinfo=timezone.utc),
             "expira_en": vence, "ubicacion": {"type": "Point", "coordinates": [-75.5, 10.4]}}
    db.boardings.insert_one(dict(marca))

    guardado: dict[str, bytes] = {}
    hecho = respaldar(db, guardado.__setitem__, datetime(2026, 11, 18, 8, 0, tzinfo=timezone.utc))
    assert hecho["respaldo"] == "2026-11-18" and hecho["colecciones"]["users"] >= 1
    assert "2026-11-18/boardings.jsonl.gz" in guardado
    assert not any(clave.split("/")[1].removesuffix(".jsonl.gz") in SIN_RESPALDO for clave in guardado)
    assert "transit_routes" in db.list_collection_names() and "transit_routes" not in colecciones_a_respaldar(db)
    assert str(marca["_id"]) in gzip.decompress(guardado["2026-11-18/boardings.jsonl.gz"]).decode()

    # Se pierde el documento y vuelve igual, con su ObjectId y su fecha.
    db.boardings.delete_one({"_id": marca["_id"]})
    vuelto = restaurar(db, guardado.get, "2026-11-18", ["boardings"])
    assert vuelto["colecciones"]["boardings"] >= 1
    assert db.boardings.find_one({"_id": marca["_id"]}) == marca
    db.boardings.delete_one({"_id": marca["_id"]})


def test_restaurar_un_dia_sin_copia_no_hace_nada(api):
    from src.infrastructure.database import get_database
    assert restaurar(get_database(), {}.get, "2026-01-01")["colecciones"] == {}


def test_sin_bucket_la_copia_falla_a_la_vista():
    """Si falta el bucket, la invocación falla: así la alarma de errores de la función avisa."""
    import pytest
    from src.infrastructure.lambda_handler import handler
    with pytest.raises(RuntimeError, match="RESPALDOS_BUCKET"):
        handler({"respaldar": True}, None)
