# Инструкция по запуску сервера

## Вариант 1: С PM2 (рекомендуется для продакшена)

### Установка PM2
```bash
sudo npm install -g pm2
```

### Запуск через PM2
```bash
cd /root/familyChat
pm2 start ecosystem.config.js
pm2 save
pm2 startup  # для автозапуска при перезагрузке
```

### Управление
```bash
pm2 status              # статус процессов
pm2 logs                # логи
pm2 logs familychat-server  # логи конкретного процесса
pm2 restart familychat-server  # перезапуск
pm2 stop familychat-server     # остановка
pm2 delete familychat-server   # удаление из PM2
```

---

## Вариант 2: Без PM2 (для тестирования)

### Запуск в фоне через nohup
```bash
cd /root/familyChat
nohup npm run start > server.log 2>&1 &
```

### Запуск в screen (если установлен)
```bash
cd /root/familyChat
screen -S familychat
npm run start
# Нажмите Ctrl+A, затем D для отсоединения
# Для возврата: screen -r familychat
```

### Проверка, что сервер запущен
```bash
ps aux | grep node
netstat -tulpn | grep :5000
curl http://localhost:5000
```

### Остановка
```bash
# Найти процесс
ps aux | grep node

# Остановить (замените PID на номер процесса)
kill PID
# или
killall node
```

---

## Важно!

1. **Файл .env** должен быть в корне проекта (`/root/familyChat/.env`):
```
NODE_ENV=production
PORT=5000
CLIENT_URL=https://aparfenov1.fvds.ru
```

2. **Соберите клиент перед запуском**:
```bash
cd /root/familyChat
npm run build
```

3. **Проверьте порт 5000 в файрволе**:
```bash
sudo ufw allow 5000/tcp
```

4. **Доступ к приложению**:
   - Через Nginx: `https://aparfenov1.fvds.ru/` (без порта)
   - Напрямую: `http://aparfenov1.fvds.ru:5000/` (HTTP, не HTTPS)

