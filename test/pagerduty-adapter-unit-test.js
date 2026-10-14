const assert = require('node:assert/strict');
const { describe, it, beforeEach, afterEach } = require('node:test');
const sinon = require('sinon');

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
      assert.equal(typeof adapter.get, 'function');
      assert.equal(typeof adapter.post, 'function');
      assert.equal(typeof adapter.put, 'function');
      assert.equal(typeof adapter.delete, 'function');
      assert.equal(typeof adapter.getIncidents, 'function');
      assert.equal(typeof adapter.getSchedules, 'function');
      assert.equal(typeof adapter.getIncident, 'function');
      assert.equal(typeof adapter.missingEnvironmentForApi, 'function');
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
      assert.equal(hasMissing, true);
      assert.equal(mockMsg.send.called, true);
      assert.match(mockMsg.send.firstCall.args[0], /API Key/);
    });

    it('detects missing From email', function () {
      delete process.env.HUBOT_PAGERDUTY_FROM_EMAIL;
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const mockMsg = {
        send: sinon.spy(),
      };

      const hasMissing = adapter.missingEnvironmentForApi(mockMsg);
      assert.equal(hasMissing, true);
      assert.equal(mockMsg.send.called, true);
      assert.match(mockMsg.send.firstCall.args[0], /From/);
    });

    it('reports no missing env vars when both are set', function () {
      const adapter = require('../src/lib/pagerduty-client');
      const mockMsg = {
        send: sinon.spy(),
      };

      const hasMissing = adapter.missingEnvironmentForApi(mockMsg);
      assert.equal(hasMissing, false);
      assert.equal(mockMsg.send.called, false);
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

      assert.equal(mockLogger.info.called, true);
      assert.match(mockLogger.info.firstCall.args[0], /Would have POST/);
    });

    it('respects noop=false setting', async function () {
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

      const { err, json } = await new Promise((resolve) => {
        adapter.post('/test', { data: 'test' }, (err, json) => resolve({ err, json }));
      });
      assert.equal(err, null);
      assert.deepEqual(json, { status: 200 });
      assert.equal(postStub.calledOnce, true);
      assert.equal(mockLogger.info.called, false);
      postStub.restore();
    });
  });

  describe('Callback Compatibility', function () {
    it('handles getSchedules with just callback', async function () {
      const adapter = require('../src/lib/pagerduty-client');
      const getStub = sinon.stub(adapter, 'get').callsFake(function (url, query, cb) {
        if (typeof query === 'function') {
          cb = query;
        }
        cb(null, { schedules: [] });
      });

      const { err, schedules } = await new Promise((resolve) => {
        adapter.getSchedules((err, schedules) => resolve({ err, schedules }));
      });
      assert.equal(err, null);
      assert.deepEqual(schedules, []);
      assert.equal(getStub.calledOnce, true);
      getStub.restore();
    });

    it('handles getSchedules with query and callback', async function () {
      const adapter = require('../src/lib/pagerduty-client');
      const getStub = sinon.stub(adapter, 'get').callsFake(function (url, query, cb) {
        cb(null, { schedules: [] });
      });

      const { err, schedules } = await new Promise((resolve) => {
        adapter.getSchedules({ query: 'test' }, (err, schedules) => resolve({ err, schedules }));
      });
      assert.equal(err, null);
      assert.deepEqual(schedules, []);
      assert.equal(getStub.calledOnce, true);
      getStub.restore();
    });

    it('handles getIncidents with status', async function () {
      const adapter = require('../src/lib/pagerduty-client');
      const getStub = sinon.stub(adapter, 'get').callsFake(function (url, query, cb) {
        cb(null, { incidents: [] });
      });

      const { err, incidents } = await new Promise((resolve) => {
        adapter.getIncidents('triggered,acknowledged', (err, incidents) => resolve({ err, incidents }));
      });
      assert.equal(err, null);
      assert.deepEqual(incidents, []);
      assert.equal(getStub.calledOnce, true);
      getStub.restore();
    });
  });
});
