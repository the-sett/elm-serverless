const elmServerless = require('../../../src-bridge');
const rc = require('strip-debug-loader!shebang-loader!rc'); // eslint-disable-line

const { Elm } = require('./API.elm');

// Use AWS Lambda environment variables to override these values
// See the npm rc package README for more details
const config = rc('demo', {
  languages: ['en', 'ru'],

  enableAuth: 'false',

  cors: {
    origin: '*',
    methods: 'get,post,options',
  },
});

module.exports.handler = elmServerless.httpApi({
  app: Elm.Quoted.API.init({ flags: config }),
  requestPort: 'requestPort',
  responsePort: 'responsePort',
});
