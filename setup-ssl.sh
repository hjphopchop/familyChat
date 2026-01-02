#!/bin/bash

echo "=== Настройка SSL (HTTPS) для FamilyChat ==="
echo ""

DOMAIN="aparfenov1.fvds.ru"

echo "1. Проверка установки Certbot..."
if ! command -v certbot &> /dev/null; then
    echo "Установка Certbot..."
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
else
    echo "✓ Certbot уже установлен"
fi

echo ""
echo "2. Проверка конфигурации Nginx..."
if [ ! -f /etc/nginx/sites-enabled/familychat ]; then
    echo "✗ Конфигурация Nginx не найдена!"
    echo "Сначала запустите: ./setup-nginx.sh"
    exit 1
fi

echo "✓ Конфигурация найдена"

echo ""
echo "3. Проверка DNS записи..."
echo "Убедитесь, что домен ${DOMAIN} указывает на IP этого сервера"
echo "IP сервера: $(curl -s ifconfig.me)"
echo ""
read -p "Домен настроен правильно? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Настройте DNS записи и запустите скрипт снова"
    exit 1
fi

echo ""
echo "4. Получение SSL сертификата..."
echo "Certbot запросит ваш email для уведомлений"
echo ""

sudo certbot --nginx -d ${DOMAIN}

if [ $? -eq 0 ]; then
    echo ""
    echo "=== Готово! ==="
    echo ""
    echo "✓ SSL сертификат установлен"
    echo "✓ Nginx настроен для HTTPS"
    echo ""
    echo "Теперь приложение доступно по адресу:"
    echo "  https://${DOMAIN}/"
    echo ""
    echo "Микрофон и камера теперь будут работать!"
    echo ""
    echo "Примечание: Certbot автоматически настроил редирект с HTTP на HTTPS"
else
    echo ""
    echo "✗ Ошибка при получении сертификата"
    echo "Проверьте:"
    echo "  1. DNS записи домена настроены правильно"
    echo "  2. Порты 80 и 443 открыты в файрволе"
    echo "  3. Nginx запущен и работает"
    exit 1
fi

