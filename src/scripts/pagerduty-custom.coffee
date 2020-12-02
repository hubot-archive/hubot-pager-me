pagerduty = require('../pagerduty')

# selects the right oncall based on current time
findOncall = (oncalls, timeFrame, timeNow) ->
  if timeFrame is 'was'
    return oncalls.find((oncall) ->
      Date.parse(oncall.start) < timeNow - (24 * 3600000) < Date.parse(oncall.end)
    )
  if timeFrame is 'next'
    return oncalls.find((oncall) ->
      Date.parse(oncall.start) > timeNow
    )
  return oncalls.find((oncall) ->
      Date.parse(oncall.start) < timeNow < Date.parse(oncall.end)
    )

# formats time to show the name of the day, month, day and time
formatTime = (date) ->
  dateTime = new Date(date).toString()
  return "#{dateTime.substring(0, 10)} #{dateTime.substring(16, 21)}"

# according to requesed time (on call, now, on call next, was on call) prepares time query
# pagerduty limits the amount of returned data, so more precise time settings
setTimeQuery = (timeFrame, timeNow)  ->
  past = new Date(timeNow - (72 * 3600000)).toISOString()
  future = new Date(timeNow + (72 * 3600000)).toISOString()
  plusMinute = new Date(timeNow + 60000).toISOString()
  
  if timeFrame is 'was'
    return { since: past, untilParam: new Date(timeNow).toISOString() }

  if timeFrame is 'next'
    return { since: new Date(timeNow).toISOString(), untilParam: future }

  return { since: new Date(timeNow).toISOString(), untilParam: plusMinute }

getCustomOncalls = (timeFrame, msg) ->
  if not msg?
    console.log('no msg sent')
    return

  timeNow = Date.now()
  timeQuery = setTimeQuery(timeFrame, timeNow)
  query = {
    limit: 50
    time_zone: 'UTC'
    "schedule_ids[]": ['PDHLWLB' , 'PGWSC3H', 'PGFERYM'],
    since: timeQuery.since
    until: timeQuery.untilParam
  }

  pagerduty.get('/oncalls', query, (err, json) ->
    if err
      msg.send(err)

    userSupports = json.oncalls.filter((oncall) -> oncall.schedule.id is 'PDHLWLB')
    escallations = json.oncalls.filter((oncall) -> oncall.schedule.id is 'PGFERYM')
    platformOncalls = json.oncalls.filter((oncall) -> oncall.schedule.id is 'PGWSC3H')

    userSupport = findOncall(userSupports, timeFrame, timeNow)
    escallation = findOncall(escallations, timeFrame, timeNow)
    platformOncall = findOncall(platformOncalls, timeFrame, timeNow)
    
    message = "#{userSupport.schedule.summary} - (#{formatTime(userSupport.start)} - #{formatTime(userSupport.end)}) - *#{userSupport.user.summary}*\n"
    message += "#{platformOncall.schedule.summary} - #{formatTime(platformOncall.start)} - #{formatTime(platformOncall.end)} - *#{platformOncall.user.summary}*\n"
    message += "#{escallation.schedule.summary} - #{formatTime(escallation.start)} - #{formatTime(escallation.end)} - *#{escallation.user.summary}*\n"

    msg.send(message)
  )
module.exports = getCustomOncalls
module.exports = { findOncall, formatTime, setTimeQuery }