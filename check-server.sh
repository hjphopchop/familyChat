#!/bin/bash

echo "=== Проверка сервера ==="
echo ""

echo "1. Проверка локального доступа к серверу:"
curl -s http://localhost:5000 > /dev/null && echo "✓ Сервер отвечает на localhost:5000" || echo "✗ Сервер НЕ отвечает на localhost:5000"

echo ""
echo "2. Проверка порта 5000:"
netstat -tulpn | grep :5000 && echo "✓ Порт 5000 открыт" || echo "✗ Порт 5000 не найден"

echo ""
echo "3. Проверка процессов Node.js:"
ps aux | grep "node server.js" | grep -v grep && echo "✓ Процесс Node.js запущен" || echo "✗ Процесс Node.js не найден"

echo ""
echo "4. Проверка файрвола (если установлен ufw):"
if command -v ufw &> /dev/null; then
    ufw status | grep 5000 && echo "✓ Порт 5000 открыт в файрволе" || echo "✗ Порт 5000 НЕ открыт в файрволе. Выполните: sudo ufw allow 5000/tcp"
else
    echo "UFW не установлен"
fi

echo ""
echo "5. Проверка Nginx (если установлен):"
if command -v nginx &> /dev/null; then
    systemctl is-active --quiet nginx && echo "✓ Nginx запущен" || echo "✗ Nginx не запущен"
    if [ -f /etc/nginx/sites-enabled/familychat ] || [ -f /etc/nginx/sites-enabled/default ]; then
        echo "✓ Конфигурация Nginx найдена"
    else
        echo "✗ Конфигурация Nginx не найдена"
    fi
else
    echo "Nginx не установлен"
fi

echo ""
echo "=== Тестирование доступа ==="
echo ""
echo "Попробуйте открыть в браузере:"
echo "  - http://aparfenov1.fvds.ru:5000/ (HTTP, не HTTPS)"
echo "  - https://aparfenov1.fvds.ru/ (если настроен Nginx)"

