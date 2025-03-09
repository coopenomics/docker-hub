# 🚀 CoopOS Docker Builder (Multi-Arch)

Этот репозиторий содержит **мульти-архитектурный контейнер** для сборки **CoopOS Blockchain** и **CDT**.
Контейнер поддерживает запуск на **Linux (AMD64, ARM64), macOS (Intel & M1/M2), Windows (WSL), Raspberry Pi 5**.

---

## 🔹 Инструкция по сборке

**Перед сборкой заменить теги в `install.sh`**.

**Запустить сборку** (образы собираются последовательно):
```
   ./install.sh
```

Проверить, что multi-arch образ создан:
```
docker buildx imagetools inspect dicoop/blockchain_v5.1.1:dev
Запустить контейнер:
```

```
docker run --rm dicoop/blockchain_v5.1.1:dev uname -m
```
Если на Intel/AMD → должно вывести x86_64
Если на Mac M1/M2, Raspberry Pi → должно вывести aarch64


## 📌 Поддерживаемые платформы
Архитектура	Поддерживаемые устройства
linux/amd64	Intel/AMD (Linux, Windows WSL, macOS Intel)
linux/arm64	Apple M1/M2, Raspberry Pi 5, ARM-серверы

