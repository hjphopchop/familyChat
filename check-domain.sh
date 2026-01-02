#!/bin/bash

echo "=== Проверка домена aparfenov1.fvds.ru ==="
echo ""

DOMAIN="aparfenov1.fvds.ru"

echo "1. Получение IP сервера:"
SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
echo "IP сервера: $SERVER_IP"

echo ""
echo "2. Проверка DNS записей домена:"
echo "Запрос DNS для $DOMAIN:"
dig +short $DOMAIN || nslookup $DOMAIN 2>/dev/null | grep "Address:" | tail -1

echo ""
echo "3. Проверка доступности домена:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$DOMAIN/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✓ Домен доступен (HTTP $HTTP_CODE)"
else
    echo "✗ Домен недоступен (HTTP $HTTP_CODE или ошибка соединения)"
fi

echo ""
echo "4. Проверка через ping:"
ping -c 2 $DOMAIN 2>&1 | head -3

echo ""
echo "=== Диагностика ==="
echo ""
echo "Если домен не работает, возможные причины:"
echo "  1. DNS записи не настроены"
echo "  2. DNS записи указывают на другой IP"
echo "  3. Домен не зарегистрирован/истек срок"
echo ""
echo "=== Решения ==="
echo ""
echo "Вариант 1: Настроить DNS записи для домена"
echo "  - Добавьте A-запись: $DOMAIN -> $SERVER_IP"
echo "  - Обычно это делается в панели управления доменом"
echo ""
echo "Вариант 2: Использовать самоподписанный сертификат (для тестирования)"
echo "  - Браузер покажет предупреждение"
echo "  - Камера/микрофон могут не работать (зависит от браузера)"
echo ""
echo "Вариант 3: Использовать другой домен или поддомен"

