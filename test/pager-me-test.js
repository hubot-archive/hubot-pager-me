const chai = require('chai');
const sinon = require('sinon');
chai.use(require('sinon-chai').default);
const { expect } = chai;

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function makeRobot() {
  const robot = {
    name: 'TestBot',
    respond: sinon.spy(),
    emit: sinon.spy(),
    brain: { userForName: sinon.stub().returns(null) },
    logger: { debug: sinon.spy() },
    helpCommands: sinon.stub().returns([]),
  };
  robot.getHandler = function (regex) {
    const call = robot.respond.args.find(([r]) => r.toString() === regex.toString());
    return call && call[1];
  };
  return robot;
}

function makeMsg(matchArray, userOverrides) {
  return {
    match: matchArray,
    send: sinon.spy(),
    reply: sinon.spy(),
    finish: sinon.spy(),
    message: {
      user: Object.assign(
        { id: 'U123', name: 'testuser', email_address: 'test@example.com' },
        userOverrides
      ),
    },
    http: sinon.stub(),
  };
}

// ---------------------------------------------------------------------------
// pager-me.js listener handler tests
// ---------------------------------------------------------------------------

describe('pager-me.js', function () {
  let pagerdutyStub, robot;

  beforeEach(function () {
    process.env.HUBOT_PAGERDUTY_API_KEY = 'test-key';
    process.env.HUBOT_PAGERDUTY_FROM_EMAIL = 'bot@example.com';
    delete process.env.HUBOT_PAGERDUTY_SCHEDULES;
    delete process.env.HUBOT_PAGERDUTY_DEFAULT_SCHEDULE;
    delete process.env.HUBOT_PAGERDUTY_SERVICE_API_KEY;
    delete process.env.HUBOT_PAGERDUTY_USER_ID;

    pagerdutyStub = {
      missingEnvironmentForApi: sinon.stub().returns(false),
      get: sinon.stub(),
      post: sinon.stub(),
      put: sinon.stub(),
      delete: sinon.stub(),
      getIncident: sinon.stub(),
      getIncidents: sinon.stub(),
      getSchedules: sinon.stub(),
    };

    // Default: /users lookup returns one matching user
    pagerdutyStub.get.callsFake(function (url, queryOrCb, cb) {
      if (typeof queryOrCb === 'function') cb = queryOrCb;
      if (/^\/users/.test(url)) {
        cb(null, { users: [{ id: 'PU001', name: 'Test User', email: 'test@example.com', html_url: 'https://pd.test/users/PU001' }] });
      } else {
        cb(null, {});
      }
    });

    require.cache[require.resolve('../src/lib/pagerduty-client')] = {
      id: require.resolve('../src/lib/pagerduty-client'),
      filename: require.resolve('../src/lib/pagerduty-client'),
      loaded: true,
      exports: pagerdutyStub,
    };

    delete require.cache[require.resolve('../src/pager-me')];
    robot = makeRobot();
    require('../src/pager-me')(robot);
  });

  afterEach(function () {
    delete require.cache[require.resolve('../src/lib/pagerduty-client')];
    delete require.cache[require.resolve('../src/pager-me')];
  });

  // -----------------------------------------------------------------------
  describe('pager me as <email>', function () {
    const regex = /pager(?: me)? as (.*)$/i;

    it('stores email on the user and confirms', function () {
      const msg = makeMsg(['pager me as alice@example.com', 'alice@example.com']);
      robot.getHandler(regex)(msg);
      expect(msg.message.user.pagerdutyEmail).to.equal('alice@example.com');
      expect(msg.send).to.have.been.calledWithMatch(/alice@example\.com/);
    });
  });

  // -----------------------------------------------------------------------
  describe('pager forget me', function () {
    const regex = /pager forget me$/i;

    it('clears pagerdutyEmail and confirms', function () {
      const msg = makeMsg(['pager forget me']);
      msg.message.user.pagerdutyEmail = 'old@example.com';
      robot.getHandler(regex)(msg);
      expect(msg.message.user.pagerdutyEmail).to.be.undefined;
      expect(msg.send).to.have.been.calledWithMatch(/forgotten/);
    });
  });

  // -----------------------------------------------------------------------
  describe('pager me (identity + help)', function () {
    const regex = /pager( me)?$/i;

    it('returns early when env vars are missing', function () {
      pagerdutyStub.missingEnvironmentForApi.returns(true);
      const msg = makeMsg(['pager', undefined]);
      robot.getHandler(regex)(msg);
      expect(pagerdutyStub.get).to.not.have.been.called;
    });

    it('shows found user with pagerdutyEmail set', function () {
      const msg = makeMsg(['pager', undefined], { pagerdutyEmail: 'test@example.com' });
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/I found your PagerDuty user/);
    });

    it("shows couldn't find when user lookup returns empty", function () {
      pagerdutyStub.get.callsFake(function (url, queryOrCb, cb) {
        if (typeof queryOrCb === 'function') cb = queryOrCb;
        cb(null, { users: [] });
      });
      const msg = makeMsg(['pager', undefined]);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/Sorry, I expected to get 1 user/);
    });
  });

  // -----------------------------------------------------------------------
  describe('pager incidents / sup / problems', function () {
    const regex = /(pager|major)( me)? (inc|incidents|sup|problems)$/i;

    it('formats triggered and acknowledged incidents', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) {
        cb(null, [
          { incident_number: 1, status: 'triggered',    title: 'Server down', created_at: '2026-01-01T00:00:00Z', assignments: [{ assignee: { summary: 'Alice' } }] },
          { incident_number: 2, status: 'acknowledged', title: 'DB slow',     created_at: '2026-01-01T01:00:00Z', assignments: [] },
        ]);
      });
      const msg = makeMsg(['pager incidents', 'pager', undefined, 'incidents']);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/Triggered/);
      expect(msg.send).to.have.been.calledWithMatch(/Acknowledged/);
    });

    it('says No open incidents when list is empty', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) { cb(null, []); });
      const msg = makeMsg(['pager incidents', 'pager', undefined, 'incidents']);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWith('No open incidents');
    });

    it('emits error on API failure', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) { cb(new Error('API error')); });
      const msg = makeMsg(['pager incidents', 'pager', undefined, 'incidents']);
      robot.getHandler(regex)(msg);
      expect(robot.emit).to.have.been.calledWith('error');
    });
  });

  // -----------------------------------------------------------------------
  describe('pager ack <number>', function () {
    const regex = /(?:pager|major)(?: me)? ack(?:nowledge)? (.+)$/i;

    it('returns early when env vars are missing', function () {
      pagerdutyStub.missingEnvironmentForApi.returns(true);
      const msg = makeMsg(['pager ack 1', '1']);
      robot.getHandler(regex)(msg);
      expect(pagerdutyStub.getIncidents).to.not.have.been.called;
    });

    it('acks matched incident and replies with acked count', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) {
        cb(null, [{ id: 'INC1', incident_number: 1, status: 'triggered', assignments: [] }]);
      });
      pagerdutyStub.put.callsFake(function (url, data, cb) {
        cb(null, { incidents: [{ incident_number: 1 }] });
      });
      const msg = makeMsg(['pager ack 1', '1']);
      robot.getHandler(regex)(msg);
      expect(pagerdutyStub.put).to.have.been.called;
      expect(msg.reply).to.have.been.calledWithMatch(/acknowledged/);
    });

    it('replies with error message when incident not found', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) {
        cb(null, [{ id: 'INC2', incident_number: 2, status: 'triggered', assignments: [] }]);
      });
      const msg = makeMsg(['pager ack 99', '99']);
      robot.getHandler(regex)(msg);
      expect(msg.reply).to.have.been.calledWithMatch(/Couldn't find incident/);
    });
  });

  // -----------------------------------------------------------------------
  describe('pager ack (no number)', function () {
    const regex = /(pager|major)( me)? ack(nowledge)?(!)?$/i;

    it('says Nothing to acknowledge when no incidents exist', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) { cb(null, []); });
      const msg = makeMsg(['pager ack', 'pager', undefined, undefined, undefined]);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWith('Nothing to acknowledge');
    });

    it('says Nothing assigned to you when incidents belong to others', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) {
        cb(null, [{ id: 'INC1', incident_number: 1, status: 'triggered', assignments: [{ assignee: { id: 'OTHER_USER' } }] }]);
      });
      const msg = makeMsg(['pager ack', 'pager', undefined, undefined, undefined]);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/Nothing assigned to you/);
    });

    it('force flag acks all incidents regardless of assignee', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) {
        cb(null, [{ id: 'INC1', incident_number: 1, status: 'triggered', assignments: [{ assignee: { id: 'OTHER_USER' } }] }]);
      });
      pagerdutyStub.put.callsFake(function (url, data, cb) {
        cb(null, { incidents: [{ incident_number: 1 }] });
      });
      const msg = makeMsg(['pager ack!', 'pager', undefined, undefined, '!']);
      robot.getHandler(regex)(msg);
      expect(pagerdutyStub.put).to.have.been.called;
    });

    it('emits error when getIncidents fails', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) { cb(new Error('fail')); });
      const msg = makeMsg(['pager ack', 'pager', undefined, undefined, undefined]);
      robot.getHandler(regex)(msg);
      expect(robot.emit).to.have.been.calledWith('error');
    });
  });

  // -----------------------------------------------------------------------
  describe('pager resolve <number>', function () {
    const regex = /(?:pager|major)(?: me)? res(?:olve)?(?:d)? (.+)$/i;

    it('resolves matched incident and reports success', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) {
        cb(null, [{ id: 'INC1', incident_number: 1, status: 'triggered', assignments: [] }]);
      });
      pagerdutyStub.put.callsFake(function (url, data, cb) {
        cb(null, { incidents: [{ incident_number: 1 }] });
      });
      const msg = makeMsg(['pager resolve 1', '1']);
      robot.getHandler(regex)(msg);
      expect(msg.reply).to.have.been.calledWithMatch(/resolved/);
    });
  });

  // -----------------------------------------------------------------------
  describe('pager resolve (no number)', function () {
    const regex = /(pager|major)( me)? res(olve)?(d)?(!)?$/i;

    it('says Nothing to resolve when no acknowledged incidents', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) { cb(null, []); });
      const msg = makeMsg(['pager resolve', 'pager', undefined, 'olve', undefined, undefined]);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWith('Nothing to resolve');
    });

    it('says Nothing assigned to you when incidents belong to others', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) {
        cb(null, [{ id: 'INC1', incident_number: 1, status: 'acknowledged', assignments: [{ assignee: { id: 'OTHER_USER' } }] }]);
      });
      const msg = makeMsg(['pager resolve', 'pager', undefined, 'olve', undefined, undefined]);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/Nothing assigned to you/);
    });

    it('force flag resolves all acknowledged incidents', function () {
      pagerdutyStub.getIncidents.callsFake(function (status, cb) {
        cb(null, [{ id: 'INC1', incident_number: 1, status: 'acknowledged', assignments: [{ assignee: { id: 'OTHER_USER' } }] }]);
      });
      pagerdutyStub.put.callsFake(function (url, data, cb) {
        cb(null, { incidents: [{ incident_number: 1 }] });
      });
      const msg = makeMsg(['pager resolve!', 'pager', undefined, 'olve', undefined, '!']);
      robot.getHandler(regex)(msg);
      expect(pagerdutyStub.put).to.have.been.called;
    });
  });

  // -----------------------------------------------------------------------
  describe('pager notes <incident_id>', function () {
    const regex = /(pager|major)( me)? notes (.+)$/i;

    it('lists notes for an incident', function () {
      pagerdutyStub.get.callsFake(function (url, query, cb) {
        if (typeof query === 'function') cb = query;
        if (/^\/users/.test(url)) {
          cb(null, { users: [{ id: 'PU001' }] });
        } else if (url.includes('/notes')) {
          cb(null, { notes: [
            { id: 'N1', content: 'Investigating now', created_at: '2026-01-01T00:00:00Z', user: { summary: 'Alice' } },
          ] });
        }
      });
      const msg = makeMsg(['pager notes 1', 'pager', undefined, '1']);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/Investigating now/);
    });

    it('emits error on API failure', function () {
      pagerdutyStub.get.callsFake(function (url, query, cb) {
        if (typeof query === 'function') cb = query;
        if (/^\/users/.test(url)) {
          cb(null, { users: [{ id: 'PU001' }] });
        } else {
          cb(new Error('API error'));
        }
      });
      const msg = makeMsg(['pager notes 1', 'pager', undefined, '1']);
      robot.getHandler(regex)(msg);
      expect(robot.emit).to.have.been.calledWith('error');
    });
  });

  // -----------------------------------------------------------------------
  describe('pager note <incident_id> <content>', function () {
    const regex = /(pager|major)( me)? note ([\d\w]+) (.+)$/i;

    it('adds a note and reports success', function () {
      pagerdutyStub.post.callsFake(function (url, data, cb) {
        cb(null, { note: { content: 'All clear' } });
      });
      const msg = makeMsg(['pager note 1 All clear', 'pager', undefined, '1', 'All clear']);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/Note created: All clear/);
    });

    it('reports failure when response contains no note', function () {
      pagerdutyStub.post.callsFake(function (url, data, cb) { cb(null, {}); });
      const msg = makeMsg(['pager note 1 All clear', 'pager', undefined, '1', 'All clear']);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/couldn't do it/);
    });

    it('emits error on API failure', function () {
      pagerdutyStub.post.callsFake(function (url, data, cb) { cb(new Error('fail')); });
      const msg = makeMsg(['pager note 1 All clear', 'pager', undefined, '1', 'All clear']);
      robot.getHandler(regex)(msg);
      expect(robot.emit).to.have.been.calledWith('error');
    });
  });

  // -----------------------------------------------------------------------
  describe('pager schedules', function () {
    const regex = /(pager|major)( me)? schedules( ((["'])([^]*?)\5|(.+)))?$/i;

    it('lists schedules', function () {
      pagerdutyStub.getSchedules.callsFake(function (query, cb) {
        if (typeof query === 'function') cb = query;
        cb(null, [{ id: 'S1', name: 'Primary On-Call', html_url: 'https://pd.test/S1' }]);
      });
      const msg = makeMsg(['pager schedules', 'pager', undefined]);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/Primary On-Call/);
    });

    it('says No schedules found when none exist', function () {
      pagerdutyStub.getSchedules.callsFake(function (query, cb) {
        if (typeof query === 'function') cb = query;
        cb(null, []);
      });
      const msg = makeMsg(['pager schedules', 'pager', undefined]);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWith('No schedules found!');
    });

    it('emits error on API failure', function () {
      pagerdutyStub.getSchedules.callsFake(function (query, cb) {
        if (typeof query === 'function') cb = query;
        cb(new Error('fail'));
      });
      const msg = makeMsg(['pager schedules', 'pager', undefined]);
      robot.getHandler(regex)(msg);
      expect(robot.emit).to.have.been.calledWith('error');
    });
  });

  // -----------------------------------------------------------------------
  describe('pager services', function () {
    const regex = /(pager|major)( me)? services$/i;

    it('lists services', function () {
      pagerdutyStub.get.callsFake(function (url, query, cb) {
        if (typeof query === 'function') cb = query;
        cb(null, { services: [{ id: 'SVC1', name: 'Production API', status: 'active', html_url: 'https://pd.test/SVC1' }] });
      });
      const msg = makeMsg(['pager services', 'pager', undefined]);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/Production API/);
    });

    it('says No services found when none exist', function () {
      pagerdutyStub.get.callsFake(function (url, query, cb) {
        if (typeof query === 'function') cb = query;
        cb(null, { services: [] });
      });
      const msg = makeMsg(['pager services', 'pager', undefined]);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWith('No services found!');
    });
  });

  // -----------------------------------------------------------------------
  describe('pager maintenance <minutes> <service_ids>', function () {
    const regex = /(pager|major)( me)? maintenance (\d+) (.+)$/i;

    it('opens a maintenance window and reports success', function () {
      pagerdutyStub.post.callsFake(function (url, data, cb) {
        cb(null, { maintenance_window: { id: 'MW1', end_time: '2026-01-01T02:00:00Z' } });
      });
      const msg = makeMsg(['pager maintenance 60 SVC1', 'pager', undefined, '60', 'SVC1']);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/Maintenance window created/);
    });

    it('reports failure when post returns no window', function () {
      pagerdutyStub.post.callsFake(function (url, data, cb) { cb(null, {}); });
      const msg = makeMsg(['pager maintenance 60 SVC1', 'pager', undefined, '60', 'SVC1']);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/didn't work/);
    });
  });

  // -----------------------------------------------------------------------
  describe('pager trigger <user/schedule> (prompt for message)', function () {
    const regex = /(pager|major)( me)? (?:trigger|page) ([\w\-]+)$/i;

    it('prompts the user to include a schedule and message', function () {
      const msg = makeMsg(['pager trigger foo', 'pager', undefined, 'foo']);
      robot.getHandler(regex)(msg);
      expect(msg.reply).to.have.been.calledWithMatch(/Please include a user or schedule/);
    });
  });

  // -----------------------------------------------------------------------
  describe('pager override <schedule> delete <id>', function () {
    const regex = /(pager|major)( me)? (overrides?) ((["'])([^]*?)\5|([\w\-]+)) (delete) (.*)$/i;

    it('deletes override and sends :boom:', function () {
      pagerdutyStub.getSchedules.callsFake(function (query, cb) {
        if (typeof query === 'function') cb = query;
        cb(null, [{ id: 'S1', name: 'Primary' }]);
      });
      pagerdutyStub.delete.callsFake(function (url, cb) { cb(null, true); });
      const msg = makeMsg(
        ['pager override Primary delete OVR1', 'pager', undefined, 'override', 'Primary', undefined, undefined, 'Primary', 'delete', 'OVR1']
      );
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWith(':boom:');
    });

    it('reports failure when delete returns false', function () {
      pagerdutyStub.getSchedules.callsFake(function (query, cb) {
        if (typeof query === 'function') cb = query;
        cb(null, [{ id: 'S1', name: 'Primary' }]);
      });
      pagerdutyStub.delete.callsFake(function (url, cb) { cb(null, false); });
      const msg = makeMsg(
        ['pager override Primary delete OVR1', 'pager', undefined, 'override', 'Primary', undefined, undefined, 'Primary', 'delete', 'OVR1']
      );
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWith('Something went weird.');
    });

    it('says could not find any schedules when none match', function () {
      pagerdutyStub.getSchedules.callsFake(function (query, cb) {
        if (typeof query === 'function') cb = query;
        cb(null, []);
      });
      const msg = makeMsg(
        ['pager override Primary delete OVR1', 'pager', undefined, 'override', 'Primary', undefined, undefined, 'Primary', 'delete', 'OVR1']
      );
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/couldn't find any schedules/);
    });
  });

  // -----------------------------------------------------------------------
  describe("who's on call", function () {
    const regex = /who(?:’s|'s|s| is|se)? (?:on call|oncall|on-call)(?:\?)?(?: (?:for )?((["'])([^]*?)\2|(.*?))(?:\?|$))?$/i;

    it('lists who is on call for each schedule', function (done) {
      pagerdutyStub.getSchedules.callsFake(function (queryOrCb, cb) {
        if (typeof queryOrCb === 'function') cb = queryOrCb;
        cb(null, [{ id: 'S1', name: 'Primary', html_url: 'https://pd.test/S1' }]);
      });
      pagerdutyStub.get.callsFake(function (url, query, cb) {
        if (typeof query === 'function') cb = query;
        if (url.includes('/schedules') && url.includes('/users')) {
          cb(null, { users: [{ id: 'PU001', name: 'Alice' }] });
        } else {
          cb(null, { users: [{ id: 'PU001', name: 'Alice', email: 'alice@example.com' }] });
        }
      });
      const msg = makeMsg(['whos on call', undefined, undefined, undefined, undefined]);
      robot.getHandler(regex)(msg);
      setImmediate(function () {
        expect(msg.send).to.have.been.calledWithMatch(/Alice/);
        done();
      });
    });

    it('says No schedules found when none exist', function () {
      pagerdutyStub.getSchedules.callsFake(function (queryOrCb, cb) {
        if (typeof queryOrCb === 'function') cb = queryOrCb;
        cb(null, []);
      });
      const msg = makeMsg(['whos on call', undefined, undefined, undefined, undefined]);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWith('No schedules found!');
    });
  });

  // -----------------------------------------------------------------------
  describe('am i on call', function () {
    const regex = /am i on (call|oncall|on-call)/i;

    it('confirms when the caller is on call for a schedule', function (done) {
      pagerdutyStub.getSchedules.callsFake(function (cb) {
        cb(null, [{ id: 'S1', name: 'Primary', html_url: 'https://pd.test/S1' }]);
      });
      pagerdutyStub.get.callsFake(function (url, query, cb) {
        if (typeof query === 'function') cb = query;
        cb(null, { users: [{ id: 'PU001', name: 'Test User', email: 'test@example.com' }] });
      });
      const msg = makeMsg(['am i on call', 'call']);
      robot.getHandler(regex)(msg);
      setImmediate(function () {
        setImmediate(function () {
          expect(msg.send).to.have.been.calledWithMatch(/Yes, you are on call/);
          done();
        });
      });
    });

    it('says no when someone else is on call', function (done) {
      pagerdutyStub.getSchedules.callsFake(function (cb) {
        cb(null, [{ id: 'S1', name: 'Primary', html_url: 'https://pd.test/S1' }]);
      });
      pagerdutyStub.get.callsFake(function (url, query, cb) {
        if (typeof query === 'function') cb = query;
        if (url.includes('/schedules') && url.includes('/users')) {
          cb(null, { users: [{ id: 'PU999', name: 'Bob' }] });
        } else {
          cb(null, { users: [{ id: 'PU001', name: 'Test User', email: 'test@example.com' }] });
        }
      });
      const msg = makeMsg(['am i on call', 'call']);
      robot.getHandler(regex)(msg);
      setImmediate(function () {
        setImmediate(function () {
          expect(msg.send).to.have.been.calledWithMatch(/NOT on call/);
          done();
        });
      });
    });
  });

  // -----------------------------------------------------------------------
  describe('pager default trigger (missing default schedule)', function () {
    const regex = /(pager|major)( me)? default (?:trigger|page) ?(.+)?$/i;

    it('warns when HUBOT_PAGERDUTY_DEFAULT_SCHEDULE is not set', function () {
      delete process.env.HUBOT_PAGERDUTY_DEFAULT_SCHEDULE;
      delete require.cache[require.resolve('../src/pager-me')];
      robot = makeRobot();
      require('../src/pager-me')(robot);
      const msg = makeMsg(['pager default trigger help', 'pager', undefined, 'help']);
      robot.getHandler(regex)(msg);
      expect(msg.send).to.have.been.calledWithMatch(/No default schedule configured/);
    });
  });
});
