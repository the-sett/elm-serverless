const co = require('co');
const should = require('should');

const request = require('./request');

const path = (relative) => `/interop/${relative}`;

describe('Demo: /interop', () => {
  describe('GET /unit', () => {
    it('gets a random float between 0 and 1', () => co(function* () {
      const n = 20;
      const responses = yield [...Array(n)].map(() =>
        request.get(path('unit')).expect(200));
      responses.forEach(({ body }) => {
        should(typeof body).equal('number');
        body.toString().should.match(/^[01]\.\d+$/);
        body.should.be.aboveOrEqual(0);
        body.should.be.belowOrEqual(1);
      });
      should(new Set(responses.map(r => r.body)).size).above(1);
    }));
  });
});
