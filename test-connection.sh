#!/bin/bash

echo "=== Тестирование подключения ==="
echo ""

DOMAIN="aparfenov1.fvds.ru"

echo "1. Тест локального доступа к Node.js (порт 5000):"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:5000

echo ""
echo "2. Тест доступа через Nginx (порт 80):"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost/

echo ""
echo "3. Проверка ответа Nginx:"
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [ "$response" = "200" ]; then
    echo "✓ Nginx успешно проксирует запросы на Node.js"
else
    echo "✗ Проблема: HTTP Status $response"
    echo "Проверьте логи: sudo tail -20 /var/log/nginx/familychat-error.log"
fi

echo ""
echo "4. Проверка Socket.io endpoint:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost/socket.io/

echo ""
echo "=== Результат ==="
echo ""
echo "Откройте в браузере:"
echo "  ✓ http://${DOMAIN}/"
echo ""
echo "Если не открывается, проверьте:"
echo "  1. Файрвол: sudo ufw status"
echo "  2. Логи Nginx: sudo tail -f /var/log/nginx/familychat-error.log"
echo "  3. Логи сервера (в терминале, где запущен npm run production)"

