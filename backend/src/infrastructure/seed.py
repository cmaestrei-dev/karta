from src.infrastructure.database import SessionLocal
from src.infrastructure.models import Modalidad, Usuario, TipoViajero

def seed():
    db = SessionLocal()
    try:
        if db.query(Modalidad).count() == 0:
            print("Iniciando inyección de datos semilla en Karta...")
            modalidades_base = [
                Modalidad(nombre_servicio="Transcaribe", tipo_servicio="Público"),
                Modalidad(nombre_servicio="Caminata", tipo_servicio="Físico")
            ]
            db.add_all(modalidades_base)
            print("✅ Catálogo de modalidades listo.")
        else:
            print("⚠️ Las modalidades ya estaban registradas. No se requiere acción.")

        # Usuario de desarrollo: la app aún reporta como id_usuario=1 hasta que exista login.
        if db.query(Usuario).count() == 0:
            db.add(Usuario(tipo_viajero=TipoViajero.RESIDENTE))
            print("✅ Usuario de desarrollo creado (id_usuario=1).")

        db.commit()
    except Exception as e:
        print(f"❌ Error al poblar la base de datos: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed()
