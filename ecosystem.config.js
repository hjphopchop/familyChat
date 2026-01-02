module.exports = {
  apps: [{
    name: 'familychat-server',
    script: './server/server.js',
    instances: 1,
    exec_mode: 'fork',
    cwd: '/root/familyChat',
    env_file: '.env',
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      CLIENT_URL: 'https://aparfenov1.fvds.ru'
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G'
  }]
};

