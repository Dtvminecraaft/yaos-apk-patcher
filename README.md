# APK Patcher для Яндекс ТВ

Утилита для автоматической подготовки APK-файлов к загрузке на [dialogs.yandex.ru](https://dialogs.yandex.ru/developer/quick-apps).

Авто-модерация Яндекс ТВ блокирует APK, которые запрашивают «опасные» разрешения (`REQUEST_INSTALL_PACKAGES`, `SYSTEM_ALERT_WINDOW` и другие). Этот патчер удаляет их из `AndroidManifest.xml`, пересобирает APK и подписывает заново.

[![Последний релиз](https://img.shields.io/github/v/release/ВАШ_НИК/yaos-apk-patcher?label=последний%20релиз)](https://github.com/ВАШ_НИК/yaos-apk-patcher/releases/latest)
[![Лицензия](https://img.shields.io/github/license/ВАШ_НИК/yaos-apk-patcher)](LICENSE)

---

## Возможности

- **Удаляет 8 разрешений**, блокирующих модерацию
- **Windows** — готовый `.bat`-скрипт
- **Автоустановка Java 17** — если её нет, скрипт скачает и поставит сам
- **XML-парсер** вместо regex — не ломает манифест (подтверждено на сложных APK)
- **Автоподпись** через [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer)
- **Формирование имени выходного файла** из имени исходного APK

---

## Требования

- **Windows 10 / 11 (x64)**
- **Java 17** (OpenJDK / Eclipse Temurin)

Если Java не установлена — скрипт скачает и поставит её автоматически (нужны права администратора и интернет, ~200 МБ).

---

## Установка

1. Скачайте последний релиз со страницы [Releases](https://github.com/ВАШ_НИК/yaos-apk-patcher/releases/latest).
2. Распакуйте архив в любую папку.
3. Убедитесь, что рядом лежат:
   - `patch_apk.bat`
   - `apktool.jar`
   - `uber-apk-signer.jar`

---

## Использование

1. Перетащите APK-файл на `patch_apk.bat`.
2. Дождитесь окончания (30–90 сек).
3. Рядом появится файл `<имя_исходного>_patched.apk`.
4. Загрузите его на [dialogs.yandex.ru](https://dialogs.yandex.ru/developer/quick-apps).
5. После модерации установите через **YaOS Store → Моё**.

### Из командной строки

```bat
patch_apk.bat "C:\path\to\app.apk"
```

---

## Удаляемые разрешения

| Разрешение | Назначение |
|---|---|
| `android.permission.INSTALL_PACKAGES` | Установка APK (системное) |
| `android.permission.REQUEST_INSTALL_PACKAGES` | Установка APK из приложения |
| `android.permission.REQUEST_DELETE_PACKAGES` | Удаление других приложений |
| `android.permission.UPDATE_PACKAGES_WITHOUT_USER_ACTION` | Тихая установка обновлений |
| `android.permission.ENFORCE_UPDATE_OWNERSHIP` | Принудительная передача владения пакетом |
| `android.permission.BIND_DEVICE_ADMIN` | Права администратора устройства |
| `android.permission.SYSTEM_ALERT_WINDOW` | Окна поверх других приложений |
| `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Обход энергосбережения |

**Итого: 8 разрешений.**

---

## Как это работает

1. **`apktool d`** — распаковка APK во временную папку.
2. **XML-парсер PowerShell** — удаление элементов `<uses-permission>` с запрещёнными именами (не трогая остальной манифест).
3. **`apktool b`** — сборка APK обратно.
4. **`uber-apk-signer`** — подпись debug-ключом.

---

## Известные ограничения

- ⚠️ **APK подписывается заново.** Перед установкой удалите старую версию приложения с устройства — иначе конфликт подписей.
- ⚠️ **Split APK не поддерживаются** (`.apks`, `.xapk`, `.apkm`). Сначала соберите их в обычный APK (например, через Apktool M).
- ⚠️ **Debug-ключ `uber-apk-signer` публичный.** Не используйте пропатченные APK для распространения — любой может сделать «обновление» поверх.
- ⚠️ **Приложение может работать некорректно** после удаления разрешений. Например:
  - магазины приложений (RuStore, Aptoide) не смогут устанавливать APK;
  - самообновление внутри приложения не сработает;
  - всплывающие окна поверх других приложений исчезнут.
- ⚠️ **Проверка подписи внутри приложения** не обходится. Если приложение проверяет свою подпись — после патча оно может отказаться работать.
- ⚠️ **Если модерация всё равно отклоняет APK** — проблема не в разрешениях, а в серверной проверке или в коде приложения.

---

## Проверено на

- **Red Shield VPN** — загружается на dialogs.yandex.ru, устанавливается и работает на **Яндекс Модуле**.

---

## FAQ

**Приложение вылетает после патча.**
Значит, одно из удалённых разрешений было критичным. Верните его обратно, отредактировав список `$forbidden` в скрипте.

**`Не удалось собрать APK / mismatched tag`.**
Обновите `apktool.jar` до последней версии — [bitbucket.org/iBotPeaches/apktool](https://bitbucket.org/iBotPeaches/apktool/downloads/).

**`Не удалось подписать APK`.**
Проверьте, что `uber-apk-signer.jar` лежит рядом со скриптом и называется именно так (без версии в имени файла).

**`PowerShell заблокирован`.**
Откройте PowerShell от имени администратора и выполните:
```powershell
Set-ExecutionPolicy RemoteSigned
```

**Что делать с файлом `.idsig`?**
Это подпись v4 для Google Play. Для установки на ТВ не нужен, можно удалить.

**Работает ли на телефоне?**
Да, но с ограничениями — теряется автообновление, оверлеи, стабильный фон.

---

## Changelog

### v1.0
- Первый релиз
- Удаление 8 разрешений
- Автоустановка Java 17
- XML-парсер вместо regex

---

## Лицензия

[MIT](LICENSE) — используйте, изменяйте, распространяйте. Указывайте автора.

---

## Благодарности

- [iBotPeaches / Apktool](https://ibotpeaches.github.io/Apktool/)
- [patrickfav / uber-apk-signer](https://github.com/patrickfav/uber-apk-signer)
- Сообществу [4PDA](https://4pda.to/forum/index.php?showtopic=1035767) за тестирование и обратную связь
