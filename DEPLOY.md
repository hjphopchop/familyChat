# Инструкция по развертыванию FamilyChat на сервере

## Вариант 1: Развертывание на VPS (Ubuntu/Debian)

### Требования
- Сервер с Ubuntu 20.04+ или Debian 11+
- Node.js 18+ и npm
- Nginx (для проксирования)
- PM2 (для управления процессами)
- Доменное имя (опционально, но рекомендуется)

### Шаг 1: Подготовка сервера

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Установка Nginx
sudo apt install -y nginx

# Установка PM2 глобально
sudo npm install -g pm2
```

### Шаг 2: Клонирование и настройка проекта

```bash
# Клонирование репозитория (или загрузка файлов)
cd /var/www
sudo git clone <ваш-репозиторий> familychat
# или загрузите файлы через scp/sftp

cd familychat

# Установка зависимостей
npm run install-all
```

### Шаг 3: Настройка переменных окружения

Создайте файл `.env` в корне проекта:

```bash
# .env
NODE_ENV=production
PORT=5000
CLIENT_URL=https://yourdomain.com
```

### Шаг 4: Сборка клиента

```bash
cd client
npm run build
cd ..
```

### Шаг 5: Настройка сервера Express

Обновите `server/server.js` для работы в production:

```javascript
// Добавьте в начало файла после импортов
const PORT = process.env.PORT || 5000;

// В конце файла, перед app.listen, добавьте:
if (process.env.NODE_ENV === 'production') {
  app.use(express.static(path.join(__dirname, '../client/build')));
  
  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../client/build/index.html'));
  });
}
```

Также обновите CORS настройки:

```javascript
const io = new Server(httpServer, {
  cors: {
    origin: process.env.CLIENT_URL || "http://localhost:5000",
    methods: ["GET", "POST"]
  }
});
```

### Шаг 6: Настройка PM2

Создайте файл `ecosystem.config.js` в корне проекта:

```javascript
module.exports = {
  apps: [{
    name: 'familychat-server',
    script: './server/server.js',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 5000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
```

Запустите сервер:

```bash
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

### Шаг 7: Настройка Nginx

Создайте конфигурационный файл:

```bash
sudo nano /etc/nginx/sites-available/familychat
```

Добавьте конфигурацию:

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    # Редирект на HTTPS (после настройки SSL)
    # return 301 https://$server_name$request_uri;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket поддержка
    location /socket.io/ {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Активируйте конфигурацию:

```bash
sudo ln -s /etc/nginx/sites-available/familychat /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Шаг 8: Настройка SSL (Let's Encrypt)

```bash
# Установка Certbot
sudo apt install -y certbot python3-certbot-nginx

# Получение сертификата
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Автоматическое обновление
sudo certbot renew --dry-run
```

### Шаг 9: Настройка файрвола

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## Вариант 2: Развертывание на Heroku

### Шаг 1: Установка Heroku CLI

```bash
# Linux
curl https://cli-assets.heroku.com/install.sh | sh

# Или следуйте инструкциям на https://devcenter.heroku.com/articles/heroku-cli
```

### Шаг 2: Подготовка проекта

Создайте `Procfile` в корне проекта:

```
web: cd server && node server.js
```

Создайте `server/package.json` с правильными скриптами:

```json
{
  "scripts": {
    "start": "node server.js"
  }
}
```

### Шаг 3: Деплой

```bash
heroku login
heroku create your-app-name
git push heroku main
heroku open
```

## Вариант 3: Развертывание на Railway/Render

### Railway

1. Подключите GitHub репозиторий
2. Установите переменные окружения:
   - `NODE_ENV=production`
   - `PORT` (автоматически)
3. Укажите root directory: `server`
4. Deploy

### Render

1. Создайте новый Web Service
2. Подключите репозиторий
3. Настройки:
   - Build Command: `cd client && npm install && npm run build`
   - Start Command: `cd server && npm install && node server.js`
4. Добавьте переменные окружения
5. Deploy

## Обновление приложения

```bash
# На VPS
cd /var/www/familychat
git pull
cd client && npm run build && cd ..
pm2 restart familychat-server

# На Heroku
git push heroku main
```

## Мониторинг

```bash
# PM2
pm2 status
pm2 logs familychat-server
pm2 monit

# Nginx
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

## Устранение неполадок

1. **Проверьте логи PM2**: `pm2 logs`
2. **Проверьте логи Nginx**: `sudo tail -f /var/log/nginx/error.log`
3. **Проверьте порты**: `sudo netstat -tulpn | grep :5000`
4. **Проверьте переменные окружения**: `pm2 env 0`

## Безопасность

- Используйте HTTPS
- Настройте файрвол
- Регулярно обновляйте зависимости
- Используйте сильные пароли
- Настройте автоматические бэкапы

