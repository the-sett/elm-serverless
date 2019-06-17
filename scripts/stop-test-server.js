const fs = require('fs');
const psList = require('ps-list'); // eslint-disable-line import/no-extraneous-dependencies
const { spawn } = require('child_process');
const { port } = require('../test/demo/request');

const args = `offline --port=${port}`.split(' ');
const logFile = `${__dirname}/test-server.log`;
const logger = console;

const findServer = () => psList().then(data => {
  const argsPattern = new RegExp(args.join(' '));
  return data.filter(({ name, cmd }) =>
    name === 'node' &&
    argsPattern.test(cmd))[0];
});

findServer().then(server => {
  if (server) {
    logger.info(`Stopping old test server (${server.pid})`);
    process.kill(server.pid);
  }
}).catch(err => {
  logger.info(`Error on stop test server`);
  logger.error(err);
  process.exit(1);
});
