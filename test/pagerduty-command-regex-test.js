const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

describe('pagerduty command regexes', () => {
  const triggerRegex =
    /(pager|major)( me)? (?:trigger|page) ((["'])([^\4]*?)\4|"([^"]*?)"|'([^']*?)'|([\.\w\-]+)) ?(.+)?$/i;
  const schedulesRegex = /(pager|major)( me)? schedules( ((["'])([^]*?)\5|(.+)))?$/i;
  const whosOnCallRegex =
    /who(?:'s|'s|s| is|se)? (?:on call|oncall|on-call)(?:\?)?(?: (?:for )?((["'])([^]*?)\2|(.*?))(?:\?|$))?$/i;

  it('trigger handles users with dots', () => {
    const msg = triggerRegex.exec('pager trigger foo.bar baz');
    assert.equal(msg[8], 'foo.bar');
    assert.equal(msg[9], 'baz');
  });

  it('trigger handles users with spaces', () => {
    const msg = triggerRegex.exec('pager trigger "foo bar" baz');
    assert.equal(msg[5], 'foo bar');
    assert.equal(msg[9], 'baz');
  });

  it('trigger handles users with spaces and single quotes', () => {
    const msg = triggerRegex.exec("pager trigger 'foo bar' baz");
    assert.equal(msg[5], 'foo bar');
    assert.equal(msg[9], 'baz');
  });

  it('trigger handles users without spaces', () => {
    const msg = triggerRegex.exec('pager trigger foo bar baz');
    assert.equal(msg[8], 'foo');
    assert.equal(msg[9], 'bar baz');
  });

  it('schedules handles names with quotes', () => {
    const msg = schedulesRegex.exec('pager schedules "foo bar"');
    assert.equal(msg[6], 'foo bar');
  });

  it('schedules handles names without quotes', () => {
    const msg = schedulesRegex.exec('pager schedules foo bar');
    assert.equal(msg[7], 'foo bar');
  });

  it('schedules handles names without spaces', () => {
    const msg = schedulesRegex.exec('pager schedules foobar');
    assert.equal(msg[7], 'foobar');
  });

  it('who is on call handles bad input', () => {
    const msg = whosOnCallRegex.exec('whos on callllllll');
    assert.equal(msg, null);
  });

  it('who is on call handles no schedule', () => {
    const msg = whosOnCallRegex.exec('whos on call');
    assert.notEqual(msg, null);
  });

  it('who is on call handles schedules with quotes', () => {
    const msg = whosOnCallRegex.exec('whos on call for "foo bar"');
    assert.equal(msg[3], 'foo bar');
  });

  it('who is on call handles schedules with quotes and question mark', () => {
    const msg = whosOnCallRegex.exec('whos on call for "foo bar"?');
    assert.equal(msg[3], 'foo bar');
  });

  it('who is on call handles schedules without quotes', () => {
    const msg = whosOnCallRegex.exec('whos on call for foo bar');
    assert.equal(msg[4], 'foo bar');
  });

  it('who is on call handles schedules without quotes and question mark', () => {
    const msg = whosOnCallRegex.exec('whos on call for foo bar?');
    assert.equal(msg[4], 'foo bar');
  });
});
