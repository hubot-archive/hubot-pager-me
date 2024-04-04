const chai = require('chai');
const sinon = require('sinon');
chai.use(require('sinon-chai'));

const { expect } = chai;

describe('pagerduty', function () {
  before(function () {
    this.triggerRegex =
      /(pager|major)( me)? (?:trigger|page) ((["'])([^\4]*?)\4|“([^”]*?)”|‘([^’]*?)’|([\.\w\-]+)) (.+)$/i;
    this.schedulesRegex = /(pager|major)( me)? schedules( ((["'])([^]*?)\5|(.+)))?$/i;
    this.whosOnCallRegex =
      /who(?:’s|'s|s| is|se)? (?:on call|oncall|on-call)(?:\?)?(?: (?:for )?((["'])([^]*?)\2|(.*?))(?:\?|$))?$/i;
  });

  beforeEach(function () {
    this.robot = {
      respond: sinon.spy(),
      hear: sinon.spy(),
    };

    require('../src/scripts/pagerduty')(this.robot);
  });

  it('registers a pager me listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/pager( me)?$/i);
  });

  it('registers a pager me as listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/pager(?: me)? as (.*)$/i);
  });

  it('registers a pager forget me listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/pager forget me$/i);
  });

  it('registers a pager incident listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/(pager|major)( me)? incident ([a-z0-9]+)$/i);
  });

  it('registers a pager sup listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/(pager|major)( me)? (inc|incidents|sup|problems)$/i);
  });

  it('registers a pager trigger listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/(pager|major)( me)? (?:trigger|page) ([\w\-]+)$/i);
  });

  it('registers a pager trigger with message listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(this.triggerRegex);
  });

  it('registers a pager ack listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/(?:pager|major)(?: me)? ack(?:nowledge)? (.+)$/i);
  });

  it('registers a pager ack! listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/(pager|major)( me)? ack(nowledge)?(!)?$/i);
  });

  it('registers a pager resolve listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/(?:pager|major)(?: me)? res(?:olve)?(?:d)? (.+)$/i);
  });

  it('registers a pager resolve! listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/(pager|major)( me)? res(olve)?(d)?(!)?$/i);
  });

  it('registers a pager notes on listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/(pager|major)( me)? notes (.+)$/i);
  });

  it('registers a pager notes add listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/(pager|major)( me)? note ([\d\w]+) (.+)$/i);
  });

  it('registers a pager schedules listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(this.schedulesRegex);
  });

  it('registers a pager schedule override listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(
      /(pager|major)( me)? (schedule|overrides)( ((["'])([^]*?)\6|([\w\-]+)))?( ([^ ]+)\s*(\d+)?)?$/i
    );
  });

  it('registers a pager schedule override details listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(
      /(pager|major)( me)? (override) ((["'])([^]*?)\5|([\w\-]+)) ([\w\-:\+]+) - ([\w\-:\+]+)( (.*))?$/i
    );
  });

  it('registers a pager override delete listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(
      /(pager|major)( me)? (overrides?) ((["'])([^]*?)\5|([\w\-]+)) (delete) (.*)$/i
    );
  });

  it('registers a pager link listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(
      /pager( me)? (?!schedules?\b|overrides?\b|my schedule\b)(.+) (\d+)$/i
    );
  });

  it('registers a pager on call listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(this.whosOnCallRegex);
  });

  it('registers a pager services listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/(pager|major)( me)? services$/i);
  });

  it('registers a pager maintenance listener', function () {
    expect(this.robot.respond).to.have.been.calledWith(/(pager|major)( me)? maintenance (\d+) (.+)$/i);
  });

  it('trigger handles users with dots', function () {
    const msg = this.triggerRegex.exec('pager trigger foo.bar baz');
    expect(msg[8]).to.equal('foo.bar');
    expect(msg[9]).to.equal('baz');
  });

  it('trigger handles users with spaces', function () {
    const msg = this.triggerRegex.exec('pager trigger "foo bar" baz');
    expect(msg[5]).to.equal('foo bar');
    expect(msg[9]).to.equal('baz');
  });

  it('trigger handles users with spaces and single quotes', function () {
    const msg = this.triggerRegex.exec("pager trigger 'foo bar' baz");
    expect(msg[5]).to.equal('foo bar');
    expect(msg[9]).to.equal('baz');
  });

  it('trigger handles users without spaces', function () {
    const msg = this.triggerRegex.exec('pager trigger foo bar baz');
    expect(msg[8]).to.equal('foo');
    expect(msg[9]).to.equal('bar baz');
  });

  it('schedules handles names with quotes', function () {
    const msg = this.schedulesRegex.exec('pager schedules "foo bar"');
    expect(msg[6]).to.equal('foo bar');
  });

  it('schedules handles names without quotes', function () {
    const msg = this.schedulesRegex.exec('pager schedules foo bar');
    expect(msg[7]).to.equal('foo bar');
  });

  it('schedules handles names without spaces', function () {
    const msg = this.schedulesRegex.exec('pager schedules foobar');
    expect(msg[7]).to.equal('foobar');
  });

  it('whos on call handles bad input', function () {
    const msg = this.whosOnCallRegex.exec('whos on callllllll');
    expect(msg).to.be.null;
  });

  it('whos on call handles no schedule', function () {
    const msg = this.whosOnCallRegex.exec('whos on call');
    expect(msg).to.not.be.null;
  });

  it('whos on call handles schedules with quotes', function () {
    const msg = this.whosOnCallRegex.exec('whos on call for "foo bar"');
    expect(msg[3]).to.equal('foo bar');
  });

  it('whos on call handles schedules with quotes and quesiton mark', function () {
    const msg = this.whosOnCallRegex.exec('whos on call for "foo bar"?');
    expect(msg[3]).to.equal('foo bar');
  });

  it('whos on call handles schedules without quotes', function () {
    const msg = this.whosOnCallRegex.exec('whos on call for foo bar');
    expect(msg[4]).to.equal('foo bar');
  });

  it('whos on call handles schedules without quotes and question mark', function () {
    const msg = this.whosOnCallRegex.exec('whos on call for foo bar?');
    expect(msg[4]).to.equal('foo bar');
  });
});
