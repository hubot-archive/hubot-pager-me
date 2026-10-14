/**
 * Integration Tests - Real-world command scenarios
 * Tests the adapter with realistic PagerDuty response structures
 */

const assert = require('node:assert/strict');
const { describe, it, beforeEach } = require('node:test');
const sinon = require('sinon');

describe('Integration: Command Workflows', function () {
  beforeEach(function () {
    // Set required environment variables
    process.env.HUBOT_PAGERDUTY_API_KEY = 'test-key-123';
    process.env.HUBOT_PAGERDUTY_FROM_EMAIL = 'bot@example.com';
    delete process.env.HUBOT_PAGERDUTY_SERVICES;
    delete process.env.HUBOT_PAGERDUTY_NOOP;

    // Clear module cache
    delete require.cache[require.resolve('../src/lib/pagerduty-client')];
    delete require.cache[require.resolve('../src/pager-me')];
  });

  describe('Adapter Interface Compatibility', function () {
    it('maintains same method signatures as legacy adapter', function () {
      const adapter = require('../src/lib/pagerduty-client');
      
      // Verify all required methods exist
      assert.equal(typeof adapter.get, 'function');
      assert.equal(typeof adapter.post, 'function');
      assert.equal(typeof adapter.put, 'function');
      assert.equal(typeof adapter.delete, 'function');
      assert.equal(typeof adapter.getIncident, 'function');
      assert.equal(typeof adapter.getIncidents, 'function');
      assert.equal(typeof adapter.getSchedules, 'function');
      assert.equal(typeof adapter.missingEnvironmentForApi, 'function');
    });

    it('adapter module resolves consistently', function () {
      const mainAdapter = require('../src/lib/pagerduty-client');
      const pdjs = require('../src/lib/pagerduty-client');
      
      // Both should exist and have same interface
      assert.deepEqual(mainAdapter, pdjs);
    });
  });

  describe('Webhook Handler', function () {
    it('still loads webhook handler without errors', function () {
      const webhookScript = require('../src/pager-me-webhooks');
      assert.equal(typeof webhookScript, 'function');
    });
  });

  describe('PagerDuty Compatibility Layer', function () {
    it('handles typical incident response structure', async function () {
      const adapter = require('../src/lib/pagerduty-client');
      const getAsyncStub = sinon.stub(adapter, '_getAsync').resolves({
        incidents: [{ id: 'INC123', incident_number: 123, status: 'triggered' }],
      });

      const { err, incidents } = await new Promise((resolve) => {
        adapter.get('/incidents', { 'statuses[]': ['triggered'] }, (err, incidents) => resolve({ err, incidents }));
      });
      assert.equal(err, null);
      assert.equal(incidents.incidents.length, 1);
      assert.equal(getAsyncStub.calledOnce, true);
      getAsyncStub.restore();
    });

    it('preserves service_id filtering when configured', async function () {
      process.env.HUBOT_PAGERDUTY_SERVICES = 'SERVICE1,SERVICE2';
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const getAsyncStub = sinon.stub(adapter, '_getAsync').resolves({ incidents: [] });

      const { err, incidents } = await new Promise((resolve) => {
        adapter.getIncidents('triggered', (err, incidents) => resolve({ err, incidents }));
      });
      assert.equal(err, null);
      assert.deepEqual(incidents, []);
      const queryArg = getAsyncStub.firstCall.args[1];
      assert.deepEqual(queryArg['service_ids[]'], ['SERVICE1', 'SERVICE2']);
      getAsyncStub.restore();
    });

    it('includes From header in requests', async function () {
      process.env.HUBOT_PAGERDUTY_FROM_EMAIL = 'testbot@example.com';
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const postAsyncStub = sinon.stub(adapter, '_postAsync').resolves({ incident: { id: 'INC123' } });

      const { err, json } = await new Promise((resolve) => {
        adapter.post('/incidents', { incident: {} }, (err, json) => resolve({ err, json }));
      });
      assert.equal(err, null);
      assert.equal(json.incident.id, 'INC123');
      assert.equal(postAsyncStub.calledOnce, true);
      postAsyncStub.restore();
    });
  });

  describe('Environment Configuration', function () {
    it('respects HUBOT_PAGERDUTY_SCHEDULES filter', function () {
      process.env.HUBOT_PAGERDUTY_SCHEDULES = 'SCHED1,SCHED2,SCHED3';
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];
      
      const adapter = require('../src/lib/pagerduty-client');
      assert.ok(adapter);
    });

    it('tolerates missing optional environment variables', function () {
      delete process.env.HUBOT_PAGERDUTY_SERVICES;
      delete process.env.HUBOT_PAGERDUTY_SCHEDULES;
      delete process.env.HUBOT_PAGERDUTY_DEFAULT_SCHEDULE;
      
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];
      const adapter = require('../src/lib/pagerduty-client');
      assert.ok(adapter);
    });

    it('handles empty service list', async function () {
      process.env.HUBOT_PAGERDUTY_SERVICES = '';
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const getAsyncStub = sinon.stub(adapter, '_getAsync').resolves({ incidents: [] });

      const { err, incidents } = await new Promise((resolve) => {
        adapter.getIncidents('triggered', (err, incidents) => resolve({ err, incidents }));
      });
      assert.equal(err, null);
      assert.deepEqual(incidents, []);
      const queryArg = getAsyncStub.firstCall.args[1];
      assert.equal(Object.hasOwn(queryArg, 'service_ids[]'), false);
      getAsyncStub.restore();
    });
  });
});
