# AGHealth — Project Status

**This file is the short operational source of truth for AGHealth's current state.** Read it first, every time, before starting any new AGHealth task. See §10 for the full rules.

Last updated: 2026-09-22 (сессия 4 — НОВЫЙ домен ПИТАНИЕ: реальный food tracker (FatSecret/Manual → backend → DB → iOS → дневная/недельная сводка → Dashboard). Заменил mock-заглушку питания и удалил legacy-импорт Excel/CSV. 163/163 backend-теста. FatSecret требует РУЧНОГО действия Анны (регистрация + credentials + IP-whitelist) — до этого работает ручной ввод и вся аналитика. См. «Current Task Checkpoint».)

_Previous: 2026-09-18 (сессия 3 — Фикс зависания при запуске (таймаут URLSession) + живые дашборды Здоровья (вес/сон/пульс покоя/HRV) + дашборд сна в обзоре + замеры шея/бицепс/рост + НОВЫЙ домен МЕДИЦИНА (лекарства с графиком/накоплением + напоминания на главной, анамнез, зрение, приёмы врачей с PDF). 136/136 backend-тестов.)_

_Previous: 2026-09-17 (вечер 2 — Measurements domain + Sleep-in-Health + Weight detail + Recovery detail + incremental SyncManager: NEW «Замеры» backend (вес + окружности, раздельно) + iOS деталка/добавление; Health получил вкладку «Сон» (дубль с переключателем дат) и деталку Веса с графиком; гипнограмма — ось времени; Восстановление — кликабельная деталка (статистика + «как считается»); Главная — кнопка синхронизации наверху, месячные наверх, дашборды реагируют на смену даты; SyncManager — настраиваемый период (по умолчанию неделя), инкрементально (только новое), синхрон при запуске. 125/125 тестов. См. «Current Task Checkpoint».)_

_Previous: 2026-09-17 (Sleep domain + deterministic Recovery + Home dashboards rework: body-map contrast fix (dimmed figure, saturated muscle colouring); NEW Sleep section (Apple-style hypnogram + weekly bar chart) fed by HealthKit `.sleepAnalysis` sync; deterministic Recovery score (sleep + training load, nutrition not yet a factor — confirmed with Anna); Home split into separate «Сон» and «Месячные» headed sections, cycle replaced by two dashboards (Месячные через X / ПМС идёт-будет через X). 112/112 backend tests. See «Current Task Checkpoint».)_

_Previous: 2026-09-16 (Muscle-influence overhaul — ALL 5 CHECKPOINTS SHIPPED. Primary/secondary muscle model; single muscle-load layer (volume Σ weight×reps + kcal intensity); interactive weekly analytics (expandable body-part → muscle); weight progression per exercise; exercise-detail muscle map; swimming stroke styles (HK sync + backend + detail + progress + per-style body-map mapping); redrawn front/back body map with level-1 (body part) + level-2 (muscle) highlighting; all sources (strength + running + swimming) on one map. 91/91 backend tests. Committed & pushed to both repos.)_

---

## IA Rework (prompt AGHEALTH_PROMT_16.09) — in progress

Правка информационной архитектуры аналитики тренировок. Логика расчёта (backend + muscle-load)
уже была сделана в предыдущем overhaul — не переписывается, только правильно размещается в UI.

**Референс body map (CP3):** зафиксирован в `docs/reference/CP3_bodymap_reference.md` (реалистичный
3D-манекен, зоны на теле, подсветка нагрузки, интерактивность). НЕ заменять абстрактной схемой.

**Ограничение среды:** на Linux-хосте нет Xcode/Swift → Build не выполняется здесь, только
структурная проверка (баланс скобок). Финальный build — на Маке.

### CP1 — Информационная архитектура: DONE (commit pending)
- `WorkoutsSectionView` — TAB-переключатель **Тренировки / Аналитика** (segmented Picker).
  - «Тренировки» = список (приватный `WorkoutsListView`).
  - «Аналитика» = NEW `WorkoutsAnalyticsView.swift`: `WeeklyMuscleSummaryView` (перенесена из
    списка) + ссылки «Прогресс силовых» и «Плавание».
- `MoreSectionView`: убраны «Прогрессия веса» и «Прогресс плавания» (перенесены).
  «Упражнения» + «Питомец» остались. Глобальное управление упражнениями — только в `ExercisesView`.
- Фикс двойной Add Exercise (`StrengthWorkoutView`): `AGSecondaryButton` показывается только
  когда есть выбранные упражнения (в empty-state CTA даёт `AGEmptyWorkoutCard`). Picker без global
  delete/edit/archive.
- Xcode: `PBXFileSystemSynchronizedRootGroup` → новый файл подхватывается авто, правка .pbxproj не нужна.
- Проверка: diff только 4 файла (+doc), несвязанные экраны не тронуты; баланс скобок OK. Build не
  выполнен (нет Xcode). Commit iOS `956191e`.

### CP2 — Сводка «Мышечная нагрузка тренировки» в WorkoutDetail: DONE (commit pending)
- Backend: `muscle-load.js` рефакторен — выделен общий `aggregateMuscleLoad({scope})`; `buildMuscleLoad`
  (окно) и НОВЫЙ `buildWorkoutMuscleLoad(workoutId)` используют ОДИН и тот же конвейер
  (volume → contribution → points → bands). Отдельной логики для WorkoutDetail НЕТ.
- `GET /workouts/:id` теперь возвращает `workout.muscleLoad` (в том же клиентском shape, что
  muscle-summary: `setEquivalents` = load points), группы + вложенные мышцы + totals.
- iOS: `APIClient.WorkoutDetail.muscleLoad` (новый optional) + `WorkoutMuscleLoad`; NEW
  `UI/WorkoutMuscleLoadView.swift` — интерактивная сводка (часть тела → мышцы), общий
  `MuscleLevelStyle`/`ProgressBar`; вставлена в `WorkoutDetailView` после stats.
- Тесты: 92/92 (+1 `buildWorkoutMuscleLoad` scoping test). Live: `GET /workouts/:id` отдаёт
  muscleLoad с точными числами (Спина/Ноги/Ягодицы/Плечи/Руки) = общий слой. Build iOS не выполнен.
  Commit iOS `77b5136` + BE (workspace) `33e42ec`.

### CP3 — Body map по референсу: DONE (commit pending)
- Решение Анны (2026-09-16): анатомичный вектор сам (без внешнего 3D-ассета).
- `UI/MuscleMapView.swift` перерисован: вместо прямоугольников/эллипсов — анатомичный силуэт
  женской фигуры (округлые плечи/талия/бёдра/сужающиеся бёдра) из Bezier-кривых + мышечные
  зоны-«blob» по контуру тела (front: грудь/дельты/бицепс/предплечья/пресс/косые/квадрицепс/
  икры; back: трапеция/широчайшие/разгибатели/трицепс/ягодичные/бицепс бедра/икры). Градиент-
  заливка для mannequin-вида.
- **API сохранён обратно совместимо:** `levels`, `muscleLevels`, `baseColor` — как были; добавлен
  опциональный `onSelect(groupKey)`. `ExerciseMuscleView` (level-2) работает без изменений.
- Интерактивность: тап по зоне мышцы на карте в недельной сводке раскрывает соотв. категорию
  (`focusedGroup`; `MuscleCategoryRow` теперь через `@Binding expanded`).
- Интеграция с нагрузкой: карта как и раньше ест `levels` из единого muscle-load слоя (силовые +
  бег + плавание) — одна мышца одинаково светится везде (task §8).
- Баланс скобок OK. ⚠️ **Визуально не проверено** (нет Xcode) — точность анатомии
  силуэта/зон требует проверки на Маке (возможна подгонка координат). Commit iOS `a05dd74`.

### CP4 — Swimming (диагностика end-to-end): DONE (commit pending)
**Диагноз по реальным данным (не заглушки):** в базе 3 реальных HealthKit-заплыва:
  575м и 500м (без стилей) + 1 тестовый 2400м (со стилями, уже soft-deleted). Реальные
  заплывы НЕ имеют stroke-style сегментов (Apple Health их не прислал).
- **Корень пустого блока:** `swimmingProgress()` агрегировал ТОЛЬКО из таблицы сегментов
  → заплывы без стилей давали 0. **Фикс:** прогресс теперь из САМИХ тренировок
  (distance/duration всегда есть), стили — опциональный overlay, никогда не выдумываются.
  Live: progress = 1075м / ~81мин / 2 недели, styleTotals=[] (честно).
- **HealthKit sync (iOS) — проверен, корректен:** `HealthKitSyncService.swimmingSegments()` читает
  `.segment` events + `HKMetadataKeySwimmingStrokeStyle`, мапит `HKSwimmingStrokeStyle`, при
  отсутствии стилей возвращает [] (`unknown` обрабатывается, ничего не выдумывает). Т.е.
  стилей нет потому, что их не было в Apple Health (открытая вода/ручной лог) — не баг sync.
- iOS UI: `SwimmingProgressView` показывает блок «По стилям» только при наличии стилей; иначе —
  честная заметка «Apple Health не передал разбивку по стилям…» + общая дистанция/время.
- Тесты: 93/93 (+1 регресс «style-less swims в progress»). Commit iOS `441e928` + BE (workspace) `a3ef91d`.

### CP5 — Strength progression (группировка + единый график): DONE (commit pending)
- Backend: `listExercisesWithHistory()` теперь возвращает `currentWeightKg` (последний top working
  weight) + `changeKg` (дельта к предыдущей сессии), та же метрика, что в exerciseProgression.
- iOS: `ExerciseProgressionView` перестроен: основной уровень — ГРУППА МЫШЦ (группировка
  по каноническому `muscleGroupKey`, единый label), внутри — упражнения с текущим весом и
  изменением (↑5/↓3 кг). `ProgressionGroup`/`ProgressionGroupSection`/`ProgressionExerciseRow`.
- **ОДИН единый график** `UnifiedProgressionChart`: выбор упражнения (сгруппированный Menu:
  группа → упражнение) ре-плотит `WeightLineChart` для ОДНОГО упражнения. Веса разных
  упражнений не смешиваются в одну линию (семантически корректно). Старый per-exercise
  экран-график больше не навигируется (россыпи графиков нет).
- `APIClient.ProgressionExercise` +`currentWeightKg`/`changeKg` (optional).
- Тесты: 94/94 (+1 CP5 current/change/grouping). Live: progression отдаёт текущий вес+дельту,
  ключи групп каноничны (back/chest/legs/glutes/shoulders/arms). Build iOS не выполнен.

---

## Доработки после ревью (2026-09-16 вечер)

### П.1 — Семантические цвета body map: DONE (commit pending)
- `MuscleIntensity.color()` теперь фиксированная шкала: нет→красный, низкая→оранжевый,
  средняя→жёлтый, высокая→зелёный. `MuscleLevelStyle.color()` делегирует туда же — бары
  в сводках и карта тела теперь одного цвета. Легенда подхватывает автоматически.

