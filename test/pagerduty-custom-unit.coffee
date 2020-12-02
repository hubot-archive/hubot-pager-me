# module.exports = { findOncall, formatTime }
chai = require 'chai'
formatTime = require('../src/scripts/pagerduty-custom.coffee').formatTime
findOncall = require('../src/scripts/pagerduty-custom.coffee').findOncall
setTimeQuery = require('../src/scripts/pagerduty-custom.coffee').setTimeQuery

expect = chai.expect

oncalls = [
  {name: 'yesterday', start: "2020-11-27T17:00:00.000Z", end: "2020-11-29T17:00:00.000Z"},
  {name: 'today',start: "2020-11-29T17:00:00.000Z", end: "2020-11-30T17:00:00.000Z"},
  {name: 'tomorrow',start: "2020-11-30T17:00:00.000Z", end: "2020-12-01T17:00:00.000Z"},
]

timeNow = Date.parse("2020-11-30T13:00:00.000Z")

describe 'custom on call - findOncall', ->
  it 'should return today for `now` timeFrame', ->
    expect(findOncall(oncalls, 'now', timeNow).name).to.equal('today')

  it 'should return yesterday for `was` timeFrame', ->
    expect(findOncall(oncalls, 'was', timeNow).name).to.equal('yesterday')

  it 'should return yesterday for `next` timeFrame', ->
    expect(findOncall(oncalls, 'next', timeNow).name).to.equal('tomorrow')

describe 'custom on call - formatTime', ->
  it 'should format time correctly', ->
    expect(formatTime(oncalls[1].start)).to.equal('Sun Nov 29 18:00')
    expect(formatTime(oncalls[0].end)).to.equal('Sun Nov 29 18:00')
    expect(formatTime(oncalls[2].end)).to.equal('Tue Dec 01 18:00')
  
describe 'custom on call - setTimeQuery', ->
  it 'should return time query according to requested time', ->
    expect(setTimeQuery('now', timeNow).since).to.equal('2020-11-30T13:00:00.000Z')
    expect(setTimeQuery('now', timeNow).untilParam).to.equal('2020-11-30T13:01:00.000Z')