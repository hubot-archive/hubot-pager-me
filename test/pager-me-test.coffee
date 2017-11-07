chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

describe 'pagerduty', ->
  before ->
    @triggerRegex = /(pager|major)( me)? (?:trigger|page) ((["'])([^]*?)\4|([\.\w\-]+)) (.+)$/i
    @schedulesRegex = /(pager|major)( me)? schedules( ((["'])([^]*?)\5|(.+)))?$/i
    @whosOnCallRegex = /who(?:’s|'s|s| is|se)? (?:on call|oncall|on-call)(?:\?)?(?: (?:for )?((["'])([^]*?)\2|(.*?))(?:\?|$))?$/i

  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()

    require('../src/scripts/pagerduty')(@robot)

  it 'registers a pager me listener', ->
    expect(@robot.respond).to.have.been.calledWith(/pager( me)?$/i)

  it 'registers a pager me as listener', ->
    expect(@robot.respond).to.have.been.calledWith(/pager(?: me)? as (.*)$/i)

  it 'registers a pager forget me listener', ->
    expect(@robot.respond).to.have.been.calledWith(/pager forget me$/i)

  it 'registers a pager indcident listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? incident (.*)$/i)

  it 'registers a pager sup listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? (inc|incidents|sup|problems)$/i)

  it 'registers a pager trigger listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? (?:trigger|page) ([\w\-]+)$/i)

  it 'registers a pager trigger with message listener', ->
    expect(@robot.respond).to.have.been.calledWith(@triggerRegex)

  it 'registers a pager ack listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(?:pager|major)(?: me)? ack(?:nowledge)? (.+)$/i)

  it 'registers a pager ack! listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? ack(nowledge)?(!)?$/i)

  it 'registers a pager resolve listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(?:pager|major)(?: me)? res(?:olve)?(?:d)? (.+)$/i)

  it 'registers a pager resolve! listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? res(olve)?(d)?(!)?$/i)

  it 'registers a pager notes on listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? notes (.+)$/i)

  it 'registers a pager notes add listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? note ([\d\w]+) (.+)$/i)

  it 'registers a pager schedules listener', ->
    expect(@robot.respond).to.have.been.calledWith(@schedulesRegex)

  it 'registers a pager schedule override listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? (schedule|overrides)( ((["'])([^]*?)\6|([\w\-]+)))?( ([^ ]+)\s*(\d+)?)?$/i)

  it 'registers a pager schedule override details listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? (override) ((["'])([^]*?)\5|([\w\-]+)) ([\w\-:\+]+) - ([\w\-:\+]+)( (.*))?$/i)

  it 'registers a pager override delete listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? (overrides?) ((["'])([^]*?)\5|([\w\-]+)) (delete) (.*)$/i)

  it 'registers a pager link listener', ->
    expect(@robot.respond).to.have.been.calledWith(/pager( me)? (?!schedules?\b|overrides?\b|my schedule\b)(.+) (\d+)$/i)

  it 'registers a pager on call listener', ->
    expect(@robot.respond).to.have.been.calledWith(@whosOnCallRegex)

  it 'registers a pager services listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? services$/i)

  it 'registers a pager maintenance listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(pager|major)( me)? maintenance (\d+) (.+)$/i)

  it 'trigger handles users with dots', ->
    msg = @triggerRegex.exec('pager trigger foo.bar baz')
    expect(msg[6]).to.equal('foo.bar')
    expect(msg[7]).to.equal('baz')

  it 'trigger handles users with spaces', ->
    msg = @triggerRegex.exec('pager trigger "foo bar" baz')
    expect(msg[5]).to.equal('foo bar')
    expect(msg[7]).to.equal('baz')

  it 'trigger handles users with spaces and single quotes', ->
    msg = @triggerRegex.exec("pager trigger 'foo bar' baz")
    expect(msg[5]).to.equal('foo bar')
    expect(msg[7]).to.equal('baz')

  it 'trigger handles users without spaces', ->
    msg = @triggerRegex.exec('pager trigger foo bar baz')
    expect(msg[6]).to.equal('foo')
    expect(msg[7]).to.equal('bar baz')

  it 'schedules handles names with quotes', ->
    msg = @schedulesRegex.exec('pager schedules "foo bar"')
    expect(msg[6]).to.equal('foo bar')

  it 'schedules handles names without quotes', ->
    msg = @schedulesRegex.exec('pager schedules foo bar')
    expect(msg[7]).to.equal('foo bar')

  it 'schedules handles names without spaces', ->
    msg = @schedulesRegex.exec('pager schedules foobar')
    expect(msg[7]).to.equal('foobar')

  it 'whos on call handles bad input', ->
    msg = @whosOnCallRegex.exec('whos on callllllll')
    expect(msg).to.be.null

  it 'whos on call handles no schedule', ->
    msg = @whosOnCallRegex.exec('whos on call')
    expect(msg).to.not.be.null

  it 'whos on call handles schedules with quotes', ->
    msg = @whosOnCallRegex.exec('whos on call for "foo bar"')
    expect(msg[3]).to.equal('foo bar')

  it 'whos on call handles schedules with quotes and quesiton mark', ->
    msg = @whosOnCallRegex.exec('whos on call for "foo bar"?')
    expect(msg[3]).to.equal('foo bar')

  it 'whos on call handles schedules without quotes', ->
    msg = @whosOnCallRegex.exec('whos on call for foo bar')
    expect(msg[4]).to.equal('foo bar')

  it 'whos on call handles schedules without quotes and question mark', ->
    msg = @whosOnCallRegex.exec('whos on call for foo bar?')
    expect(msg[4]).to.equal('foo bar')