### П.3 — Стили плавания: FIX (commit pending)
**Диагноз уточнён (против предыдущего вывода):** стили В HealthKit ЕСТЬ (Анна видит их
  в приложении Фитнес) — это был НАШ баг, а не отсутствие данных. Две причины:
  1. `HKMetadataKeySwimmingStrokeStyle` — стиль ЛАПА (Apple docs: «predominant stroke style for a
     lap»), лежит на `distanceSwimming`-семплах (по лапам) и `.lap`-событиях. Мы читали
     ТОЛЬКО `.segment`-события, которых у бассейнных заплывов обычно нет.
  2. `distanceSwimming` НЕ был в readTypes HealthKit → лап-семплы вообще не читались.
- **Фикс:** `HealthKitSyncService.swimmingSegments()` переписан — primary: читает пер-лап
  `distanceSwimming`-семплы (`predicateForObjects(from: workout)`) + их style-метаданные,
  fallback: `.lap`/`.segment`-события. `HealthKitManager` — добавлен `.distanceSwimming` в readTypes.
  Стили никогда не выдумываются.
- ⚠️ Старые 2 заплыва (575м/500м) синхронизированы ДО фикса → без стилей. После rebuild+re-sync
  POST идемпотентен по HK-UUID и перешлёт сегменты (replaceForWorkout) → стили подтянутся.
- ⚠️ Apple спросит разрешение на новый тип (Swimming Distance) при первом запуске после rebuild.

### П.2 — Силуэт body map: DONE (commit pending)
- Решение Анны: вшить готовый анатомический ассет (CC BY-SA).
- Ассет: «Muscles front and back» (Wikimedia Commons, OpenStax & T. Kebert & umimeto.org),
  **CC BY-SA 4.0**. SVG → PNG, разрезан на фронт/спину, добавлен в `Assets.xcassets`
  (`BodyFront`, `BodyBack`, @1x/@2x/@3x).
- `MuscleMapView` переписан: база — `Image("BodyFront/BodyBack")`, поверх — подсветка
  мышц (RadialGradient-эллипсы) в нормализованных координатах под анатомию. API сохранён
  (`levels`/`muscleLevels`/`baseColor`/`onSelect`) — `ExerciseMuscleView` + недельная сводка без изменений.
- Атрибуция: `BodyMapAttribution` под картой + `docs/reference/ASSET_ATTRIBUTION.md`.
- Координаты зон проверены оффлайн (наложение эллипсов на реальные PNG) — ложатся на
  нужные мышцы (грудь/пресс/квадрицепс/трапеция/широчайшие/ягодичные/бицепс бедра…).
  ⚠️ Финальная визуальная проверка — на Маке; координаты легко подкрутить в MuscleRegionLibrary.
- ⚠️ Новые имейджсеты в .xcassets подхватятся Xcode автоматически (ассет-каталог компилируется).

---

## Финальная проверка (§11 промта) — 2026-09-16
1. git status: чисто после коммитов (не запушено — по требованию).
2. progression БОЛЬШЕ НЕ в «Ещё» — в «Тренировки → Аналитика». ✅
3. swimming progress БОЛЬШЕ НЕ в «Ещё» — в Аналитике. ✅
4. Таб Тренировки / Аналитика — есть (segmented Picker). ✅
5. WorkoutDetail — сводка «Мышечная нагрузка тренировки». ✅
6. Analytics — body map + summary. ✅
7. Реальные swimming workouts отображаются (575м+500м). ✅
8. HealthKit stroke styles — sync читает корректно; у этих заплывов стилей нет (честно). ✅
9. progression — группировка + единый график. ✅
10. Двойная Add Exercise — исправлена. ✅
11. Статическая проверка: 94/94 backend-теста; iOS — баланс скобок OK.
12. **Build НЕ выполнен: Xcode отсутствует (Linux-хост).** Финальный build/визуал — на Маке.

---

## Current Task Checkpoint

Task: Сессия 4 (2026-09-22) — ПИТАНИЕ (промт AGHEALTH_FOOD_21092026): реальный трекинг еды.

Status: DONE локально (backend 163/163 + живой + задеплоен; iOS запушен; финальная сборка на Маке).
**Единственный оставшийся ручной блок — регистрация FatSecret Анной (см. ниже).**

### Что сделано

**Backend (`coach/aghealth-backend`, домен nutrition):**
- Схема (идемпотентно): `foods` (каталог, КБЖУ НА 100 Г, source=fatsecret|manual, external_id, serving_*),
  `food_entries` (факт употребления: date/meal_type/food/grams + СНИМОК calc_* КБЖУ), `nutrition_goals`
  (дневная цель, singleton id=1). Каталог и факт РАЗДЕЛЕНЫ (промт §6). Soft-delete везде.
- `nutrition/nutrition-model.js` — ЕДИНЫЙ источник расчёта КБЖУ (per-100g × grams; remaining/over vs goal,
  превышение отдельно, не отрицательный remaining — промт §7).
- `nutrition/fatsecret.js` — провайдер: OAuth2 client_credentials (токен-кэш в памяти 24ч),
  `foods.search` → нормализация в 100 г (grams/ml serving, приоритет «100 g»). **Без credentials
  → NotConfiguredError/isConfigured=false.** Кэширование каталога НЕ делаем (Basic Free запрещает).
- `nutrition/nutrition-summary.js` — день (5 приёмов + итоги + цель + осталось/превышение) и неделя
  (съедено из entries vs ПОТРАЧЕНО из `fitness_workouts.energy_burned_kcal` — существующий источник §12;
  средние КБЖУ, дни в цели/превышении).
- Роуты: `GET /nutrition/foods/search`, `GET /nutrition/fatsecret/status`, `POST/GET /nutrition/foods`,
  `POST /nutrition/entries`, `DELETE /nutrition/entries/:id`, `GET /nutrition/day`, `GET /nutrition/week`,
  `GET/PUT /nutrition/goal`. Тесты: +18 (163/163). Живо проверено на 100.123.202.44:8791.

**iOS (`aghealth-work`, «Fitness API»):**
- `APIClient.swift` — модели (Food/FoodSearchResult/FoodEntry/Macros/NutritionGoal/NutritionDay/
  NutritionWeek…) + методы (searchFoods с graceful 503→configured:false, createFood, createFoodEntry,
  deleteFoodEntry, fetchNutritionDay/Week/Goal, saveNutritionGoal, fetchFatSecretConfigured).
- `NutritionSectionView.swift` — ПЕРЕПИСАН с mock на реальные данные (NutritionStore @MainActor).
  Табы День/Аналитика. NEW `NutritionDayScreen` (итоги дня + 5 приёмов + удаление entry),
  `AddFoodFlowView` (поиск каталога с debounce/пагинация/пусто/ошибка/нет-сети + «Вручную» +
  attribution FatSecret), `FoodQuantityView` (граммы/порции + живой пересчёт КБЖУ), `ManualFoodView`
  (ручной продукт на 100 г), `NutritionAnalyticsScreen` (график съедено-вверх/потрачено-вниз §11 +
  средние КБЖУ + выполнение цели §13).
- `HomeSectionView.swift` — `HomeNutritionCard` теперь ЖИВОЙ (сегодня X/Goal ккал+КБЖУ из backend).
  **Заглушка импорта Excel/CSV удалена навсегда** (NutritionImportView и весь mock снесены).
- `SettingsView.swift` — NEW `NutritionGoalSettingsView` (цель КБЖУ, грузится/сохраняется через backend, §8).
- Проверено структурно (баланс скобок + резолв символов AGContentColors/AGPrimaryButton/ErrorCard;
  новые файлы авто-подхватятся через PBXFileSystemSynchronizedRootGroup). Swift-тулчейна на Linux нет →
  финальный build/визуал на Маке.

### ⚠️ Что должна сделать Анна (ЕДИНСТВЕННЫЙ ручной блок — FatSecret)
Без этого работает ручной ввод + вся аналитика; НЕ работает только поиск по каталогу.
1. Зарегистрироваться на https://platform.fatsecret.com/ (Basic — self-signup, бесплатно; или
   Premier Free — apply, для стартапов/НКО/студентов, verification).
2. Создать application → получить **Client ID** и **Client Secret** (Secret показывается 1 раз — скопировать).
3. **Вписать IP бэкенда в whitelist** приложения (OAuth2 требует IP-whitelisted proxy). IP —
   внешний egress хоста бэкенда (уточнить `curl ifconfig.me` на сервере) / диапазон CIDR.
4. Встроить attribution — УЖЕ сделано в UI (бейдж «fatsecret Platform API» под результатами поиска).
5. Передать ключи агенту → положить в `/root/.openclaw/secrets/aghealth-backend.env` как
   `FATSECRET_CLIENT_ID` / `FATSECRET_CLIENT_SECRET` (+ опц. `FATSECRET_SCOPE=basic`). НЕ в чат, НЕ в git,
   НЕ в iOS bundle. После — рестарт `aghealth-backend.service`, `status` вернёт configured:true.

### Ограничения бесплатного тарифа (промт §19)
Basic Free: 5000 запросов/день, **база US-only** (для рос. продуктов слабовата → ручной ввод важен),
англ., **кэширование запрещено**, attribution обязателен. При превышении лимита поиск отдаст ошибку →
UI предложит ручной ввод. Barcode/NLP/image — НЕ делаем (промт §20). Альтернатива для RU (если US-база
не устроит) — Open Food Facts (бесплатно, RU, без IP-whitelist) — обсудить с Анной отдельно.

Next Action: на Маке — собрать/запустить; проверить питание (день/приёмы/ручной ввод/аналитика/цель/
Dashboard-блок). Отдельно: Анна регистрирует FatSecret → передаёт ключи → включаю каталожный поиск.

Do not: удалять данные питания; трогать существующие экраны сверх блока питания; кэшировать каталог
FatSecret (Basic запрещает); переключаться на платный тариф молча.

---

## Previous Task Checkpoint

Task: Сессия 3b (2026-09-18) — правки по отзыву Анны.

Status: DONE (backend 137/137 + живой; iOS запушен; финальная сборка на Маке).

- **Главная — лекарства:** причина «нет дашборда» — /upcoming показывал только daily/weekly-в-свой-
  день. Теперь возвращает ВСЕ лекарства (missed/due/scheduled/taken + nextDate); iOS-карточка
  показывает статусы и дату следующего приёма.
- **Вес → рост:** в форме «Вес» добавлено поле Рост; рост в гриде/истории замеров (backend
  height_cm уже был).
- **Анамнез:** теперь экран ПРОСМОТРА (AnamnesisReadCard), редактирование — отдельно
  (AnamnesisEditView, sheet) + кнопка «Выгрузить в PDF» (AnamnesisPDF — красивый шаблон
  медкарты, UIGraphicsPDFRenderer + QuickLook).
- **Лекарства:** свайп-удаление (List + .swipeActions → archiveMedication).

Files: backend `routes/medicine.js`, `test/medicine.test.js`; iOS `HomeSectionView.swift`,
`HealthMeasurementsView.swift`, `AnamnesisView.swift`, NEW `AnamnesisPDF.swift`, `MedicationsView.swift`,
`APIClient.swift`. Ничего не удалено из данных.

---

## Previous Task Checkpoint

