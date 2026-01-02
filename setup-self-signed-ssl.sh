#!/bin/bash

echo "=== Установка самоподписанного SSL сертификата ==="
echo ""
echo "ВНИМАНИЕ: Самоподписанный сертификат:"
echo "  - Браузер покажет предупреждение о безопасности"
echo "  - Камера/микрофон могут не работать (зависит от браузера)"
echo "  - Подходит только для тестирования"
echo ""

read -p "Продолжить? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Отменено"
    exit 0
fi

DOMAIN="aparfenov1.fvds.ru"
SERVER_IP=$(curl -s ifconfig.me || echo "your-server-ip")

echo ""
echo "1. Создание директории для сертификатов..."
sudo mkdir -p /etc/nginx/ssl

echo ""
echo "2. Генерация самоподписанного сертификата..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/${DOMAIN}.key \
    -out /etc/nginx/ssl/${DOMAIN}.crt \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=FamilyChat/CN=${DOMAIN}" \
    -addext "subjectAltName=IP:${SERVER_IP},DNS:${DOMAIN}"

if [ $? -eq 0 ]; then
    echo "✓ Сертификат создан"
else
    echo "✗ Ошибка при создании сертификата"
    exit 1
fi

echo ""
echo "3. Обновление конфигурации Nginx..."

sudo tee /etc/nginx/sites-available/familychat > /dev/null <<EOF
# Редирект HTTP на HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} ${SERVER_IP};
    return 301 https://\$server_name\$request_uri;
}

# HTTPS сервер
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN} ${SERVER_IP};

    # SSL сертификаты
    ssl_certificate /etc/nginx/ssl/${DOMAIN}.crt;
    ssl_certificate_key /etc/nginx/ssl/${DOMAIN}.key;

    # SSL настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;

    # Логи
    access_log /var/log/nginx/familychat-access.log;
    error_log /var/log/nginx/familychat-error.log;

    # Основное приложение
    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket поддержка для Socket.io
    location /socket.io/ {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
EOF

echo "✓ Конфигурация обновлена"

echo ""
echo "4. Проверка конфигурации Nginx..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Конфигурация корректна"
    echo ""
    echo "5. Перезагрузка Nginx..."
    sudo systemctl reload nginx
    echo "✓ Nginx перезагружен"
else
    echo "✗ Ошибка в конфигурации"
    exit 1
fi

echo ""
echo "=== Готово! ==="
echo ""
echo "Сертификат установлен. Теперь:"
echo ""
echo "1. Откройте: https://${SERVER_IP}/"
echo "   или: https://${DOMAIN}/ (если DNS настроен)"
echo ""
echo "2. Браузер покажет предупреждение 'Небезопасное соединение'"
echo "   Нажмите 'Дополнительно' -> 'Перейти на сайт (небезопасно)'"
echo ""
echo "3. Проверьте работу камеры/микрофона:"
echo "   - Chrome: может заблокировать (попробуйте разрешить в настройках)"
echo "   - Firefox: может работать после принятия предупреждения"
echo ""
echo "ВАЖНО: Для полной поддержки камеры/микрофона нужен валидный SSL сертификат"
echo "       (например, от Let's Encrypt с правильным доменом)"

