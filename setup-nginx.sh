#!/bin/bash

echo "=== Настройка Nginx для FamilyChat ==="
echo ""

DOMAIN="aparfenov1.fvds.ru"

echo "1. Создание конфигурации Nginx..."

sudo tee /etc/nginx/sites-available/familychat > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

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
        
        # Таймауты для долгих запросов
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
        
        # Таймауты для WebSocket
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }
}
EOF

echo "✓ Конфигурация создана"

echo ""
echo "2. Активация конфигурации..."

# Удаляем симлинк, если существует
sudo rm -f /etc/nginx/sites-enabled/familychat

# Создаем новый симлинк
sudo ln -s /etc/nginx/sites-available/familychat /etc/nginx/sites-enabled/

echo "✓ Конфигурация активирована"

echo ""
echo "3. Проверка конфигурации Nginx..."

sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Конфигурация корректна"
    echo ""
    echo "4. Перезагрузка Nginx..."
    sudo systemctl reload nginx
    echo "✓ Nginx перезагружен"
else
    echo "✗ Ошибка в конфигурации Nginx!"
    exit 1
fi

echo ""
echo "=== Открытие порта в файрволе ==="
echo ""

if command -v ufw &> /dev/null; then
    echo "Открытие порта 5000..."
    sudo ufw allow 5000/tcp
    echo "✓ Порт 5000 открыт"
    echo ""
    echo "Статус файрвола:"
    sudo ufw status
else
    echo "UFW не установлен, пропускаем настройку файрвола"
fi

echo ""
echo "=== Готово! ==="
echo ""
echo "Теперь приложение должно быть доступно:"
echo "  - http://${DOMAIN}/ (через Nginx на порту 80)"
echo "  - https://${DOMAIN}/ (если настроен SSL)"
echo ""
echo "Проверка:"
echo "  curl http://localhost/"