Task: Сессия 3 (2026-09-18) — фикс зависания при запуске; живые дашборды Здоровья + дашборд сна;
замеры шея/бицепс/рост; новый домен Медицина (лекарства/анамнез/зрение/приёмы врачей).

Status: DONE (backend committed+live+136/136; iOS committed+pushed; финальная сборка на Маке).

Completed — backend (openclaw-backup):
- **Замеры:** +neck_cm/biceps_cm/height_cm (идемпотентно, без потери данных). height_cm — рост для анамнеза.
- **Медицина (NEW):** таблицы medications(+intakes), anamnesis(singleton), vision_records,
  doctor_visits(+PDF на диске). `repositories/medicine.js` + `routes/medicine.js`:
  · Лекарства: CRUD, отметка приёма (накапливаемые → accumulated), график intakes,
    `GET /medications/upcoming` для главной (due/taken, детерминированно).
  · Анамнез: GET/PUT singleton (списки как JSONB).
  · Зрение: create/list/latest/delete. · Приёмы: create/list по kind (history/plan)/delete +
    загрузка/выдача PDF (raw body до 20МБ, хранение в uploads/).
- Тесты: 136/136 (+8 замеры/сон, +11 медицина).

Completed — iOS (AGHealth):
- **Фикс зависания:** APIClient → собственная URLSession с таймаутом (15с/30с,
  waitsForConnectivity=false). Раньше URLSession.shared висел 60+с при недоступном бэкенде
  (tailnet-адрес без VPN) — приложение выглядело замороженным до Stop.
- **Здоровье → Общее:** HealthMetricsGrid на реальных данных (вес/сон — backend; пульс
  покоя/HRV — HealthKit через новый HealthKitVitalsService). Добавлен дашборд Сна в обзор.
- **Замеры:** Шея и Бицепс в грид/историю/форму (Плечо и остальное не тронуты).
- **Медицина (NEW экраны):** MedicationsView (карточки-сводки + график приёма +
  накоплено/цель + добавление); HomeUpcomingMedsCard («ближайшие лекарства» + Принято/
  Пропущено); AnamnesisView (1 карточка, вес/рост/зрение подтягиваются, линк хроники к
  лекарству); VisionView; DoctorVisitsView (История/План + PDF через fileImporter/QuickLook).
- APIClient: модели/методы всей Медицины + помощники postJSON/putJSON/deletePath.

Files changed:
- Backend: `src/db/schema.sql`, `repositories/measurements.js`, `routes/measurements.js`,
  NEW `repositories/medicine.js`, NEW `routes/medicine.js`, `server.js`, `test/helpers.js`,
  `test/measurements.test.js`, NEW `test/medicine.test.js`, `.gitignore`.
- iOS: `Synchronization/APIClient.swift`, NEW `HealthKit/HealthKitVitalsService.swift`,
  `HealthKit/HealthKitManager.swift`, `UI/HealthSectionView.swift`, `UI/HealthMeasurementsView.swift`,
  `UI/HomeSectionView.swift`, NEW `UI/MedicationsView.swift`, NEW `UI/VisionView.swift`,
  NEW `UI/AnamnesisView.swift`, NEW `UI/DoctorVisitsView.swift`.

API: /api/v1/medications(+/upcoming,/:id,/:id/intakes), /anamnesis (GET/PUT), /vision(+/:id),
/visits(+?kind,/:id,/:id/pdf GET+POST). Замеры: +neckCm/bicepsCm/heightCm.

Зависание Xcode — заметка: «принудительно открывается» = настройка схемы (Wait for the
executable to be launched). Основная причина мороза — висящие сетевые запросы к недоступному
бэкенду; теперь с таймаутом 15с. Если мороз останется — проверить доступность 100.123.202.44
с телефона (Tailscale/VPN).

Next Action: на Маке — собрать/запустить; проверить запуск (не виснет), живые дашборды
Здоровья, замеры шея/бицепс, весь раздел Медицина (лекарства+накопление, напоминания
на главной, анамнез, зрение, приёмы врачей + PDF).

Do not:
- удалять данные (замеры/вес и пр.); менять лишнее без запроса.

---

## Previous Task Checkpoint

Task: Measurements domain + Sleep-in-Health + Weight/Recovery details + incremental Sync + Home
rework (prompt AGHealth 2026-09-17 вечер 2).

Status: DONE (backend committed+live+125/125; iOS committed+pushed; final Xcode build on the Mac).

Completed — backend (`coach/aghealth-backend`, pushed to openclaw-backup):
- **Measurements domain:** `body_measurements` table (weight_kg + waist/hips/chest/thigh/arm_cm, all
  nullable — вес и замеры логгируются раздельно), soft-delete. `repositories/measurements.js` +
  `routes/measurements.js`: POST /api/v1/measurements, GET /measurements (+latest-per-metric),
  GET /measurements/weight?days= (график веса), DELETE /measurements/:id. +8 tests.
- **Sleep day switcher:** `GET /api/v1/sleep/day?date=YYYY-MM-DD` + `availableNights[]`. +2 tests.
- Tests: 125/125 (was 116).

Completed — iOS (pushed to AGHealth):
- **SyncManager (NEW, `Synchronization/SyncManager.swift`):** централизованная синхронизация.
  Настраиваемый период (UserDefaults, по умолчанию 7 дней). ИНКРЕМЕНТАЛЬНО: помнит уже
  залитые HealthKit-id и шлёт только новое (последнюю ночь всегда обновляет). Синхрон при
  запуске/активации (не чаще 1/30мин), только после первой ручной синхры (чтобы первый запуск
  не вызывал диалог разрешений — против «зависания»). App: асинхронный launch-sync (.task +
  scenePhase). SettingsView: Stepper периода, старый инлайн-sync удалён.
- **Home:** кнопка синхронизации вверху (`HomeSyncBar`, по умолчанию неделя, только новое); «Месячные»
  перенесены наверх; RecoveryCard → кликабельная `RecoveryDetailView`; дата-селектор теперь
  реально меняет карточки (сон выбранной ночи через ?date=, тренировка того дня); дашборды
  обновляются после синхры.
- **RecoveryDetailView (NEW):** балл + факторы (сон/нагрузка/питание-плейсхолдер) + прозрачное
  описание «как считается».
- **Sleep:** переключатель дат (←/→ по availableNights) + ОСЬ ВРЕМЕНИ под гипнограммой
  (`HypnogramWithAxis`, HH:mm); режим `embedded` для встраивания.
- **Health:** новая вкладка «Сон» (дубль SleepSectionView с переключателем); «Вес» → `WeightDetailView`
  (график 1М/3М/1Г/Всё + текущий/дельта); «Замеры» (`HealthMeasurementsView`) переписаны на
  реальные данные + `AddMeasurementView` (вес/замеры РАЗДЕЛЬНО).
- **APIClient:** Measurement*/Weight*/SleepDay.availableNights + fetchMeasurements/fetchWeightSeries/
  createMeasurement/fetchSleepDay(date:).

Files changed:
- Backend: `src/db/schema.sql`, NEW `repositories/measurements.js`, NEW `routes/measurements.js`,
  `repositories/sleep.js`, `fitness/sleep-summary.js`, `routes/sleep.js`, `server.js`, `test/helpers.js`,
  NEW `test/measurements.test.js`, `test/sleep.test.js`.
- iOS: NEW `Synchronization/SyncManager.swift`, `Fitness_APIApp.swift`, `Synchronization/APIClient.swift`,
  `UI/HomeSectionView.swift`, NEW `UI/RecoveryDetailView.swift`, `UI/SleepSectionView.swift`,
  `UI/HealthSectionView.swift`, `UI/HealthMeasurementsView.swift`, NEW `UI/WeightDetailView.swift`,
  `UI/SettingsView.swift`.

API / backend changes: POST/GET/DELETE /api/v1/measurements(+/weight); GET /sleep/day?date=.

Tests: 125/125 backend passing. iOS verified structurally (brace balance + symbol resolution; new
files auto-included via PBXFileSystemSynchronizedRootGroup). No Swift toolchain on the Linux host →
final Xcode build/visual on the Mac.

Xcode launch notes (для Анны): «принудительно открывается» = настройка схемы Xcode (Edit
Scheme → Run → Info → Launch → «Wait for the executable to be launched»), не код приложения.
«Виснет до Stop» — поведение отладчика; с кодовой стороны launch теперь полностью асинхронный
и не вызывает диалог разрешений на старте.

Next Action: на Маке — собрать/запустить; дать разрешения Apple Health; проверить: (a) кнопка синхры
вверху грузит только новое; (b) смена даты меняет дашборды; (c) Health→Сон с переключателем;
(d) Health→Вес график; (e) Замеры → «+» → добавить вес/замеры; (f) ось времени на гипнограмме;
(g) клик по Восстановлению → деталка.

Do not:
- менять что-либо сверх явно запрошенного (просьба Анны); удалять данные.
- добавлять nutrition в recovery пока нет источника данных.

---

## Previous Task Checkpoint

Task: Bugfix — Swift compile error in sleep id + restore in-workout exercise picker (2026-09-17 вечер).

Status: DONE (backend committed+tests green; iOS committed; final Xcode build on the Mac).

Completed:
- **Swift compile error (`HealthKitSleepService.deterministicID`):** the previous code used an invalid
  expression `let idx = hex.index(hex.startIndex, offsetBy:)` (no argument) → «Expected expression» /
  «No exact matches in call to ‘index’». Rewrote the UUID formatting to build the canonical
  8-4-4-4-12 string directly from the 16 byte groups (`hex(0..<4)`…`hex(10..<16)`). Verified the
  algorithm yields a valid, stable UUID and distinct nights → distinct ids.
- **In-workout exercise picker showed no list (regression):** the plumbing (empty-card CTA →
  `showingExercisePicker` → `fullScreenCover` → `ExercisePickerView`) was intact, but the picker only
  rendered the list the parent passed; if the parent's async `loadExercises()` hadn't finished when
  the sheet opened, the picker showed «Упражнения не загружены» and never recovered. Fix: made
  `ExercisePickerView` self-sufficient — if the passed list is empty it loads the catalog itself
  (`.task { await load() }`), shows a spinner while loading, and an «Обновить» retry on error;
  removed the `.disabled(exercises.isEmpty)` guard on the secondary «Добавить упражнение» button.
  Backend catalog verified live: 177 active exercises returned correctly (the API was never the
  problem).

Files changed:
- iOS: `Fitness API/HealthKit/HealthKitSleepService.swift`, `Fitness API/UI/StrengthWorkoutView.swift`.
- Backend (tests only): NEW `test/exercise-picker-contract.test.js`, `test/sleep.test.js` (+deterministic-id test).

Tests: 116/116 backend passing (was 112; +3 picker-contract, +1 deterministic sleep-id). The picker-
contract tests guard the exact `GET /exercises` shape the iOS picker decodes (id/name/archivedAt/
numeric `muscles[].contribution`), so a future backend shape drift that would silently empty the
picker fails loudly. iOS verified structurally (brace balance + symbol resolution). No Swift toolchain
on the Linux host → final Xcode build on the Mac.

