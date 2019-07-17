const should = require('should');
const sinon = require('sinon');

const { httpApi } = require('../../src-bridge');
const spyLogger = require('./spy-logger');

const requestPort = 'requestPort';
const responsePort = 'responsePort';
const makeWorkerApp = () => ({
  init: sinon.stub().returns({
    ports: {
      requestPort: { send: sinon.spy() },
      responsePort: { subscribe: sinon.spy() },
    },
  })
});

describe('elmServerless', () => {
  describe('.httpApi({ app, requestPort, responsePort })', () => {
    it('is a function', () => {
      should(httpApi).be.a.Function();
    });

    it('works with valid app, requestPort, and responsePort', () => {
      (() => httpApi({ app: makeWorkerApp().init(), requestPort, responsePort }))
        .should.not.throw();
    });

    it('passes config to the handler.init function', () => {
      const config = { some: { app: ['specific', 'configuration'] } };
      const w = makeWorkerApp();
      const h = w.init({ flags: config });
      httpApi({ app: h, requestPort, responsePort });
      w.init.calledWith({ flags: config }).should.be.true();
    });

    it('subscribes to the responsePort', () => {
      const h = makeWorkerApp().init();
      httpApi({ app: h, requestPort, responsePort });
      const subscribe = h.ports.responsePort.subscribe;
      subscribe.called.should.be.true();
      const call = subscribe.getCall(0);
      const [func] = call.args;
      should(func).be.a.Function();
    });

    it('handles responses', () => {
      const h = makeWorkerApp().init();
      const logger = spyLogger();
      httpApi({ app: h, logger, requestPort, responsePort });
      const subscribe = h.ports.responsePort.subscribe;
      const responseHandler = subscribe.getCalls()[0].args[0];
      logger.error.getCalls().should.be.empty();
      responseHandler(['id', {}]);
      logger.error.getCalls().should.not.be.empty();
      logger.error.getCalls()[0].args.should.deepEqual(['No callback for ID: id']);
    });

    it('returns a request handler', () => {
      const h = makeWorkerApp().init();
      const func = httpApi({ app: h, requestPort, responsePort });
      should(func).be.a.Function();
      should(func.name).equal('requestHandler');
    });

    it('requires an app', () => {
      (() => httpApi({ requestPort, responsePort }))
        .should.throw(/^handler.init did not return valid Elm app.Got: undefined/);
    });

    it('requires a requestPort', () => {
      (() => httpApi({
        app: makeWorkerApp().init(),
        requestPort: 'reqPort',
        responsePort,
      }))
        .should.throw(/^No request port named reqPort among: \[requestPort, responsePort\]$/);
    });

    it('requires a valid requestPort', () => {
      (() => httpApi({
        app: makeWorkerApp().init(),
        requestPort: 'responsePort',
        responsePort,
      }))
        .should.throw(/^Invalid request port/);
    });

    it('requires a responsePort', () => {
      (() => httpApi({
        app: makeWorkerApp().init(),
        requestPort,
        responsePort: 'respPort',
      }))
        .should.throw(/^No response port named respPort among: \[requestPort, responsePort\]$/);
    });

    it('requires a valid responsePort', () => {
      (() => httpApi({
        app: makeWorkerApp().init(),
        requestPort,
        responsePort: 'requestPort',
      }))
        .should.throw(/^Invalid response port/);
    });
  });
});
