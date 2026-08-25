# Architektura RenoWorkshop

## Vrstvy

```
presentation  obrazovky, widgety, Riverpod providery
     |  závisí na
   domain     entity + rozhraní repository (čistý Dart, žádný Flutter)
     ^  implementuje
    data      DTO, datové zdroje, implementace repository
```

Pravidlo: **doména nezná nikoho**. `presentation` a `data` znají doménu, ale
navzájem se nevidí. Prakticky to znamená, že výměna zdroje dat se nedotkne UI
a naopak.

### Doména (`features/orders/domain/`)

| Typ | Role |
|---|---|
| `ServiceOrder` | servisní zakázka; `isOverdue()`, `mechanicInitials`, `matchesQuery()` |
| `OrderStatus` | 7 stavů v pořadí kroků na dílně; `next`, `isClosed`, `apiValue` |
| `Branch` | pobočka Praha / Brno / Zlín |
| `OrderNote`, `WorkItem` | poznámky a úkony |
| `OrderFilter` | kritéria seznamu + řazení, `apply()` je čistá funkce |
| `ServiceOrderRepository` | rozhraní, které zná prezentační vrstva |

`OrderStatus.apiValue` (`in_repair`, …) je stabilní klíč pro serializaci -
české popisky se dají měnit bez dopadu na data.

### Data (`features/orders/data/`)

```
ServiceOrderDataSource (rozhraní)
    ├── MockServiceOrderDataSource      fáze 1 - JSON z assetu, mutace v paměti
    └── RestServiceOrderDataSource      fáze 2 - HTTP proti DMS
                    ↓
ServiceOrderRepositoryImpl  mapuje DTO -> entity, drží cache a broadcast stream
```

Repository publikuje `Stream<List<ServiceOrder>>`, protože stav dílny je sdílený
mezi více lidmi. Dnes se do streamu emituje po lokální mutaci, později tam
poteče polling nebo websocket - **prezentační vrstva se nemění**.

### Prezentace (`features/orders/presentation/`)

```
serviceOrderDataSourceProvider   <- jediné místo, kde se vybírá zdroj dat
        ↓
serviceOrderRepositoryProvider
        ↓
ordersStreamProvider (StreamProvider)      orderActionsProvider (zápisy)
        ↓                                          ↓
filteredOrdersProvider  ← orderFilterProvider   updateStatus / addNote / setWorkItemDone
        ↓
OrdersListScreen                          orderByIdProvider → OrderDetailScreen
```

Detail čte ze stejného streamu jako seznam, takže posun stavu v detailu se
okamžitě projeví v seznamu bez ručního refreshe.

## Napojení reálného API (fáze 2)

1. Přidat HTTP klienta (`dio`) a provider `apiClientProvider` s auth
   interceptorem, který doplní token z Entra ID.
2. Napsat `RestServiceOrderDataSource implements ServiceOrderDataSource` -
   metody odpovídají endpointům:
   - `GET  /orders` → `fetchOrders()`
   - `GET  /orders/{id}` → `fetchOrder()`
   - `PATCH /orders/{id}` → `updateStatus()`
   - `POST /orders/{id}/notes` → `addNote()`
   - `PATCH /orders/{id}/work-items/{workItemId}` → `setWorkItemDone()`
3. Přepnout jeden řádek v `orders_providers.dart`:
   ```dart
   final serviceOrderDataSourceProvider = Provider<ServiceOrderDataSource>(
     (ref) => RestServiceOrderDataSource(ref.watch(apiClientProvider)),
   );
   ```
4. Pokud se liší tvar payloadu, upravit **jen** `ServiceOrderDto.fromJson`.
5. Volitelně: `OrderFilter` poslat jako query parametry místo filtrování
   v paměti (`apply()` zůstane pro offline režim).

Nic z toho se nedotkne obrazovek ani widgetů.

## Autentizace (fáze 2)

`AuthRepository` už má tvar, který cílová implementace potřebuje:

```dart
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(...),   // dnes PlaceholderAuthRepository()
);
```

Plán:

- Firebase Auth + `OAuthProvider('microsoft.com')` s tenantem RENOCAR
  (stejný postup jako v projektu RenoCharge).
- `local_auth` pro biometrické odemčení uloženého refresh tokenu; token
  v `flutter_secure_storage` (Keychain / Keystore).
- `isBiometricSignInAvailable()` už dnes řídí, jestli se biometrické tlačítko
  vůbec zobrazí.
- Auth guard je v `app/router.dart` v `redirect` - tam přibude i kontrola rolí
  (skupiny z Entra ID → `EmployeeRole`).

## Adaptivní chrome

Platforma se čte přes `Theme.of(context).platform` (extension `context.isIOS`),
ne přes `dart:io` - jde ji tak přepnout v testech.

| Prvek | iOS | Android |
|---|---|---|
| Titul v hlavičce | 25 px | 21 px |
| Zpět | chevron | šipka |
| Hlavní CTA | radius 13 | pill, radius 26 |
| Biometrie | "Přihlásit se přes Face ID" | "Odemknout otiskem prstu" |
| Spodní navigace | outline ikony, label 10.5 | plná aktivní ikona, label 11.5 |

## Design tokeny

`core/theme/` drží paletu (`AppColors` + `AppPalette` jako `ThemeExtension` pro
light/dark), typografii (`AppTextStyles`) a rozměry (`Insets`, `Radii`, `Sizes`).
App bar zůstává navy `#031E49` v obou režimech kvůli rychlé orientaci; badge
stavů jsou plné barvy kvůli čitelnosti na dálku a v rukavicích.

Další appka rodiny (RenoSales) převezme `core/` beze změny a vymění jen hodnoty
v `AppColors`.

## Testy

```
test/domain/     filtrování, řazení, pravidla stavů        (čistý Dart)
test/data/       mapování DTO, stream po mutaci, mock asset
test/widget/     login → seznam → detail → posun stavu, light/dark, iOS/Android
test/helpers/    FakeServiceOrderDataSource + builder zakázek
```

Widget testy nahrazují datový zdroj přes `ProviderScope.overrides`, takže běží
bez assetů a bez latence.