Next Action: on the Mac — build (the sleep id compile error is fixed) & run; open a workout →
«Добавить упражнение» → confirm the exercise list appears (spinner → 177 exercises).

Do not:
- reintroduce a second always-visible «Добавить упражнение» button in the empty state (that was the
  original CP1 double-button bug); the empty-state card CTA is the single entry there.

---

## Previous Task Checkpoint

Task: Sleep domain + deterministic Recovery + Home dashboards rework (prompt AGHealth 2026-09-17).

Scope (from Anna): (1) body-map contrast in Тренировки→Аналитика (dim the figure, saturate muscle
colouring); (2) design + build the Sleep section from Apple Health with Apple-style graphs; (3) a
DETERMINISTIC (not AI) recovery score from sleep + training + food — food doesn't exist yet, so
Anna's guard was «если без еды нельзя — ничего не делай». Confirmed with Anna (2026-09-17): recovery
IS defensible from sleep + training load now, nutrition added later; (4) Home: sleep dashboard
(day/week), remove the single «Цикл» card, replace with two dashboards «Месячные через X» and
«ПМС идёт/будет через X», with SEPARATE headed «Сон» and «Месячные» sections.

Status: DONE (backend committed+live; iOS committed; final Xcode build/visual on the Mac).

Completed:
- **Body-map contrast (`MuscleMapView.swift`):** base anatomical figure dimmed (`.opacity(0.45)`
  `.saturation(0.35)`); muscle overlay opacity raised (low .70 / med .82 / high .95), solid
  saturated core in the RadialGradient (fills to 1.35 radius), more saturated semantic colours. Muscle
  load no longer «loses» against the illustration.
- **Backend Sleep domain (`coach/aghealth-backend`, committed BE):** `sleep_sessions`+`sleep_segments`
  tables (idempotent schema); `repositories/sleep.js` (upsert by HealthKit-derived id, segment
  replace, latest/recent, efficiency); `fitness/sleep-summary.js` (day: latest night + hypnogram +
  deterministic rating; week: per-night totals + averages); routes `POST /api/v1/sleep/sessions`,
  `GET /api/v1/sleep/day`, `GET /api/v1/sleep/week`.
- **Backend Recovery (deterministic):** `fitness/recovery.js` — score 0..100 =
  sleepScore(duration piecewise + efficiency ±8) − loadPenalty(training-load points last 72h, cap 25);
  fixed band table + verdict. Nutrition flagged `available:false` (documented placeholder, no term
  yet). `hasData:false` when no sleep — never invents a number. `GET /api/v1/recovery`.
- **iOS HealthKit sleep:** `.sleepAnalysis` added to read permissions (`HealthKitManager`); NEW
  `HealthKitSleepService.swift` groups samples into per-night sessions (4h-gap split, ≥30min asleep),
  maps stages (deep/core/rem/awake/inbed/asleep), deterministic per-night id; `SettingsView` manual
  sync now also pushes sleep sessions (idempotent, isolated error handling).
- **iOS APIClient:** `SleepSession/SleepSegment/SleepDay/SleepWeek/SleepNight`, `Recovery`;
  `createSleepSession`, `fetchSleepDay/Week`, `fetchRecovery`; generic `getDecoded` helper.
- **iOS Sleep screen (`SleepSectionView.swift`):** Apple-style `HypnogramView` (stage bands across
  the night in lanes), stage breakdown, weekly `SleepWeekChart` (per-night bars + dashed goal line),
  honest empty/error states.
- **iOS Home (`HomeSectionView.swift`):** `RecoveryCard` now fetches `/recovery` (real score + factor
  chips, honest empty state); NEW headed «Сон» section with `HomeSleepCard` (last-night duration +
  mini hypnogram + weekly avg, links to Sleep screen); removed `HomeCycleCard`, NEW headed «Месячные»
  section with `HomeCycleDashboards` = two tiles «Месячные» (Идут / через X дней) and «ПМС» (Идёт /
  через X), computed from HealthKit `CycleAnalytics` (predictedNextPeriod / predictedPMSStart-End).
  `HomeHealthCard` no longer shows a fake «Сон 7ч42м».

Files changed:
- Backend: `src/db/schema.sql`, NEW `src/repositories/sleep.js`, NEW `src/fitness/sleep-summary.js`,
  NEW `src/fitness/recovery.js`, NEW `src/routes/sleep.js`, NEW `src/routes/recovery.js`, `src/server.js`,
  `test/helpers.js`, NEW `test/sleep.test.js`, NEW `test/recovery.test.js`.
- iOS: `Fitness API/HealthKit/HealthKitManager.swift`, NEW `Fitness API/HealthKit/HealthKitSleepService.swift`,
  `Fitness API/Synchronization/APIClient.swift`, `Fitness API/UI/SettingsView.swift`,
  `Fitness API/UI/MuscleMapView.swift`, `Fitness API/UI/HomeSectionView.swift`,
  NEW `Fitness API/UI/SleepSectionView.swift`.

API / backend changes:
- NEW `POST /api/v1/sleep/sessions` (idempotent upsert), `GET /api/v1/sleep/day`, `GET /api/v1/sleep/week?days=`,
  `GET /api/v1/recovery`. All under the standard Bearer auth.

Tests: 112/112 backend passing (was 94; +8 sleep, +10 recovery). Live-verified: `/recovery`,
`/sleep/day`, `/sleep/week` return honest `hasData:false` before any sleep is synced; service
restarted. iOS verified structurally (brace/paren/bracket balance + symbol resolution + no dangling
refs; new files auto-included via `PBXFileSystemSynchronizedRootGroup`). No Swift toolchain on the
Linux host → final Xcode build/visual on the Mac.

Next Action: on the Mac — build & run; grant the new Apple Health «Анализ сна» permission; tap
«Синхронизировать сейчас» to pull sleep; verify (a) Аналитика body-map muscle colours now read
stronger than the figure; (b) Home shows a real recovery score once sleep is synced; (c) Sleep screen
hypnogram + weekly chart; (d) Home «Сон» and «Месячные» headed sections with the two cycle tiles.

Do not:
- add a nutrition term to recovery until a nutrition data source exists (keep the placeholder shape).
- invent sleep stages / recovery numbers where HealthKit gave nothing (honest `hasData:false`).
- redesign existing screens beyond the added blocks/headings.

---

## Previous Task Checkpoint

Task: Muscle-influence model overhaul — primary/secondary muscles, real load calculation (weight/reps/volume + kcal), interactive weekly analytics, weight progression, exercise-detail muscle map, running + swimming (styles) mapping, and a redrawn front/back body map. All fed by ONE shared muscle-load layer.

Phase plan / status (5 checkpoints):
- **Checkpoint 1 — Muscle model (primary/secondary) + catalog + create/edit forms: DONE (committed).**
- **Checkpoint 2 — Unified muscle-load calc (volume + kcal) + weekly summary + expandable categories: DONE (committed).**
  - NEW `src/fitness/muscle-load.js` (`buildMuscleLoad`): strength volume = Σ(weight×reps) split by contribution; bodyweight fallback; kcal intensity factor; cardio via shared layer; per-group + per-muscle bands. `muscle-summary.js` rewritten as a thin adapter over it.
  - Formula documented above in "Логика расчёта нагрузки на мышцы".
  - iOS: `MuscleSummary`/`MuscleGroupLoad` gain `muscles[]` + `strengthVolume`; `WeeklyMuscleSummaryView` shows ALL categories, tap-to-expand into specific muscles (high/medium/low/none); `MuscleLevelStyle` shared helper.
  - Tests: 78/78 (+10 `test/muscle-load.test.js`). Live: summary is volume-based (legs 64.2 high, forearms 0 none), strengthVolume=15132.
- **Checkpoint 3 — Weight progression graph + exercise-detail muscle map: DONE (committed).**
  - Backend: NEW `src/fitness/progression.js` + `src/routes/progression.js`. `GET /api/v1/fitness/progression` (exercises with history, recent first) and `GET /api/v1/fitness/exercises/:id/progression?days=` (one series, never mixed; metric = top working weight per workout, + topReps + volume). Tests: 82/82 (+4).
  - iOS: `APIClient` progression models + fetchers; NEW `UI/ExerciseProgressionView.swift` (exercise list → weight line chart drawn with SwiftUI Path + weight/reps/volume table); NEW `UI/ExerciseMuscleView.swift` (exercise muscle map reusing the SAME `exercise.muscles` mapping); NEW `UI/ExerciseDetailView.swift` (opened from the «Упражнения» directory: muscle map + progression link). «Прогрессия веса» added under Ещё → Мои данные.
- **Checkpoint 4 — Swimming styles (HK sync + backend + UI + progress): DONE (committed).**
  - Backend: NEW `fitness_workout_swimming_segments` table (style/distance/time per workout, idempotent). NEW `src/repositories/swimming.js` + `src/routes/swimming.js` + `src/fitness/swimming-muscle-map.js`. POST workout accepts `swimmingSegments[]` (validated; bad style → 400; unknown/mixed allowed); GET workout adds `swimming` breakdown for swimming; `GET /api/v1/fitness/swimming/progress?weeks=` (per-week + per-style totals). Per-style muscle mapping feeds the body map via `muscle-load.js` (falls back to generic swimming when styles unknown). Tests: 89/89 (+8).
  - iOS: `HealthKitSyncService` reads stroke styles from `.segment` workout events (`HKMetadataKeySwimmingStrokeStyle`) + per-segment `distanceSwimming`; only real styles forwarded (never invented). `APIClient` gains `SwimmingSegmentInput`, `WorkoutDetail.swimming`, `fetchSwimmingProgress`; sync sends segments. NEW `UI/SwimmingViews.swift` (per-style breakdown in workout detail + `SwimmingProgressView`); «Прогресс плавания» under Ещё → Мои данные.
  - Live-verified: swim POST → detail per-style breakdown (2.4 км / freestyle 1400 / breaststroke 800 / backstroke 200) + progress by style. Test workout cleaned up (soft-deleted); progress excludes deleted workouts.
- **Checkpoint 5 — New body map (MuscleMapView redraw) + all-source integration: DONE (committed).**
  - iOS: `UI/MuscleMapView.swift` redrawn — smoother curved anatomical silhouette, muscle regions visually separated, front+back, 4 intensity levels, neutral untrained. Architecture now supports TWO levels: `levels: [groupKey: level]` (level 1) AND optional `muscleLevels: [muscle: level]` (level 2). `ExerciseMuscleView` passes per-muscle levels so exercise-detail highlights the exact muscles.
  - Integration: the weekly body map already aggregates strength + running + swimming via the single `muscle-load.js` layer. Backend test `muscle-map-integration.test.js` proves strength (chest/arms) + running (legs/glutes) + swimming butterfly (shoulders/back/chest) light up together on one map. Tests: 91/91 (+2).

