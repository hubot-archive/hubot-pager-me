const chai = require('chai');

const { expect } = chai;

describe('pagerduty', function () {
  before(function () {
    this.triggerRegex =
      /(pager|major)( me)? (?:trigger|page) ((["'])([^\4]*?)\4|"([^"]*?)"|'([^']*?)'|([\.\w\-]+)) ?(.+)?$/i;
    this.schedulesRegex = /(pager|major)( me)? schedules( ((["'])([^]*?)\5|(.+)))?$/i;
    this.whosOnCallRegex =
      /who(?:'s|'s|s| is|se)? (?:on call|oncall|on-call)(?:\?)?(?: (?:for )?((["'])([^]*?)\2|(.*?))(?:\?|$))?$/i;
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

  it('whos on call handles schedules with quotes and question mark', function () {
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
