module.exports = {
  apps: [{
    name: 'openclaw-gw',
    script: process.env.USERPROFILE + '\\AppData\\Roaming\\npm\\node_modules\\openclaw\\openclaw.mjs',
    interpreter: 'node',
    args: 'gateway start',
    cwd: process.env.USERPROFILE,
    restart_delay: 3000,
    max_restarts: 10
  }]
};