Design decisions locked (do not re-derive):
- **Muscle influence = normalized table `fitness_exercise_muscles`** (`exercise_id, group_key, muscle, role, contribution, body_region`). One exercise → 1 primary + N secondary muscles. This is the SINGLE source of truth `exercise → body part → muscle → role/contribution`. The denormalized columns on `fitness_exercises` (`muscle_group`, `muscle_group_key`, `muscle`, `body_region`) are kept as the PRIMARY convenience copy for the picker/legacy readers and are derived from the primary muscle-map row.
- **Contribution coefficients (fixed, in `src/fitness/muscle-model.js`):** primary = **1.0**, secondary = **0.5** default, with lighter assists = **0.3** for muscles that help less. The UI only ever shows the role («Основная»/«Дополнительная»); the numeric weight lives in the model, never in the UI. Any value in (0, 1] is valid.
- **Single source of truth module = `src/fitness/muscle-model.js`** — canonical group keys, contribution constants, group labels, and `body_region` resolution. Catalog seed, load calc, weekly summary, body map and exercise detail all read from it.
- **Seed safety improved:** `applyCatalogV2()` now archives only old exercises that have **no** historical sets. Exercises the user actually used stay ACTIVE across re-seeds (never removed from the picker). History/FK always preserved.

Completed (Checkpoint 1):
- Backend (`openclaw-backup` → `coach/aghealth-backend/`):
  - `src/db/schema.sql` — new `fitness_exercise_muscles` table + indexes (idempotent).
  - NEW `src/fitness/muscle-model.js` — group keys, ROLE_CONTRIBUTION {primary:1.0, secondary:0.5}, labels, region resolution, `normalizeGroupKey`.
  - `src/seed/exercise-catalog-v2.js` — derives group keys/region from muscle-model; adds a data-driven secondary-muscle mapping (`SECONDARY_BY_PATTERN`) so compound lifts (румынская тяга → +ягодицы +разгибатели; жим лёжа → +трицепс +перед. дельта; etc.) carry secondaries; each exercise now exposes `muscles: [primary, ...secondary]`. 79 of 171 catalog exercises have secondaries.
  - NEW `src/repositories/exerciseMuscles.js` — list/replace the muscle mapping.
  - `src/repositories/exercises.js` — `upsertWithMuscles()`, list/find/update/archive attach `muscles`; denorm columns derived from the primary.
  - `src/routes/exercises.js` — create/PATCH accept structured `{ primary, secondary[] }` (or a raw role-tagged `muscles[]`), and still accept the legacy `{ muscleGroup }` shape. Invalid body part → 400.
  - `src/seed/seed-catalog-v2.js` — writes the mapping rows; archives only history-free old exercises.
- iOS (`aghealth-work`):
  - NEW `Fitness API/UI/MuscleCatalog.swift` — client body-part→muscles catalog (mirrors backend vocabulary) driving the pickers.
  - `Synchronization/APIClient.swift` — `ExerciseMuscle` model + `Exercise.muscles` + `primaryMuscle`/`secondaryMuscles`; structured `createExercise/patchExercise(primary:secondary:)`; legacy overloads preserved.
  - `UI/ExercisesView.swift` — rewritten `ExerciseEditorView`: «Основное влияние» (часть тела → мышца) + «＋ Добавить дополнительную мышцу» (N secondaries), via a chained `MusclePickerRow`. No technical coefficients shown.

API / backend changes:
- `POST /api/v1/fitness/exercises` and `PATCH /api/v1/fitness/exercises/:id` accept `{ primary:{bodyPart,muscle?}, secondary:[{bodyPart,muscle?,contribution?}] }`; response `exercise.muscles[]` added. Legacy `{ muscleGroup }` still works.
- `GET /api/v1/fitness/exercises` now returns `muscles[]` per exercise.

Tests: 68/68 backend passing (was 58; +9 new `test/exercise-muscles.test.js` + reworked catalog-v2 archive tests). Live dev: migration + seed applied; 177 active exercises (171 v2 + 6 restored real user exercises with history), 325 muscle-map rows; RDL/bench return primary+secondary live. Service restarted.

Live-data note: the v2 re-seed initially archived 6 real user-created exercises (with history); they were restored to ACTIVE + given a primary muscle-map row, and the seed was fixed so this can't recur.

iOS verified structurally (brace/paren/bracket balance + symbol check — `AGColors`, `AGPrimaryButton`, `ErrorCard` exist). No Swift toolchain on the Linux host → final Xcode build is on the Mac.

Last safe commit:
- iOS: `0ace586` · Backend: `2ba481a` (CP1). Later commits: CP2 iOS `dc9f217`/BE `4c65356`; CP3 iOS `cd1ee6f`/BE `7bfc882`; CP4 iOS `f1fe593`/BE `b3d872c`; CP5 iOS `9b8d207`/BE `e95c0b4`.

Next Action: NONE — all 5 checkpoints of the muscle-influence overhaul are complete, committed and pushed. Remaining is a normal Xcode build/run on the Mac to visually confirm the new create/edit forms, expandable weekly categories, progression chart, exercise-detail map, swimming views, and the redrawn body map (the Linux dev host has no Swift toolchain, so iOS was verified structurally).

Do not:
- physically delete exercises, sets, or workouts (archive only; keep history/FK)
- redesign the Workouts screen — add new blocks only, in separate SwiftUI files
- create three separate load algorithms — weekly summary, body map and exercise detail must share one layer
- invent muscle load / swimming styles / precision where the data can't support it (use documented fallbacks)
- show raw contribution coefficients (0.35, ...) in the UI — only «Основная»/«Дополнительная»


---

## Логика расчёта нагрузки на мышцы (muscle-load formula)

Это описание для будущего разработчика и AI-агента. Весь расчёт живёт в **одном** месте —
`coach/aghealth-backend/src/fitness/muscle-load.js` (`buildMuscleLoad()`), а недельная сводка, карта
тела и деталка упражнения только читают его. Три отдельных алгоритма делать нельзя.

**1. Как определяется мышца.** Источник истины — таблица `fitness_exercise_muscles`
(`exercise_id → group_key → muscle → role → contribution`). У каждого упражнения ровно одна
`primary`-мышца и сколько угодно `secondary`. Денормализованные колонки на `fitness_exercises`
(`muscle_group_key`, `muscle`) — это копия primary для пикера и легаси; если у упражнения нет строк
маппинга, расчёт откатывается на эту primary-группу с весом 1.0 (fallback, чтобы старые упражнения
не терялись).

**2. Primary / secondary.** Роль хранится в `role`, а её вес — в `contribution` (0..1). Константы
(`src/fitness/muscle-model.js`): **primary = 1.0**, **secondary = 0.5** по умолчанию, **0.3** для
слабых синергистов. В UI показываем только роль («Основная»/«Дополнительная»), число — внутри модели.

**3. Подходы и 4. вес и 5. повторения (силовые).** Для каждого подхода
`volume = weight_kg × reps`. Для упражнений с весом тела (`weight_kg = 0`) —
`volume = reps × BODYWEIGHT_UNIT_KG` (BODYWEIGHT_UNIT_KG = 5 кг-эквивалента/повтор). Объём
упражнения — сумма по его подходам. Затем объём распределяется по мышцам:
`muscle_load += exercise_volume × contribution`. Чтобы силовые и кардио жили на одной шкале, объём
переводится в «очки нагрузки» (set-equivalents): `points = volume / VOLUME_PER_POINT`
(VOLUME_PER_POINT = 400 кг ≈ 1 очко; рабочий подход 40×10 = 400 кг ≈ 1 очко на primary).

**6. kcal.** Калории **не** прибавляются к килограммам. Если у тренировки есть
`energy_burned_kcal`, силовая нагрузка этой тренировки умножается на коэффициент интенсивности
`1 + min(kcal / 600, 1) × 0.3` — то есть тяжёлая сессия читается максимум как +30 % интенсивности,
лёгкая — почти без изменений. Для **кардио** без пригодной длительности (duration < 60 c), но с
kcal, kcal — это fallback-драйвер: очки = `kcal × 0.02`, размазанные по мышцам типа кардио по их
весам.

**7. Если данных нет.** Нет маппинга мышц → primary-группа из денормализованных колонок. Нет веса →
fallback по весу тела. Нет длительности у кардио, но есть kcal → kcal-fallback. Нет ни того, ни
другого → вклад 0 (ложную точность не выдумываем). Тип `other` и неизвестные типы кардио дают 0.

**8. Агрегация разных упражнений.** Очки суммируются по `group_key` (и отдельно по конкретной
мышце) по всем завершённым тренировкам окна. Одна мышца, задействованная в нескольких упражнениях,
накапливает их вклад.

**9. Недельная нагрузка.** Окно — скользящие последние `days×24` часа (по умолчанию 7). Итог
переводится в уровни (в очках): **≥ 12 — высокая**, **≥ 5 — средняя**, **> 0 — низкая**,
**0 — нет**. Эти же уровни красят карту тела и раскрываемые категории (часть тела → мышцы).

Кардио-маппинг (`src/fitness/cardio-muscle-map.js`, «очки/минута»): running → ноги/ягодицы/кор;
walking, cycling → ноги/ягодицы; swimming → спина/плечи/кор/грудь; tennis → ноги/кор/плечи. Бег и
плавание — отдельный, меньший вклад, не приравнивается к силовому подходу.

**Плавание по стилям** (`src/fitness/swimming-muscle-map.js`): если у заплыва известны стили
(из HealthKit), нагрузка распределяется по стилям — freestyle → спина/плечи/кор/грудь; backstroke →
спина/плечи/кор/ягодицы; breaststroke → грудь/ноги/плечи/кор; butterfly → плечи/спина/грудь/кор.
Если стиль неизвестен/mixed — общий маппинг swimming. Стили никогда не выдумываются: берём только то,
что реально прислал Apple Health.

---

## 1. Project Overview

**AGHealth** is a personal, lifelong health-data platform for a single user (Анна). It is not a medical device and not a diagnostic tool — it's a personal archive + analytics + an AI interpreter on top of the user's own data.

End-to-end data flow:

```text
Apple Watch → Apple Health / HealthKit → AGHealth iOS → AGHealth Backend → AI Agent
```

- **Apple Watch / Apple Health** — the primary source of workout data (and, in the future, other health metrics).
- **AGHealth iOS** — the native SwiftUI app: reads HealthKit, lets the user enrich workouts (strength exercises/sets), and is the user-facing surface going forward.
- **AGHealth Backend** — a small Node.js + PostgreSQL API that is the source of truth for structured data.
- **AI Agent** — analyzes/interprets data on request; it does not store data and does not run deterministic calculations itself (that's Backend's job).

Fitness/workouts is the **first** domain built this way. The long-term product vision (documented in the `openclaw-backup` repository, not yet built here) is much broader: nutrition, sleep, menstrual cycle, medications, doctor visits, lab results, mood/wellbeing, body measurements, cosmetics, dental, pets, documents, notifications — see §6 Roadmap.

---

## 2. Repository Structure

- **`goryaynova/AGHealth`** — **this repository.** The current, separate, standalone iOS app repository. All iOS Swift code and this status file live here. This is the only repository iOS work should be pushed to.
- **`goryaynova/openclaw-backup`** — a **different, older, much larger repository**. It's the general workspace/auto-backup repo for the AI agent this project grew out of. It contains:
  - the original product architecture and planning documents (`coach/ARCHITECTURE_V0.1.md` and friends — see §6/§9 for exact files),
  - the AGHealth backend source code (`coach/aghealth-backend/`, Node.js + PostgreSQL, currently deployed as `aghealth-backend.service`),
  - an unrelated legacy Telegram bot project (`coach/coach-bot.js`, `health/health-bot.js`) that predates and is **separate from** AGHealth iOS.
