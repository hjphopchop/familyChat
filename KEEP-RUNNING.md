# Как запустить приложение так, чтобы оно работало всегда

## Проблема
Когда вы закрываете терминал, процесс Node.js завершается вместе с ним.

## Решение: PM2 (рекомендуется)

PM2 - это менеджер процессов для Node.js приложений, который:
- ✅ Запускает приложение в фоне
- ✅ Автоматически перезапускает при сбоях
- ✅ Запускает приложение при перезагрузке сервера
- ✅ Сохраняет логи
- ✅ Позволяет управлять несколькими процессами

### Быстрая установка:

```bash
cd /root/familyChat
chmod +x start-permanent.sh
./start-permanent.sh
```

Выберите вариант 1 (PM2)

### Или вручную:

```bash
# 1. Установите PM2
sudo npm install -g pm2

# 2. Остановите текущий процесс (если запущен)
pkill -f "node.*server.js"

# 3. Запустите через PM2
cd /root/familyChat
pm2 start ecosystem.config.js

# 4. Сохраните конфигурацию
pm2 save

# 5. Настройте автозапуск при загрузке системы
pm2 startup
# Выполните команду, которую покажет PM2 (обычно что-то вроде):
# sudo env PATH=... pm2 startup systemd -u root --hp /root
```

### Управление:

```bash
pm2 status                    # Статус всех процессов
pm2 logs                      # Логи всех процессов
pm2 logs familychat-server    # Логи конкретного процесса
pm2 restart familychat-server # Перезапуск
pm2 stop familychat-server    # Остановка
pm2 delete familychat-server  # Удаление из PM2
pm2 monit                     # Мониторинг в реальном времени
```

## Альтернатива: systemd (как служба Linux)

```bash
cd /root/familyChat
chmod +x start-permanent.sh
./start-permanent.sh
```

Выберите вариант 2 (systemd)

## Простой вариант: nohup (не перезапускается при рестарте сервера)

```bash
cd /root/familyChat
chmod +x start-permanent.sh
./start-permanent.sh
```

Выберите вариант 3 (nohup)

Или вручную:
```bash
cd /root/familyChat
nohup npm run production > server.log 2>&1 &
```

## Проверка работы

```bash
# Проверьте, что сервер отвечает
curl http://localhost:5000

# Проверьте процессы
ps aux | grep node

# Если используете PM2
pm2 status
```

## Важно!

- **Не используйте** `npm run production` напрямую в терминале - он завершится при закрытии терминала
- **Используйте PM2** для продакшена - это стандарт для Node.js приложений
- После установки PM2 приложение будет работать всегда, даже после перезагрузки сервера

