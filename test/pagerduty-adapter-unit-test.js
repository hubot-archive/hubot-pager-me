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
      const originalLog = console.log;
      console.log = sinon.spy();

      adapter.post('/test', { data: 'test' }, function () {
        // callback should not be called in noop
      });

      expect(console.log).to.have.been.called;
      expect(console.log.firstCall.args[0]).to.include('Would have POST');
      console.log = originalLog;
    });

    it('respects noop=false setting', function () {
      process.env.HUBOT_PAGERDUTY_NOOP = 'false';
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const originalLog = console.log;
      console.log = sinon.spy();

      // This will fail because we don't have valid credentials, but that's expected
      // We just want to verify it tries to execute instead of noop logging
      adapter.post('/test', { data: 'test' }, function (err) {
        // Expected to have error
      });

      expect(console.log).to.not.have.been.called;
      console.log = originalLog;
    });
  });

  describe('Callback Compatibility', function () {
    it('handles getSchedules with just callback', function (done) {
      const adapter = require('../src/lib/pagerduty-client');
      
      // This will fail to call actual API but tests the interface
      adapter.getSchedules(function (err, schedules) {
        // Expected to have error due to invalid credentials
        // Just testing that interface works
        done();
      });
    });

    it('handles getSchedules with query and callback', function (done) {
      const adapter = require('../src/lib/pagerduty-client');
      
      adapter.getSchedules({ query: 'test' }, function (err, schedules) {
        // Expected to have error due to invalid credentials
        done();
      });
    });

    it('handles getIncidents with status', function (done) {
      const adapter = require('../src/lib/pagerduty-client');
      
      adapter.getIncidents('triggered,acknowledged', function (err, incidents) {
        // Expected to have error due to invalid credentials
        done();
      });
    });
  });
});