- **They are not the same repository and must not be treated as one.** `openclaw-backup` (specifically its `coach/` folder) is used **only as a historical/architectural context source** for AGHealth. The current iOS product code is developed exclusively in `AGHealth`. Nothing from `openclaw-backup` should be copied wholesale into `AGHealth`, and this status file should not be duplicated back into `openclaw-backup`.
- **`openclaw-backup/coach`** specifically is a different, unrelated project scope (a personal Telegram AI-coach/health-bot workspace) — do not confuse it with AGHealth iOS work, even though the AGHealth backend code physically lives inside it for now (see Known Issues, §9).

---

## 3. Current Architecture

### Implemented

- **iOS:** SwiftUI app, Xcode project `Fitness API.xcodeproj` / `Fitness API.xcworkspace`. Networking via a plain `APIClient` (URLSession, no third-party dependencies observed). No local persistence layer yet — every screen fetches from the backend over the network each time.
- **HealthKit:** authorization request flow; reading real `HKWorkout` objects for the last 30 days on each manual sync.
- **Backend:** Node.js, **no HTTP framework** (`node:http`, manual routing) — `coach/aghealth-backend/` inside `openclaw-backup`, running as systemd service `aghealth-backend.service`.
- **Database:** PostgreSQL (`aghealth` DB), tables `fitness_exercises`, `fitness_workouts`, `fitness_strength_sets`, `events`. Legacy `coach-bot.db` (SQLite, Telegram bot) still exists separately and is **not** migrated or touched.
- **API:** REST-ish, CRUD-style endpoints under `/api/v1/fitness/*` plus `GET /api/v1/timeline` and `GET /health`. Full contract implemented for exercises/workouts/sets; see `coach/AGHEALTH_VERTICAL_SLICE_1_STRENGTH.md` in `openclaw-backup` for the detailed spec.
- **Authentication:** a single static Bearer token (`AGHEALTH_API_TOKEN`) shared by the whole app, checked on every `/api/v1/*` call. This is explicitly a **development-level** auth model (see Known Issues, §9), not a real per-user auth system.
- **AI Agent:** not integrated into the product at all yet. Right now "AI" only exists as this OpenClaw agent doing the diagnosis/build/documentation work described in this file, not as an in-app feature.

### Planned (documented, not built)

