module.exports = {
  apps: [
    {
      name: 'Shiroi',
      script: './server.js',
      cwd: __dirname,
      exec_mode: 'fork',
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: '180M',
      env: {
        NODE_ENV: 'production',
        HOSTNAME: '0.0.0.0',
        PORT: process.env.PORT || 2323,
      },
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      merge_logs: true,
    },
  ],
}
