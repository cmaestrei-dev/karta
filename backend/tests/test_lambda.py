"""La entrada de AWS Lambda (D7): el calentador y las peticiones de la Function URL llegan a la misma app."""
import json


def evento(metodo: str, ruta: str, cuerpo: dict | None = None, ip: str = "181.50.1.2") -> dict:
    """Una petición como la manda la Function URL (formato 2.0): rawPath trae la ruta tal cual, y
    requestContext.http.path, sin la barra final."""
    return {
        "version": "2.0", "routeKey": "$default", "rawPath": ruta, "rawQueryString": "",
        "headers": {"host": "karta.lambda-url.us-east-1.on.aws", "content-type": "application/json"},
        "requestContext": {
            "accountId": "anonymous", "apiId": "karta", "domainName": "karta.lambda-url.us-east-1.on.aws",
            "domainPrefix": "karta", "requestId": "prueba", "routeKey": "$default", "stage": "$default",
            "time": "26/Oct/2026:06:00:00 +0000", "timeEpoch": 1792980000000,
            "http": {"method": metodo, "path": ruta.rstrip("/") or "/", "protocol": "HTTP/1.1", "sourceIp": ip,
                     "userAgent": "prueba"},
        },
        "body": json.dumps(cuerpo) if cuerpo is not None else None, "isBase64Encoded": False,
    }


def test_el_calentador_y_la_function_url_llegan_a_la_api(api):
    from src.infrastructure.lambda_handler import handler

    assert handler({"preparar": True}, None) == {"preparada": True}  # lo que hace el despliegue
    assert handler({"calentar": True}, None) == {"calentada": True}

    salud = handler(evento("GET", "/api/v1/health"), None)
    assert salud["statusCode"] == 200 and json.loads(salud["body"])["database"] == "up"

    lugares = handler(evento("GET", "/api/v1/places/search") | {"rawQueryString": "q=bazurto"}, None)
    assert any(lugar["nombre"] == "Estación Bazurto" for lugar in json.loads(lugares["body"]))


def test_las_rutas_con_barra_final_no_redirigen_en_bucle(api):
    """En el primer despliegue, GET /api/v1/incidents/ respondía 307 hacia sí misma y la app no cargaba los reportes."""
    from src.infrastructure.lambda_handler import handler

    for ruta in ("/api/v1/incidents/", "/api/v1/routes/"):
        respuesta = handler(evento("GET", ruta), None)
        assert respuesta["statusCode"] == 200, ruta


def test_los_limites_por_ip_usan_la_ip_del_viajero(api):
    from src.infrastructure.database import get_database
    from src.infrastructure.lambda_handler import handler

    respuesta = handler(evento("POST", "/api/v1/auth/anonymous", {"secreto": "s" * 43}, ip="181.50.77.88"), None)
    assert respuesta["statusCode"] == 200
    assert get_database().rate_limits.count_documents({"_id": {"$regex": "^cuenta_invisible:ip:181.50.77.88:"}}) == 1
