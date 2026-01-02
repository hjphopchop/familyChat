#!/bin/bash

echo "=== Диагностика проблемы Connection Refused ==="
echo ""

echo "1. Проверка процессов Node.js:"
ps aux | grep "node server.js" | grep -v grep
if [ $? -eq 0 ]; then
    echo "✓ Node.js процесс найден"
else
    echo "✗ Node.js процесс НЕ запущен!"
    echo ""
    echo "Запустите сервер:"
    echo "  cd /root/familyChat"
    echo "  npm run production"
    exit 1
fi

echo ""
echo "2. Проверка порта 5000:"
netstat -tulpn | grep :5000
if [ $? -eq 0 ]; then
    echo "✓ Порт 5000 открыт"
else
    echo "✗ Порт 5000 НЕ открыт!"
    exit 1
fi

echo ""
echo "3. Проверка локального подключения:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://127.0.0.1:5000
if [ $? -eq 0 ]; then
    echo "✓ Сервер отвечает на 127.0.0.1:5000"
else
    echo "✗ Сервер НЕ отвечает на 127.0.0.1:5000"
fi

echo ""
echo "4. Проверка подключения через localhost:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:5000
if [ $? -eq 0 ]; then
    echo "✓ Сервер отвечает на localhost:5000"
else
    echo "✗ Сервер НЕ отвечает на localhost:5000"
fi

echo ""
echo "5. Проверка конфигурации Nginx:"
if [ -f /etc/nginx/sites-enabled/familychat ]; then
    echo "✓ Конфигурация найдена"
    echo "Содержимое proxy_pass:"
    grep "proxy_pass" /etc/nginx/sites-enabled/familychat | head -2
else
    echo "✗ Конфигурация не найдена!"
    echo "Запустите: ./setup-nginx.sh"
fi

echo ""
echo "=== Решение ==="
echo ""
echo "Если сервер не запущен, выполните:"
echo "  cd /root/familyChat"
echo "  npm run production"
echo ""
echo "Если сервер запущен, но Nginx не может подключиться, проверьте:"
echo "  - Что сервер слушает на localhost (0.0.0.0:5000 - это правильно)"
echo "  - Что нет других процессов на порту 5000"
echo ""
echo "Перезапустите Nginx после изменений:"
echo "  sudo systemctl reload nginx"

