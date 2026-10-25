# Источники анатомии и движения

`makehuman/` содержит только графические данные из официального репозитория
https://github.com/makehumancommunity/makehuman , commit
`a8bc2d54ff0ac92e78ff71431b1023eda42bf482`.

Лицензия активов — CC0 1.0 Universal: оригинальный текст сохранён в
[`assets/licenses/MakeHuman-CC0.txt`](../../../assets/licenses/MakeHuman-CC0.txt).
Она разрешает переработку, включение в коммерческую игру и распространение.
Программный код MakeHuman, лицензируемый отдельно, не используется.

| Здесь | Путь в исходном репозитории под `makehuman/data/` |
|---|---|
| `base.obj` | `3dobjs/base.obj` — анатомическая сетка hm08 и помощники одежды |
| `default.mhskel`, `default_weights.mhw` | `rigs/` — положение суставов и веса |
| `caucasian-male-young.target`, `caucasian-male-old.target` | `targets/macrodetails/` — взрослые пропорции |
| `eye-left-closure.target`, `eye-right-closure.target` | `targets/expression/units/caucasian/` — закрытие век |
| `high-poly.obj`, `high-poly.mhclo` | `eyes/high-poly/` — глаза и их привязка к лицу |
| `walk1.bvh` | `animations/walks/walk1.bvh` — исходный цикл ходьбы |

Текстура глаз находится в `assets/character/textures/brown_eye.png`;
исходник — `eyes/materials/brown_eye.png` в том же репозитории. Владельцы прав
указаны в заголовках файлов: Data Collection AB, Joel Palmius, Jonas Hauquier;
для исходных морфов также Manuel Bastioni и сведения о передаче прав.

Рабочая модель создаётся собственным `build_realistic_worker.py`: человеческий
рост 1.78 м, 49 костей, цельные сменные предметы одежды, швы и детали, UV-окраска
кожи, моргание и отдельные анатомические кисти с цельным морфом большого пальца.
`retarget_walk.py` преобразует BVH в компактные направления костей для игры.
Исходная запись движения — анимационный актив; файл программы `walks.mhanim`
не включён и не используется.

Пересборка из корня репозитория (не нужна для F5):

```sh
python tools/art/generate_textures.py
python tools/art/retarget_walk.py
blender -b --python tools/art/build_realistic_worker.py
```

Готовые GLB, PNG и JSON уже включены в репозиторий. Инструменты не запускаются
из игры. Рендер и скелетные движения — обычные функции Godot, без плагинов.
