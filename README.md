# TaskLite

Mały planer projektów i zadań. Backend w C# udostępnia API, zapisuje dane w SQL Server przez EF Core, a ekran w HTML/CSS/JavaScript korzysta z `fetch`.

## Funkcje

- dodawanie projektów z unikalną nazwą;
- usuwanie pustych projektów; projekty z zadaniami są chronione przed usunięciem;
- dodawanie, edycja i usuwanie zadań przypisanych do projektu;
- statusy `Todo`, `InProgress`, `Done`, opis oraz opcjonalny termin;
- filtrowanie po projekcie, statusie i tytule oraz stronicowanie;
- walidacja danych na serwerze, migracje i trwały wolumen bazy;
- dwa przykładowe raporty T-SQL w `sql/reports.sql`.

## Uruchomienie

Wymagany Docker Desktop z kontenerami Linux, około 4 GB wolnej pamięci oraz dostęp do internetu przy pierwszym buildzie. SQL Server Developer służy tutaj do lokalnego programowania.

```powershell
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
# W .env ustaw MSSQL_SA_PASSWORD na własne silne hasło developerskie.
docker compose up --build -d
docker compose logs migrate
```

Otwórz [localhost:8080](http://localhost:8080). SQL Server jest dostępny na `localhost,14333`. Migracja wykonuje się w osobnym kontenerze przed startem aplikacji. Pierwszy start bazy może potrwać około minuty; jeśli ekran nie odpowiada, sprawdź `docker compose ps` i logi.

Hasło nie powinno zawierać średnika, ponieważ konfiguracja Compose umieszcza je w connection stringu. Plik `.env` jest ignorowany przez Git. Zachowaj istniejące hasło przy ponownym uruchomieniu: zmiana `.env` nie zmienia loginu `sa` w zachowanym wolumenie. `TrustServerCertificate=True` jest ustawieniem lokalnego środowiska z developerskim certyfikatem SQL Server.

```powershell
docker compose logs web
docker compose stop
docker compose start
# Usunięcie kontenerów z zachowaniem danych:
docker compose down
```

Po pierwszym uruchomieniu utwórz projekt, np. „Nauka SQL”, a następnie zadanie. Baza jest początkowo pusta. Nie ma automatycznych danych przedstawianych jako prawdziwi użytkownicy.

## Uruchomienie aplikacji bez kontenera

Wymagany SDK .NET 10. SQL Server może nadal działać przez Compose.

```powershell
docker compose up -d db
$env:ConnectionStrings__TaskLite = 'Server=localhost,14333;Database=TaskLite;User Id=sa;Password=TWOJE_HASLO;Encrypt=True;TrustServerCertificate=True'
dotnet run --project src/TaskLite.Web -- --migrate
dotnet run --project src/TaskLite.Web --urls http://localhost:5080
```

W tym wariancie ekran jest dostępny na [localhost:5080](http://localhost:5080).

## Sprawdzenie działania

```powershell
dotnet build TaskLite.slnx
# Skrypt wymaga PowerShell 7 (pwsh):
pwsh -File scripts/Smoke.ps1
# Dla aplikacji uruchomionej przez dotnet:
pwsh -File scripts/Smoke.ps1 -BaseUrl http://localhost:5080
```

Skrypt sprawdza zapis i odczyt, relację z projektem, filtr, zmianę statusu, usunięcie, błędne identyfikatory, limity stronicowania oraz niepoprawne dane. Sprawdza również, że projekt z zadaniami nie może zostać usunięty, a po usunięciu zadania można usunąć pusty projekt i znika on z listy. Korzysta z prawdziwej bazy aplikacji. Tworzy własny projekt z losową nazwą i sprząta wyłącznie swoje zadanie i projekt w bloku `finally`, także gdy sprawdzenie zakończy się błędem. Workflow GitHub Actions buduje aplikację i wykonuje te same sprawdzenia w Compose.

## API

| Metoda i adres | Działanie |
| --- | --- |
| `GET /api/projects` | Lista projektów |
| `GET /api/projects/{id}` | Jeden projekt |
| `POST /api/projects` | Nowy projekt, np. `{"name":"Nauka SQL"}` |
| `DELETE /api/projects/{id}` | Usunięcie pustego projektu: 204; brak projektu: 404; projekt z zadaniami: 409 |
| `GET /api/tasks` | Lista z filtrami `projectId`, `status`, `search`, `page`, `pageSize` |
| `GET /api/tasks/{id}` | Jedno zadanie |
| `POST /api/tasks` | Nowe zadanie |
| `PUT /api/tasks/{id}` | Zmiana wszystkich pól zadania |
| `DELETE /api/tasks/{id}` | Usunięcie zadania |
| `GET /health` | Połączenie z bazą: 200 albo 503 |

Przykładowe żądanie dodania zadania — `projectId` musi wskazywać utworzony projekt:

```json
{
  "projectId": 1,
  "title": "Przećwiczyć LEFT JOIN",
  "description": "Uwzględnić także projekty bez zadań",
  "dueDate": "2026-10-20",
  "status": "Todo"
}
```

## Model i kod

`Projects` ma wiele rekordów `Tasks`. Klucz obcy pilnuje przypisania do projektu i blokuje usunięcie projektu, dopóki istnieją jego zadania. Po usunięciu pustego projektu ekran odświeża listę projektów w formularzu zadania i filtrze. Nazwa projektu ma unikalny indeks, a zadania indeks `(ProjectId, Status, DueDate)`. Zapytanie raportowe z `LEFT JOIN` pokazuje również projekty bez zadań. Przy większej liczbie danych dobór indeksów wymaga sprawdzenia planu wykonania i pomiarów.

- `Program.cs`: konfiguracja usług, połączenia i aplikacji;
- `Controllers`: operacje HTTP;
- `Contracts`: dane żądań i odpowiedzi, walidacja;
- `Models`: projekt, zadanie i status;
- `Data`: konfiguracja EF Core i migracje;
- `wwwroot`: formularze i komunikacja z API.

Nową migrację można utworzyć przez `dotnet ef migrations add Nazwa --project src/TaskLite.Web` po zainstalowaniu narzędzia `dotnet-ef` w wersji zgodnej z EF Core 10. Następnie uruchom aplikację z `--migrate`.

## Zakres

To lokalna aplikacja do nauki. Nie ma logowania, uprawnień, obsługi konfliktów równoczesnej edycji ani wdrożenia w Azure. Compose publikuje porty tylko na loopback. Poza takim środowiskiem potrzebne byłyby uwierzytelnianie, HTTPS, zarządzanie sekretami i konto bazy z ograniczonymi uprawnieniami zamiast `sa`.
