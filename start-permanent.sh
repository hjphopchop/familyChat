#!/bin/bash

echo "=== Настройка постоянного запуска приложения ==="
echo ""

echo "Вариант 1: PM2 (рекомендуется)"
echo "Вариант 2: systemd service"
echo "Вариант 3: nohup (простой вариант)"
echo ""
read -p "Выберите вариант (1/2/3): " choice

case $choice in
    1)
        echo ""
        echo "=== Установка PM2 ==="
        if ! command -v pm2 &> /dev/null; then
            echo "Установка PM2..."
            sudo npm install -g pm2
        else
            echo "✓ PM2 уже установлен"
        fi
        
        echo ""
        echo "Остановка старого процесса (если запущен)..."
        pm2 delete familychat-server 2>/dev/null
        
        echo ""
        echo "Запуск приложения через PM2..."
        cd /root/familyChat
        pm2 start ecosystem.config.js
        
        echo ""
        echo "Сохранение конфигурации PM2..."
        pm2 save
        
        echo ""
        echo "Настройка автозапуска при загрузке системы..."
        pm2 startup
        echo ""
        echo "⚠ ВНИМАНИЕ: Выполните команду, которую показал PM2 выше (обычно sudo env PATH=...)"
        
        echo ""
        echo "=== Готово! ==="
        echo ""
        echo "Управление приложением:"
        echo "  pm2 status              # статус"
        echo "  pm2 logs                # логи"
        echo "  pm2 restart familychat-server  # перезапуск"
        echo "  pm2 stop familychat-server     # остановка"
        ;;
        
    2)
        echo ""
        echo "=== Создание systemd service ==="
        
        sudo tee /etc/systemd/system/familychat.service > /dev/null <<EOF
[Unit]
Description=FamilyChat Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/familyChat
Environment="NODE_ENV=production"
Environment="PORT=5000"
Environment="CLIENT_URL=https://aparfenov1.fvds.ru"
ExecStart=/usr/bin/node /root/familyChat/server/server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

        echo "✓ Service файл создан"
        
        echo ""
        echo "Обновление systemd..."
        sudo systemctl daemon-reload
        
        echo ""
        echo "Запуск службы..."
        sudo systemctl enable familychat
        sudo systemctl start familychat
        
        echo ""
        echo "=== Готово! ==="
        echo ""
        echo "Управление:"
        echo "  sudo systemctl status familychat   # статус"
        echo "  sudo systemctl restart familychat  # перезапуск"
        echo "  sudo systemctl stop familychat     # остановка"
        echo "  sudo journalctl -u familychat -f   # логи"
        ;;
        
    3)
        echo ""
        echo "=== Запуск через nohup ==="
        
        # Остановка старого процесса
        pkill -f "node.*server.js"
        sleep 2
        
        echo "Запуск приложения в фоне..."
        cd /root/familyChat
        nohup npm run production > server.log 2>&1 &
        
        sleep 2
        
        if ps aux | grep "node.*server.js" | grep -v grep > /dev/null; then
            echo "✓ Приложение запущено"
            echo ""
            echo "Логи: tail -f /root/familyChat/server.log"
        else
            echo "✗ Ошибка при запуске. Проверьте логи: cat /root/familyChat/server.log"
            exit 1
        fi
        
        echo ""
        echo "⚠ ВНИМАНИЕ: nohup не сохраняется при перезагрузке сервера"
        echo "           Используйте PM2 или systemd для постоянного запуска"
        ;;
        
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac

echo ""
echo "Проверка:"
sleep 2
curl -s http://localhost:5000 > /dev/null && echo "✓ Сервер отвечает" || echo "✗ Сервер не отвечает"

