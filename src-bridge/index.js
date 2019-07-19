const xmlhttprequest = require('./xmlhttprequest');

const defaultLogger = require('./logger');
const Pool = require('./pool');
const requestHandler = require('./request-handler');
const responseHandler = require('./response-handler');
const validate = require('./validate');

global.XMLHttpRequest = xmlhttprequest.XMLHttpRequest;

const invalidElmApp = msg => {
  throw new Error(`handler.init did not return valid Elm app.${msg}`);
};

const httpApi = ({
  app,
  logger = defaultLogger,
  requestPort = 'requestPort',
  responsePort = 'responsePort',
} = {}) => {
  if (typeof app !== 'object') {
    invalidElmApp(`Got: ${validate.inspect(app)}`);
  }
  const portNames = `[${Object.keys(app.ports).sort().join(', ')}]`;

  validate(app.ports[responsePort], 'subscribe', {
    missing: `No response port named ${responsePort} among: ${portNames}`,
    invalid: 'Invalid response port',
  });

  validate(app.ports[requestPort], 'send', {
    missing: `No request port named ${requestPort} among: ${portNames}`,
    invalid: 'Invalid request port',
  });

  const pool = new Pool({ logger });
  const handleResponse = responseHandler({ pool, logger });

  app.ports[responsePort].subscribe(([id, jsonValue]) => {
    handleResponse(id, jsonValue);
  });

  return requestHandler({ pool, requestPort: app.ports[requestPort] });
};

module.exports = { httpApi };
