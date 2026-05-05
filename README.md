# docker-hub

Сборочная среда и стенд для `dicoop/blockchain` (CoopOS / coopos nodeos).

Содержит две независимые части:
1. **Сборка** мульти-стадийного образа `dicoop/blockchain:vX.Y.Z` из исходников `~/coopos` и `~/cdt` — `Dockerfile` + `install.sh`.
2. **Стенд** для локального запуска ноды и проверки совместимости версий — `docker-compose.yaml`, `config/`, `scripts/`, `Dockerfile.deb-runner`.

## Структура

```
.
├── Dockerfile               # multi-stage build dicoop/blockchain (из ~/coopos)
├── install.sh               # сборка + push dicoop/blockchain в Docker Hub
├── Dockerfile.deb-runner    # ubuntu:22.04 + установленный coopos*.deb
├── docker-compose.yaml      # параметризованный запуск ноды
├── .env.example             # переменные для compose (image, tag, порты)
├── config/config.ini        # лёгкая нода: seed p2p.coopenomics.world:9876
├── scripts/
│   ├── fetch-snapshot.sh    # скачивает snapshot.coopenomics.world
│   ├── fetch-debs.sh        # скачивает .deb с GitHub Releases coopenomics/coopos
│   ├── build-deb-image.sh   # собирает coopos-deb:5.1.0 / 5.2.0 из .deb
│   ├── start.sh             # старт ноды через compose
│   ├── stop.sh              # стоп
│   ├── status.sh            # head/version/chain_id через :8888 API
│   ├── test-compat.sh       # snapshot-compat двух тегов dicoop/blockchain
│   ├── test-deb-compat.sh   # миграционный тест .deb на одном data dir
│   └── fork-snapshot.sh     # форк прод-снапшота: to-json → jq-patch → from-json
├── patches/
│   └── dev-fork.jq          # шаблон JQ-патча: подмена ключей eosio + producer schedule
├── snapshot.bin             # gitignored
├── data/                    # gitignored, файлы создаются root в контейнере
└── debs/                    # gitignored
```

## Сценарии

### 1. Поднять лёгкую ноду со снапшота продакшна

```bash
./scripts/start.sh --tag latest --from-snapshot --clean --follow
```

`--clean` нужен потому что `--snapshot` применяется только при пустом `data/`. Чистит через одноразовый контейнер (файлы в `data/` принадлежат root). `--follow` сразу хвостит логи.

После старта:
```bash
./scripts/status.sh   # head_block_num, head_block_time, chain_id, server_version
./scripts/stop.sh     # остановить (data/ сохраняется)
```

API: `http://127.0.0.1:8888` (HTTP), `9876` (P2P), `8088` → `8080` внутри (state-history). Порты переопределяются через `NODE_HTTP_PORT` / `NODE_P2P_PORT` / `NODE_HISTORY_PORT` в `.env`.

### 2. Главный тест перед прод-апгрейдом — миграция .deb

Симулирует продакшн-апгрейд: `stop nodeos → dpkg -i новый.deb → start nodeos` на том же `data/`. Если проходит — значит на проде апгрейд бесшовный, replay не нужен.

```bash
./scripts/fetch-debs.sh         # требует gh CLI с auth, скачает оба .deb
./scripts/build-deb-image.sh    # соберёт coopos-deb:5.1.0 и coopos-deb:5.2.0
./scripts/test-deb-compat.sh    # OLD_TAG → NEW_TAG на одном data dir
```

Параметры через env:
- `OLD_TAG=5.1.0 NEW_TAG=5.2.0` — какие версии сравнивать (должны быть собраны через `build-deb-image.sh`).
- `MIN_BLOCKS=50` — сколько блоков должно прирасти, чтобы признать прогресс.
- `WAIT_SECONDS=180` — таймаут на каждый этап.

Зелёный результат значит: можно делать `dpkg -i` на проде без двух нод и без replay.

### 3. Локальный fork прод-снапшота (для writable-тестов)

Прод-снапшот содержит реальные ключи и producer schedule, поэтому локальная нода с ним продьюсить не может — нет приватников. Решение: подменить authority системного аккаунта и schedule на dev-ключ.

Требует `leap-util snapshot from-json` (есть начиная с тега `v5.2.0+`). После пересборки .deb:

```bash
./scripts/fetch-snapshot.sh                                   # snapshot.bin с прода
./scripts/fork-snapshot.sh --patch patches/dev-fork.jq --keep-json
# на выходе snapshot-fork.bin + промежуточные .json для отладки

./scripts/start.sh --tag 5.2.0 --image coopos-deb --from-snapshot --clean \
  --extra "--snapshot /root/blockchain/snapshot-fork.bin \
           --producer-name eosio \
           --signature-provider EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV=KEY:5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3 \
           --enable-stale-production"
```

`patches/dev-fork.jq` — шаблон JQ-патча: меняет authority `eosio@active|owner` и producer schedule на dev-ключ. Перед прогоном с `--keep-json` сохрани и сверь с реальной структурой `snap.json` (имена секций могут отличаться по версиям coopos).

### 4. Snapshot-совместимость двух тегов в Docker Hub

```bash
./scripts/test-compat.sh        # OLD_TAG=v5.1.0-dev NEW_TAG=latest
```

Тест проверяет, что оба образа из реестра умеют поднять ноду из одного и того же продакшн-снапшота. **Не путать с миграцией** — здесь не проверяется hot-swap data dir между бинарниками.

### 5. Сборка и публикация образа dicoop/blockchain

```bash
COOPOS_SRC=~/coopos CDT_SRC=~/cdt ./install.sh   # собирает + push на Docker Hub
```

Теги задаются константами в `install.sh` (`VERSION_TAG`, `LATEST_TAG`).

## start.sh — флаги

```
--image <name>     dicoop/blockchain (default) | coopos-deb | …
--tag <tag>        latest | v5.2.0 | 5.1.0 | …
--from-snapshot    добавить --snapshot к nodeos (требует пустой data/)
--replay           --replay-blockchain (только если в blocks.log есть genesis)
--hard-replay      --hard-replay-blockchain
--clean            предварительно удалить data/ (для применения снапшота)
--extra "<args>"   произвольные доп.аргументы к nodeos
--follow / -f      tail логов после старта
```

## Подвохи, которые ловили

- **`content of memory does not match data expected by executable`** при переключении бинарника — почти всегда означает разный toolchain (gcc/boost) у двух сборок, а не код. Pre-built `dicoop/blockchain:v5.1.0-dev` (2024-04-16) с современным `latest` несовместим именно поэтому. Собирать сравниваемые версии одним и тем же CI/Dockerfile.
- **`Genesis state is necessary…`** при `--replay-blockchain` — в `blocks.log` нет genesis, потому что нода стартовала со снапшота. Replay в этом случае невозможен; либо снапшот, либо blocks.log с genesis.
- **`Permission denied` при `rm -rf data/`** — файлы создаёт root в контейнере. `start.sh --clean` чистит через одноразовый контейнер от того же образа.
- **Порт `8080` занят** — на хосте обычно крутится nocodb или другой сервис. Дефолт state-history наружу = `8088`.
- **`gh release download` для draft-релиза** — работает только если `gh auth` привязан к аккаунту с доступом к draft.

## Память для будущих сессий

`~/.claude/projects/-home-admin/memory/project_coopos_migration.md` — что выяснилось про совместимость chainbase shared_memory, какой апгрейд бесшовный, когда нужен snapshot-перенакат.
