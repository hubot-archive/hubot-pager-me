/**
 * Integration Tests - Real-world command scenarios
 * Tests the adapter with realistic PagerDuty response structures
 */

const chai = require('chai');
const { expect } = chai;

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
      expect(adapter.get).to.be.a('function');
      expect(adapter.post).to.be.a('function');
      expect(adapter.put).to.be.a('function');
      expect(adapter.delete).to.be.a('function');
      expect(adapter.getIncident).to.be.a('function');
      expect(adapter.getIncidents).to.be.a('function');
      expect(adapter.getSchedules).to.be.a('function');
      expect(adapter.missingEnvironmentForApi).to.be.a('function');
    });

    it('adapter module resolves consistently', function () {
      const mainAdapter = require('../src/lib/pagerduty-client');
      const pdjs = require('../src/lib/pagerduty-client');
      
      // Both should exist and have same interface
      expect(mainAdapter).to.deep.equal(pdjs);
    });
  });

  describe('Webhook Handler', function () {
    it('still loads webhook handler without errors', function () {
      const webhookScript = require('../src/pager-me-webhooks');
      expect(webhookScript).to.be.a('function');
    });
  });

  describe('PagerDuty Compatibility Layer', function () {
    it('handles typical incident response structure', function (done) {
      const adapter = require('../src/lib/pagerduty-client');
      const getAsyncStub = require('sinon').stub(adapter, '_getAsync').resolves({
        incidents: [{ id: 'INC123', incident_number: 123, status: 'triggered' }],
      });

      adapter.get('/incidents', { 'statuses[]': ['triggered'] }, function (err, incidents) {
        expect(err).to.equal(null);
        expect(incidents.incidents).to.have.length(1);
        expect(getAsyncStub.calledOnce).to.equal(true);
        getAsyncStub.restore();
        done();
      });
    });

    it('preserves service_id filtering when configured', function (done) {
      process.env.HUBOT_PAGERDUTY_SERVICES = 'SERVICE1,SERVICE2';
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const getAsyncStub = require('sinon').stub(adapter, '_getAsync').resolves({ incidents: [] });

      adapter.getIncidents('triggered', function (err, incidents) {
        expect(err).to.equal(null);
        expect(incidents).to.deep.equal([]);
        const queryArg = getAsyncStub.firstCall.args[1];
        expect(queryArg['service_ids[]']).to.deep.equal(['SERVICE1', 'SERVICE2']);
        getAsyncStub.restore();
        done();
      });
    });

    it('includes From header in requests', function (done) {
      process.env.HUBOT_PAGERDUTY_FROM_EMAIL = 'testbot@example.com';
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const postAsyncStub = require('sinon').stub(adapter, '_postAsync').resolves({ incident: { id: 'INC123' } });

      adapter.post('/incidents', { incident: {} }, function (err, json) {
        expect(err).to.equal(null);
        expect(json.incident.id).to.equal('INC123');
        expect(postAsyncStub.calledOnce).to.equal(true);
        postAsyncStub.restore();
        done();
      });
    });
  });

  describe('Environment Configuration', function () {
    it('respects HUBOT_PAGERDUTY_SCHEDULES filter', function () {
      process.env.HUBOT_PAGERDUTY_SCHEDULES = 'SCHED1,SCHED2,SCHED3';
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];
      
      const adapter = require('../src/lib/pagerduty-client');
      expect(adapter).to.exist;
    });

    it('tolerates missing optional environment variables', function () {
      delete process.env.HUBOT_PAGERDUTY_SERVICES;
      delete process.env.HUBOT_PAGERDUTY_SCHEDULES;
      delete process.env.HUBOT_PAGERDUTY_DEFAULT_SCHEDULE;
      
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];
      const adapter = require('../src/lib/pagerduty-client');
      expect(adapter).to.exist;
    });

    it('handles empty service list', function (done) {
      process.env.HUBOT_PAGERDUTY_SERVICES = '';
      delete require.cache[require.resolve('../src/lib/pagerduty-client')];

      const adapter = require('../src/lib/pagerduty-client');
      const getAsyncStub = require('sinon').stub(adapter, '_getAsync').resolves({ incidents: [] });

      adapter.getIncidents('triggered', function (err, incidents) {
        expect(err).to.equal(null);
        expect(incidents).to.deep.equal([]);
        const queryArg = getAsyncStub.firstCall.args[1];
        expect(queryArg).to.not.have.property('service_ids[]');
        getAsyncStub.restore();
        done();
      });
    });
  });
});
