const chai = require('chai');
const sinon = require('sinon');
chai.use(require('sinon-chai'));
const { expect } = chai;

describe('PagerDuty PDjs Adapter', function () {
  beforeEach(function () {
    // Set required environment variables
    process.env.HUBOT_PAGERDUTY_API_KEY = 'test-key-123';
    process.env.HUBOT_PAGERDUTY_FROM_EMAIL = 'bot@example.com';
    delete process.env.HUBOT_PAGERDUTY_SERVICES;
    delete process.env.HUBOT_PAGERDUTY_NOOP;
  });

  afterEach(function () {
    delete require.cache[require.resolve('../src/lib/pagerduty-client')];
  });

  describe('API Adapter Initialization', function () {
    it('exports required methods', function () {
      const adapter = require('../src/lib/pagerduty-client');
      expect(adapter).to.have.property('get').that.is.a('function');
      expect(adapter).to.have.property('post').that.is.a('function');
      expect(adapter).to.have.property('put').that.is.a('function');
      expect(adapter).to.have.property('delete').that.is.a('function');
      expect(adapter).to.have.property('getIncidents').that.is.a('function');
      expect(adapter).to.have.property('getSchedules').that.is.a('function');
      expect(adapter).to.have.property('getIncident').that.is.a('function');
      expect(adapter).to.have.property('missingEnvironmentForApi').that.is.a('function');
    });
  });

  describe('Environment Validation', function () {
    it('detects missing API key', function () {
      delete process.env.HUBOT_PAGERDUTY_API_KEY;
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const mockMsg = {
        send: sinon.spy(),
      };

      const hasMissing = adapter.missingEnvironmentForApi(mockMsg);
      expect(hasMissing).to.be.true;
      expect(mockMsg.send).to.have.been.called;
      expect(mockMsg.send.firstCall.args[0]).to.include('API Key');
    });

    it('detects missing From email', function () {
      delete process.env.HUBOT_PAGERDUTY_FROM_EMAIL;
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const mockMsg = {
        send: sinon.spy(),
      };

      const hasMissing = adapter.missingEnvironmentForApi(mockMsg);
      expect(hasMissing).to.be.true;
      expect(mockMsg.send).to.have.been.called;
      expect(mockMsg.send.firstCall.args[0]).to.include('From');
    });

    it('reports no missing env vars when both are set', function () {
      const adapter = require('../src/lib/pagerduty-client');
      const mockMsg = {
        send: sinon.spy(),
      };

      const hasMissing = adapter.missingEnvironmentForApi(mockMsg);
      expect(hasMissing).to.be.false;
      expect(mockMsg.send).to.not.have.been.called;
    });
  });

  describe('Noop Mode', function () {
    it('logs instead of executing in noop mode', function () {
      process.env.HUBOT_PAGERDUTY_NOOP = 'true';
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const mockLogger = {
        debug: sinon.spy(),
        info: sinon.spy(),
        warn: sinon.spy(),
        error: sinon.spy(),
      };
      adapter.setLogger(mockLogger);

      adapter.post('/test', { data: 'test' }, function () {
        // callback should not be called in noop
      });

      expect(mockLogger.info).to.have.been.called;
      expect(mockLogger.info.firstCall.args[0]).to.include('Would have POST');
    });

    it('respects noop=false setting', function (done) {
      process.env.HUBOT_PAGERDUTY_NOOP = 'false';
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const mockLogger = {
        debug: sinon.spy(),
        info: sinon.spy(),
        warn: sinon.spy(),
        error: sinon.spy(),
      };
      adapter.setLogger(mockLogger);
      const postStub = sinon.stub(adapter, '_postAsync').resolves({ status: 200 });

      adapter.post('/test', { data: 'test' }, function (err, json) {
        expect(err).to.equal(null);
        expect(json).to.deep.equal({ status: 200 });
        expect(postStub).to.have.been.calledOnce;
        expect(mockLogger.info).to.not.have.been.called;
        postStub.restore();
        done();
      });
    });
  });

  describe('Callback Compatibility', function () {
    it('handles getSchedules with just callback', function (done) {
      const adapter = require('../src/lib/pagerduty-client');
      const getStub = sinon.stub(adapter, 'get').callsFake(function (url, query, cb) {
        if (typeof query === 'function') {
          cb = query;
        }
        cb(null, { schedules: [] });
      });

      adapter.getSchedules(function (err, schedules) {
        expect(err).to.equal(null);
        expect(schedules).to.deep.equal([]);
        expect(getStub).to.have.been.calledOnce;
        getStub.restore();
        done();
      });
    });

    it('handles getSchedules with query and callback', function (done) {
      const adapter = require('../src/lib/pagerduty-client');
      const getStub = sinon.stub(adapter, 'get').callsFake(function (url, query, cb) {
        cb(null, { schedules: [] });
      });

      adapter.getSchedules({ query: 'test' }, function (err, schedules) {
        expect(err).to.equal(null);
        expect(schedules).to.deep.equal([]);
        expect(getStub).to.have.been.calledOnce;
        getStub.restore();
        done();
      });
    });

    it('handles getIncidents with status', function (done) {
      const adapter = require('../src/lib/pagerduty-client');
      const getStub = sinon.stub(adapter, 'get').callsFake(function (url, query, cb) {
        cb(null, { incidents: [] });
      });

      adapter.getIncidents('triggered,acknowledged', function (err, incidents) {
        expect(err).to.equal(null);
        expect(incidents).to.deep.equal([]);
        expect(getStub).to.have.been.calledOnce;
        getStub.restore();
        done();
      });
    });
  });
});

