# SonarQube — Análisis de calidad de Hotel Nyx

Stack local de SonarQube (Community) + PostgreSQL para analizar el código de
`app/` (reservas, pagos, frontend) y obtener la captura del dashboard.

La configuración del análisis vive en [`sonar-project.properties`](../sonar-project.properties)
en la raíz del proyecto. El `projectKey` es **`hotel-nyx`**.

---

## Correr SonarQube localmente en Windows

> Requisitos: Docker Desktop en marcha.

### 1) Levantar el stack

```powershell
cd sonarqube
docker compose up -d
```

### 2) Esperar a que arranque (2-3 min)

SonarQube tarda en iniciar. Espera 2-3 minutos y verifica que esté `UP`:

- En el navegador: <http://localhost:9000>
- O por API: <http://localhost:9000/api/system/status> (debe devolver `"status":"UP"`)

### 3) Entrar y configurar el proyecto

1. Abre <http://localhost:9000>.
2. Login inicial: **admin / admin** (te pedirá cambiar la contraseña la primera vez).
3. Crea un proyecto **local** con la clave exacta **`hotel-nyx`**:
   *Create Project → Local project → Project key: `hotel-nyx`*.
4. Cuando pida el método de análisis, elige **Use the global setting / Locally**
   y **genera un token** de análisis. Cópialo (no se vuelve a mostrar).

### 4) Correr el scanner

Desde la **raíz del proyecto** (no desde `sonarqube/`), reemplaza `TU_TOKEN`:

```powershell
docker run --rm `
  -e SONAR_HOST_URL="http://host.docker.internal:9000" `
  -e SONAR_TOKEN="TU_TOKEN" `
  -v "${PWD}:/usr/src" `
  sonarsource/sonar-scanner-cli
```

> En Windows el contenedor del scanner alcanza a SonarQube vía
> `host.docker.internal:9000` (no `localhost`, que apuntaría al propio contenedor).

### 5) Ver el dashboard

Cuando el scanner termine, vuelve a <http://localhost:9000> → proyecto **hotel-nyx**.
Ahí está el dashboard con métricas y Quality Gate (para la captura).

### 6) Apagar

```powershell
cd sonarqube
docker compose down       # conserva los datos en los volúmenes
# docker compose down -v  # borra también los volúmenes (instancia limpia)
```

---

## Integración en CI (GitHub Actions)

El workflow `.github/workflows/deploy.yml` incluye un job **`sonarqube`**
independiente e **informativo**: levanta una instancia efímera, corre el análisis
y reporta el Quality Gate sin bloquear el resto del pipeline.

> **Falta configurar en GitHub:** crea el secret **`SONAR_ADMIN_PASSWORD`**
> (Settings → Secrets and variables → Actions → New repository secret).
> En CI la instancia se levanta limpia con credencial inicial `admin/admin`;
> el job cambia esa contraseña a `SONAR_ADMIN_PASSWORD` antes de generar el token.