- Full HealthKit metrics beyond the current basics: HR time series, HRV, resting HR, sleep, VO2max, GPS route, cadence, power, swim laps (Phase 2 fields already reserved conceptually in `ARCHITECTURE_V0.1.md` §8, no DB columns exist for them yet except `distance_m`/`energy_burned_kcal`, which are implemented).
- Local iOS persistence / offline read (SwiftData vs Core Data — Open Decision #7, unresolved).
- Automatic/background HealthKit sync (observer queries) — today sync is a manual button tap only.
- A unified Notification Engine (local + APNs hybrid — architecture approved, not implemented; needs Apple Developer Program).
- A formal AI query/retrieval layer (architecture approved in `AGHEALTH_NOTIFICATIONS_AND_AI_PROPOSAL.md`, not implemented for any domain yet).
- PostgreSQL migration of the other, still-JSON-based `health-bot` domains (cycle, medications, labs, mood, cosmetics) — explicitly deferred, not started.
- Multi-domain backend refactor (framework choice, layering) — deferred until domain count grows (Open Decision #8).

**Do not treat anything in "Planned" as existing.** Where the old architecture docs in `openclaw-backup` describe a fuller system than what's actually running, the actual current code wins — see §9 for the specific gaps found.

---

## 4. Completed Work / History

In order, "what was done → result":

1. **Legacy Telegram AI-coach project (`coach-bot`, pre-pivot).** Built a Telegram-bot-based fitness/nutrition tracker (`@privatannabot`) with a SQLite backend (`coach-bot.db`: `workouts`, `exercise_catalog` with 33 real exercises, `strength_sets`, `nutrition_entries`, etc.) and a working `/sync` HTTP contract for HealthKit data (`FITNESS_API_CONTRACT.md`). → A fully working, still-running Telegram interface (Phase 1), later reused as historical/technical context, not as the product going forward.
2. **Product pivot to AGHealth (09.09.2026).** Full repo/backend audit; decided the product should be an iOS-first, backend-source-of-truth platform instead of a Telegram bot. → `ARCHITECTURE_V0.1.md` (26 sections) drafted and approved with 11 open decisions; PostgreSQL approved as the target unified database.
3. **Event/Timeline model proposal (10.09.2026).** → Approved: domain tables remain source of truth, a single `events` index table powers a future Timeline view.
4. **iOS Storage/Offline-Sync + Documents proposal (10.09.2026).** → Approved: local iOS mirror of structured data, two sync flows (HealthKit push, Domain Sync push+pull), PostgreSQL as sole canonical source of truth, client-generated IDs + idempotent upserts required everywhere.
5. **Notifications + AI architecture proposal (11.09.2026).** → Approved: hybrid local/APNs notifications (APNs not blocking MVP), hybrid AI layer (OpenClaw agent for now, retrieval/analytics stays in backend code, not in the LLM).
6. **Requirements → Backlog → MVP process (11.09.2026).** → Fitness domain fully specified: 36 requirements (`REQ-001`–`REQ-036`), 29 backlog items (`AGH-1`–`AGH-29`), an 18-item MVP scope, and a chosen first vertical slice: **end-to-end manual strength workout**.
7. **Backend Vertical Slice #1 implemented (11–13.09.2026).** New `aghealth-backend` (Node.js + PostgreSQL) built from scratch, separate from legacy `coach-bot.db`: `fitness_exercises`/`fitness_workouts`/`fitness_strength_sets`/`events` tables, full REST API, the 33 legacy exercises seeded, 42 automated backend tests. → A working, tested backend for strength workouts, independent of the Telegram bot's SQLite.
8. **Separate iOS GitHub repository created (`goryaynova/AGHealth`).** → A dedicated repo for the iOS app, decoupling it from the general `openclaw-backup` workspace.
9. **iOS: HealthKit authorization + real workout reading.** → App can request HealthKit permission and read actual `HKWorkout` records instead of hardcoded/demo data.
10. **iOS: manual sync (`SettingsView`).** → A button that pulls the last 30 days of HealthKit workouts and pushes each to the backend, using the HealthKit workout UUID as the backend workout ID (idempotent — safe to re-run).
11. **iOS: real Workout List + filters + Workout Detail.** → Replaced earlier hardcoded UUIDs with live API data; list supports filtering by workout type; detail screen shows real metrics and strength sets from the backend.
12. **iOS: add sets to an existing workout (`StrengthWorkoutView`) + Detail refresh.** → A user can add exercises/sets onto an already-synced workout and immediately see the updated detail.
13. **iOS + backend: exercise deletion/archive (13.09.2026, commit `51a94ee`).** → Trash button + confirmation dialog in the exercise picker, calling the existing backend `DELETE /api/v1/fitness/exercises/{id}` (soft-delete/archive); archived exercises disappear from the picker but historical sets keep working.
14. **Data cleanup: two erroneous test `running` workouts removed (13.09.2026, same commit).** → Diagnosed as leftover manual/curl test data from backend debugging (not a real sync bug, not real user workouts); removed from PostgreSQL (soft-deleted + hidden Timeline events + one orphan test set hard-deleted). 27 real workouts untouched, 42/42 backend tests still pass.
15. **Documentation: `AGHealth_PROJECT_STATUS.md` created (13.09.2026), then rewritten into this full operational status doc (13.09.2026, this update).** → A single, accurate, up-to-date reference file that doesn't require reading all of `openclaw-backup` to understand the project.

---

## 5. Current Implemented Features

Legend: **implemented** = works today · **partial** = exists but incomplete/limited · not listed = not implemented (see §6/§7 for planned work).

| Area | Status | Notes |
|---|---|---|
| iOS UI | **implemented** | SwiftUI, custom dark theme components, Home/Workouts/Settings sections |
| HealthKit permissions | **implemented** | Explicit authorization request flow |
| HealthKit workout reading | **partial** | Reads real `HKWorkout`s, but only the **last 30 days** on each sync — not the full lifelong history the requirements call for (see §9) |
| Workout sync (push to backend) | **partial** | Manual button only, no automatic/background sync (no observer queries); idempotent by HealthKit UUID; per-workout error handling so one failure doesn't abort the batch |
| Workout list + filters | **implemented** | Real API data, filter by workout type |
| Workout detail | **implemented** | Real metrics + strength sets from the backend, "no data" shown for missing optional metrics |
| Strength workouts — add sets to existing workout | **implemented** | Only works on an already-existing (HealthKit-synced) workout |
| Strength workouts — create a brand-new manual workout from scratch | **not implemented** | No UI path to create a workout that isn't already synced from HealthKit; backend supports `source: manual` creation, iOS doesn't expose it (see §7 P1) |
| Exercises — catalog (v2, 171 active) | **implemented** | The active catalog is the new 171-exercise v2 set with structured muscle classification (`muscle_group_key/muscle/equipment/body_region`). The 35 old legacy exercises are archived (history intact), excluded from the active picker |
| Weekly worked-muscles summary | **implemented** | `GET /api/v1/fitness/muscle-summary?days=7` aggregates real completed workouts (strength sets by muscle group + fixed cardio mapping) into per-group high/medium/low intensity; iOS `WeeklyMuscleSummaryView.swift` renders the list block on the Workouts screen |
| Body muscle map (front/back) | **implemented** | iOS `MuscleMapView.swift` — front+back body silhouettes drawn with SwiftUI Shapes (no third-party framework/asset), muscle groups highlighted by weekly intensity incl. running/cardio; neutral for untrained + empty state |
| Exercises — standalone directory («Упражнения») | **implemented** | Dedicated `ExercisesView.swift` (Ещё → Упражнения): list + search + view of the global catalog |
| Exercises — create/edit | **implemented** | In the «Упражнения» screen via `ExerciseEditorView` → `APIClient.createExercise` / `patchExercise` → backend `POST`/`PATCH /api/v1/fitness/exercises`. Muscle group is required (backend enforces non-empty) |
| Exercises — global archive/delete | **implemented** | Trash action in the «Упражнения» screen only → `APIClient.deleteExercise` → `DELETE /api/v1/fitness/exercises/{id}` (soft-delete/archive). Historical sets keep working |
| Exercises — picker (in strength-add flow) | **implemented** | Selection-only. No delete/edit/archive affordance — the erroneous trash button removed. Picking an exercise adds it to the draft |
| Strength workouts — remove one exercise from one workout | **implemented** | Swipe-left on an exercise group in Workout Detail → `DELETE /api/v1/fitness/workouts/{id}/exercises/{exerciseId}`. Removes only that exercise's sets from that workout; global exercise and other workouts untouched; re-addable via the picker |
| Backend / API | **implemented** | Node.js, no framework, REST endpoints for exercises/workouts/sets/timeline/muscle-summary, Bearer auth, 58 automated tests passing |
| Database | **implemented** | PostgreSQL `aghealth` DB; legacy `coach-bot.db` (SQLite) still running independently, not migrated |
| Authentication | **partial** | Single shared static Bearer token — functional but development-grade only, no per-user auth |
| Timeline | **partial** | Backend creates `events` rows and exposes `GET /api/v1/timeline`; **no iOS UI consumes it yet** |
| Settings | **partial** | Manual sync trigger + one-line result message; no persisted sync history |
| Logging / error handling | **partial** | Structured `APIError` with localized messages; per-workout error isolation during sync; console `print()` logging only, nothing persisted client-side |

---

## 6. Roadmap

Carried over from `openclaw-backup` (`ARCHITECTURE_V0.1.md`, `BACKLOG.md`, `MVP_SCOPE.md`) and reconciled with what's actually built. This is **documentation only** — nothing below should be started without a separate, explicit task.

- **HealthKit / Apple Health:** full historical (not 30-day-windowed) import; automatic/background sync via observer queries; Phase 2 metrics (HR time series, HRV, resting HR, VO2max, GPS route, cadence, power).
- **Workout data:** sync status/history UI (`AGH-7`); tracking of *changed* HealthKit workouts, not just new ones (`AGH-5` refinement); dedup hardening (`AGH-6`, mostly done via idempotent UUID).
- **Strength training:** exercise create/edit in iOS (`AGH-10` remainder); standalone "My Workouts"/"My Exercises" screens (`AGH-8`/`AGH-9` full versions); manual "from scratch" workout creation (`AGH-20` full version); per-exercise progression (`AGH-13`); muscle-group balance analysis (`AGH-14`).
- **Running / Swimming / Cycling / Walking / Tennis:** specialized metrics + progression screens (`AGH-15`–`AGH-19`) — deferred by the approved MVP scope; generic list/detail already shows these workouts with basic HealthKit fields.
- **Health metrics (beyond fitness):** sleep, HRV, resting HR, VO2max, GPS/route, body measurements — not started as domains at all in AGHealth.
- **Synchronization:** Domain Sync (bidirectional, tombstones, LWW + recoverable buffer for conflicts) — architecture approved, not implemented; iOS offline-first local mirror — not implemented (no local persistence at all yet).
- **Backend:** multi-domain refactor when domain count grows (possible move to a lightweight framework, Open Decision #8); unify auth tokens across domains instead of per-domain static tokens.
- **Database:** migrate other `health-bot` JSON domains (cycle, medications, labs, mood, cosmetology) into PostgreSQL — explicitly deferred until each domain gets its own Requirements pass; at-rest encryption — not decided.
- **AI Agent / analytics:** Fitness Analytics engine (weekly/monthly summary `AGH-22`, training volume `AGH-23`); AI Q&A on fitness data (`AGH-25`–`AGH-28`) — depends on the approved-but-unbuilt AI retrieval/query layer.
- **Timeline:** iOS Timeline UI consuming the already-working backend `events`/`GET /api/v1/timeline` (`AGH-29` iOS side); cross-domain timeline once other domains exist.
- **Notifications/automation:** unified Notification Engine, local + APNs hybrid — architecture approved, needs Apple Developer Program ($99/year) before APNs can ship.
- **UI:** subjective workout fields — perceived difficulty / pain level / free-text comment (`AGH-21`); broader navigation/screen map (Home / Training / Nutrition / Measurements / Health / Cosmetics / Pets / Settings) is still an unfinalized draft in `ARCHITECTURE_V0.1.md` §22.
- **Infrastructure:** Apple Developer Program enrollment (needed for real-device distribution, TestFlight, APNs); iOS local persistence technology choice (SwiftData vs Core Data, Open Decision #7 — still unresolved); production-grade backups/retention for PostgreSQL (currently only the general git auto-backup covers it).
- **Other domains (documented in `openclaw-backup`, not started for AGHealth at all):** Nutrition, Menstrual cycle, Medications, Doctor visits, Lab/research results, Wellbeing/mood diary, Body measurements, Cosmetics, Dental, Favorite doctors, Pets, Documents-as-first-class-entity. These currently only exist as legacy JSON data inside the unrelated `health-bot` Telegram service.

---

## 7. Backlog / Next Tasks

**P0 — blocks further development:** none currently. The app and backend both work end-to-end for the manual-strength-workout slice; nothing is broken or blocking.

**P1 — next important functional step:**
- **Finish manual workout creation from scratch** (`AGH-20` full version) — today `StrengthWorkoutView` can only add sets to an *existing* HealthKit-synced workout; there's no UI to create a new workout (type/date/duration) that isn't tied to HealthKit. Backend already supports `source: "manual"` creation. Status: **partial**.
- **Add exercise create/edit to iOS** (`AGH-10` remainder) — backend `POST`/`PATCH /api/v1/fitness/exercises` already exist and are tested; iOS only has delete. Status: **partial**.
- **Fix the 30-day sync window** (`AGH-4`) — requirements call for a full lifelong historical import on first sync, current code hardcodes the last 30 days. Status: **partial**.
- **Standalone "My Exercises" / "My Workouts" screens** (`AGH-9`/`AGH-8`) — currently implicit (a picker + a filtered general list), not the dedicated views the requirements describe. Status: **partial**.

**P2 — subsequent features:**
- Strength progression per exercise (`AGH-13`). Dependency: `AGH-11` (done). Status: **planned**.
- Muscle-group balance analysis (`AGH-14`). Dependency: `AGH-12` (done). Status: **planned**.
- Weekly/monthly summary (`AGH-22`) and training volume (`AGH-23`) analytics. Status: **planned**.
- iOS Timeline UI (`AGH-29` iOS side) — backend already emits `events`/`GET /api/v1/timeline`. Status: **planned**.
- Sync status/history screen (`AGH-7`). Status: **planned**.
- Specialized Running/Swimming/Cycling/Walking/Tennis screens (`AGH-15`–`AGH-19`). Status: **planned**.
- Subjective workout fields — pain/difficulty/comment (`AGH-21`). Status: **planned**.

**P3 — long-term/optional:**
- AI Q&A on fitness data (`AGH-25`–`AGH-28`). Status: **blocked** — needs the AI retrieval/query layer from `AGHEALTH_NOTIFICATIONS_AND_AI_PROPOSAL.md` to be built first.
- Notification Engine (local + APNs hybrid). Status: **blocked** — needs Apple Developer Program enrollment.
- iOS local persistence / true offline support. Status: **blocked** — needs Open Decision #7 (SwiftData vs Core Data) resolved.
- PostgreSQL migration of other `health-bot` domains (cycle, medications, labs, mood, cosmetics). Status: **blocked** — each domain needs its own Requirements pass first (only Fitness has one so far).
- Any brand-new health domain (Sleep, Nutrition-in-AGHealth, Body Measurements, Documents, Pets, Dental, etc.). Status: **planned**, far future — no Requirements exist for these in AGHealth yet.
- Production security hardening: per-user auth model, at-rest encryption, real DB backup/retention policy. Status: **planned**.

---

## 8. Current Focus

The originally-scoped **Vertical Slice #1 (manual strength workout, end-to-end)** is backend-complete but has two iOS gaps that make it not fully deliverable as designed: no "create workout from scratch" and no exercise create/edit on iOS. The recommended next functional block is:

**Recommended: close the Vertical Slice #1 gaps first** — implement manual "create new workout" (P1) and exercise create/edit on iOS (P1). Both reuse existing, already-tested backend endpoints, so this is the smallest remaining gap and finishes what was already promised for this slice.

If a different order is preferred, the equally-valid next candidates, in a reasonable sequence, are:
1. Fix the 30-day HealthKit sync window → full historical import (`AGH-4`).
2. Build the iOS Timeline screen (`AGH-29`) — the backend side is already done and unused.
3. Fitness Analytics (`AGH-22`/`AGH-23`/`AGH-13`/`AGH-14`) — most valuable once more workout history has accumulated.

---

## 9. Known Issues / Technical Debt

- **30-day sync window contradicts the approved requirement** (`AGH-4`/REQ-007: full lifelong import) — `SettingsView.startManualSync()` hardcodes the last 30 days.
- **No automatic/background HealthKit sync** — the user must open Settings and tap manually every time (`AGH-5` partial).
- **No offline/local persistence on iOS at all** — every screen re-fetches over the network; this contradicts the long-term architecture principle that iOS should support offline read from a local cache (`AGHEALTH_IOS_SYNC_AND_DOCUMENTS_PROPOSAL.md`).
- **Single shared static Bearer token** (`AGHEALTH_API_TOKEN`) for all API calls — explicitly a development-only auth model (`ARCHITECTURE_V0.1.md` §17), not production-grade.
- **No at-rest encryption** on PostgreSQL or on any future document storage.
- **Backend has no HTTP framework** — bare `node:http` with manual routing; fine for one domain, flagged in `ARCHITECTURE_V0.1.md` Open Decision #8 as needing revisit once more domains are added.
- **iOS local storage technology unresolved** (SwiftData vs Core Data, Open Decision #7) — currently moot since there's no local storage yet, but blocks any offline-support work.
- **Legacy `coach-bot` (SQLite, Telegram `@privatannabot`) is still active and independently writable** — a second, unsynced source of truth for the same Strength domain during the transition period. This is an explicitly accepted temporary state (`ARCHITECTURE_V0.1.md` §23/24), but real divergence risk exists if both are used for real data entry at the same time.
- **Backup strategy is just the general workspace git auto-backup** (`openclaw-backup`) — not a real database backup/retention policy (`ARCHITECTURE_V0.1.md` §19 flags this as a pre-production gap).
- **Console `print()`-based logging only** on iOS — nothing persisted client-side, no crash reporting.
- **Two local clones of the AGHealth iOS repo exist on the dev server** (`/root/.openclaw/workspace/aghealth-work` — canonical, tracks `origin/main` — and a stale `/tmp/AGHealth` with an old unpushed commit). Not cleaned up automatically; flagged here so a future agent doesn't get confused about which is current.
- **AGHealth backend code physically lives inside the unrelated `openclaw-backup/coach/aghealth-backend` folder**, not inside the `AGHealth` iOS repo — this is a pre-existing arrangement, not something introduced by this task, but worth knowing when looking for backend source.
- **Documentation gap (now fixed by this task):** the previous version of this file only covered the most recent block (exercise deletion + data cleanup) and had no history, architecture summary, or roadmap — a future agent would have had to read all of `openclaw-backup` to get context. Resolved by this rewrite.

---

## 10. Agent Workflow / Checkpoint Rules

These are **permanent project rules**, not a description of any one current task. They exist so that after a crash, a finished session, or a session handover, the next coding agent can determine the exact current state and continue the work without re-analyzing the whole project.

### 10.0 Baseline rules (always apply)

1. Before starting any new task, always read `AGHealth_PROJECT_STATUS.md` first.
2. When more architectural/historical context is needed, consult `openclaw-backup` (mainly `coach/ARCHITECTURE_V0.1.md`, `coach/BACKLOG.md`, `coach/MVP_SCOPE.md`, `coach/requirements/fitness.md`, and the other `coach/AGHEALTH_*` proposal docs) as the source.
3. Do not change the existing UI or redesign it without an explicit requirement to do so.
4. When adding a feature, change only what's necessary.
5. Do not implement features that exist only in the roadmap without a separate, explicit task for them.
6. After finishing every functional block, update `AGHealth_PROJECT_STATUS.md`.
7. The status update must reflect: what was done, what changed, what now works, what remains, the next block, and any new known issues.
8. After finishing a functional block, commit and push to `origin/main`.
9. Do not mix AGHealth with `openclaw-backup/coach` — they are different projects.
10. Do not delete or rewrite the historical documentation in `openclaw-backup` for AGHealth's sake.

### 10.1 Checkpoint rules (how to survive crashes and session handovers)

**Rule 1 — The status file is the source of the current state.**
Before starting any substantial task the agent MUST:
- read `AGHealth_PROJECT_STATUS.md`;
- run `git status`;
- check the current branch;
- look at the last commits (`git log --oneline`);
- determine whether there are uncommitted changes;
- check the `Current Task Checkpoint` section, if it exists.
Do not start work "from a clean slate" if a checkpoint already exists in the project.

**Rule 2 — Large tasks are executed in phases.**
Do not shred work into micro-tasks just for agent resilience. Instead, split a large functional block into a few logically complete phases — for example: backend; iOS; a separate UI/integration piece; testing. A phase must be large enough to represent a finished, self-contained functional chunk.

**Rule 3 — After finishing a meaningful phase, create a checkpoint.**
After completing each logically complete phase the agent must:
- review the code;
- run the tests that belong to that phase;
- check `git diff`;
- update `AGHealth_PROJECT_STATUS.md`;
- update the `Current Task Checkpoint`;
- state the next phase / Next Action;
- make a commit.
If the phase is finished and a commit is safe, the checkpoint must reference that commit.

**Rule 4 — Do not commit broken code just to create a checkpoint.**
A checkpoint does not mean any intermediate code must be committed immediately. If the current implementation is unfinished and potentially broken:
- do not make a fake commit;
- record the state in the documentation;
- describe exactly what is IN PROGRESS;
- state a concrete Next Action.
If there is a logically complete part, it can and should be saved as its own commit.

**Rule 5 — The checkpoint must contain the actual state.**
Do not write `Backend — DONE` just because backend was planned. Status must reflect the actual code. For each phase use one of: `DONE`, `IN PROGRESS`, `NOT STARTED`, and where applicable `BLOCKED`.

**Rule 6 — The next session must be able to continue the work.**
The `Current Task Checkpoint` must let a new agent, without access to the previous session, understand: what was being worked on; what is already done; what is not done; which files were changed; which APIs were added/changed; which tests passed; the last safe commit; and what to do next. The Next Action must be concrete — not "continue the work", but e.g. "implement swipe-to-delete in `StrengthWorkoutView.swift` using existing endpoint X, then verify scenarios A–C".

**Rule 7 — Recovery after a crash.**
If a new session starts after the previous one crashed/was interrupted:
- do not start the implementation over;
- read the status/checkpoint;
- check git;
- determine the last safe commit;
- check for uncommitted changes;
- determine the last completed phase;
- continue from the Next Action.
If the actual code state diverges from the checkpoint, update the checkpoint first, then continue the implementation.

**Rule 8 — Push after a safe checkpoint.**
After a meaningful completed phase and its corresponding commit, the agent must push to `origin/main` if the task is meant to be done through the shared repository. This is required so the work can be recovered in a new session.

**Rule 9 — Do not rewrite the checkpoint retroactively without cause.**
Do not rewrite the history of already-completed phases without a reason. If an error is found in a previous phase: explicitly flag it; state exactly what is being fixed; update the current phase; and keep a clear change history via git.

**Rule 10 — Do not expand the task because of the checkpoint.**
A checkpoint is not a reason to implement extra features. The agent must continue only the current task and its explicitly necessary dependencies.

### 10.2 Standard `Current Task Checkpoint` format

The `Current Task Checkpoint` section (kept near the top of this file) is the live checkpoint. Its exact wording may be adapted to fit the document, but the required fields below must be preserved:

```text
## Current Task Checkpoint

Task:
<name of the functional block>

Phase:
<current phase>

Status:
DONE / IN PROGRESS / NOT STARTED / BLOCKED

Completed:
- ...

In progress:
- ...

Not started:
- ...

Files changed:
- ...

API / backend changes:
- ...

Tests:
- ...

Last safe commit:
- <commit hash>

Next Action:
- <concrete next action>

Do not:
- <important constraints of the current task>
```

**`AGHealth_PROJECT_STATUS.md` is the short operational source of truth for AGHealth's current state. Git history and the original documentation are used to recover details, but this status file must stay accurate and current.**

---

## 11. Last Completed Block

**Muscle-influence overhaul (5 checkpoints)** (2026-09-16, pushed to `origin/main` on both repos).

Reworked the whole muscle side of AGHealth on top of the shipped catalog/weekly-map:
1. **Primary/secondary muscle model** — a normalized `fitness_exercise_muscles` table (`exercise → body part → muscle → role/contribution`), single source of truth; catalog secondaries for compound lifts; structured create/edit forms (body-part → muscle pickers, add N secondaries; roles shown, coefficients hidden). Seed made history-safe (never re-archives an in-use exercise).
2. **Single muscle-load layer** (`src/fitness/muscle-load.js`) — strength volume = Σ(weight×reps) split by contribution (primary 1.0 / secondary 0.5·0.3), bodyweight fallback, kcal as an intensity factor (≤ +30%) / cardio fallback; per-group AND per-muscle load bands. Weekly summary rewritten to consume it; weekly categories are now tap-to-expand (body part → specific muscles, high/medium/low/none). Full formula documented in "Логика расчёта нагрузки на мышцы".
3. **Weight progression** — `GET /fitness/progression` + `GET /fitness/exercises/:id/progression` (top working weight per workout, never mixed); iOS line chart + weight/reps/volume table; exercise-detail muscle map reusing the same mapping.
4. **Swimming stroke styles** — `fitness_workout_swimming_segments`; HK sync reads styles from `.segment` events + per-segment `distanceSwimming` (only real styles); workout detail per-style breakdown; `GET /fitness/swimming/progress`; per-style muscle mapping feeds the body map.
5. **Redrawn body map** — cleaner anatomical front/back silhouette, separated regions, level-1 (body part) + level-2 (specific muscle) highlighting; strength + running + swimming aggregate on ONE map via the shared load layer.

**Numbers:** 91/91 backend tests (was 58; +33). New tables: `fitness_exercise_muscles`, `fitness_workout_swimming_segments`. New backend modules: `fitness/muscle-model.js`, `fitness/muscle-load.js`, `fitness/swimming-muscle-map.js`, `fitness/progression.js`, repos `exerciseMuscles.js`/`swimming.js`, routes `progression.js`/`swimming.js`. New iOS files: `MuscleCatalog.swift`, `ExerciseMuscleView.swift`, `ExerciseDetailView.swift`, `ExerciseProgressionView.swift`, `SwimmingViews.swift` (+ redrawn `MuscleMapView.swift`). Live dev: 177 active exercises, volume-based weekly load, swimming end-to-end verified.

### Superseded block (for history)

**Exercise catalog rebuild + weekly muscle map** (2026-09-15, pushed to `origin/main` on both repos).

Replaced the whole active exercise set with a new 171-exercise catalog, added a structured muscle model, and built a «Проработанные мышцы за неделю» block with a front/back body muscle map — fed by real completed workouts (strength sets + a fixed cardio mapping for running/etc.).

**Numbers:**
- **171 new active exercises** added (the requested list; a handful of names disambiguated where the same title appeared under two groups). No duplicates by name or UUID.
- **35 old exercises archived, 0 deleted.** All previously-active legacy exercises were archived (`archived_at`), so they leave the active picker but their rows and every historical set/workout stay intact (4 are still referenced by historical sets — FK preserved). This is the «занулить старые» semantics: inactive as new exercises, undestroyed as history.
- Live DB: 171 active / 35 archived; sets=16, workouts=33 unchanged; a historical workout with archived exercises still opens (200, sets intact).

**Model changes (`fitness_exercises`, idempotent additive migration):** added `muscle_group_key` (canonical group), `muscle` (specific muscle), `equipment`, `body_region` (front/back/both) + an index; all nullable so legacy/archived rows stay valid. No separate table (kept minimal).

**Backend (`openclaw-backup` → `coach/aghealth-backend/`):**
- `src/seed/exercise-catalog-v2.js` + `src/seed/seed-catalog-v2.js` (`applyCatalogV2()`, idempotent archive-old + upsert-v2), `package.json` `seed:catalog-v2`.
- `src/fitness/cardio-muscle-map.js` (fixed cardio→muscle mapping), `src/fitness/muscle-summary.js` (`buildWeeklyMuscleSummary()`), `src/routes/muscleSummary.js` + `server.js` route.
- New endpoint `GET /api/v1/fitness/muscle-summary?days=7` (days clamped 1..30) — per-group set-equivalents + high/medium/low/none level, rolling last 7×24h window.
- `src/repositories/exercises.js` — `mapRow` returns the structured fields.
- Tests: **58/58** (was 45; +5 catalog-v2, +8 muscle-summary incl. checks 9–14). Service restarted; endpoints live-verified.

**iOS (`aghealth-work`):**
- `APIClient.swift`: `MuscleSummary`/`MuscleGroupLoad` + `fetchMuscleSummary(days:)`; `Exercise` gains optional structured fields.
- NEW `UI/MuscleMapView.swift`: front+back body silhouettes via SwiftUI Shapes (no third-party framework / external asset), intensity-highlighted, extensible shape library + legend.
- NEW `UI/WeeklyMuscleSummaryView.swift`: self-contained weekly block (map + per-group list + totals + loading/empty/error states).
- `UI/WorkoutsSectionView.swift`: block added above the filters (additive, no redesign).

**Muscle-map data source:** strength = 1 set-equivalent/set by `muscle_group_key`; cardio = fixed per-type mapping × duration (running → legs+glutes+core). Running never fabricates a strength exercise/set. Deterministic, computed in backend code.

iOS verified structurally (brace/paren balance + call-site checks); a final Xcode build/run on the Mac is the only remaining visual check.

### Previous block (for history)

**Exercise management — per-workout delete + selection-only picker + «Упражнения» directory CRUD** (2026-09-15, commit `6d7def6` iOS): the exercise picker became selection-only (removed the erroneous in-picker global-archive trash button); added swipe-left per-workout exercise delete in `WorkoutDetailView` via `DELETE /api/v1/fitness/workouts/:id/exercises/:exerciseId`; added the standalone «Упражнения» directory (`ExercisesView.swift`) where global archive/delete lives.

**Commit `51a94ee` — "Add exercise deletion and clean invalid workouts"** (2026-09-13): first added a (now-removed) trash button inside the picker and cleaned two erroneous test `running` workouts.
