pagerduty = require('../pagerduty')

getCustomOncalls = (timeFrame, msg) ->
  if not msg?
    console.log('no msg sent')
    return

  timeNow = Date.now()
  past = new Date(timeNow - (72 * 3600000)).toISOString()
  future = new Date(timeNow + (72 * 3600000)).toISOString()
  plusMinute = new Date(timeNow + 60000).toISOString()
  since = null
  untilParam = null

  # , 'PGWSC3H', 'PGFERYM'
  if timeFrame is 'now'
    since = new Date(timeNow).toISOString()
    untilParam = plusMinute
    msg.send('it\'s now or never')

  if timeFrame is 'was'
    since = past
    untilParam = new Date(timeNow).toISOString()
    msg.send('let the past rest in peace')

  if timeFrame is 'next'
    since = new Date(timeNow).toISOString()
    untilParam = future
    msg.send('what\'s next?')

  query = {
    limit: 50
    time_zone: 'UTC'
    "schedule_ids[]": ['PDHLWLB' , 'PGWSC3H', 'PGFERYM'],
    since: since
    until: untilParam
  }

  pagerduty.get('/oncalls', query, (err, json) ->
    if err
      msg.send(err)

    userSupports = json.oncalls.filter((oncall) -> oncall.schedule.id is 'PDHLWLB')
    escallations = json.oncalls.filter((oncall) -> oncall.schedule.id is 'PGFERYM')
    platformOncalls = json.oncalls.filter((oncall) -> oncall.schedule.id is 'PGWSC3H')

    findOncall = (oncalls, timeFrame) ->
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
    
    formatTime = (date) ->
      dateTime = new Date(date).toString()
      return "#{dateTime.substring(0, 10)} #{dateTime.substring(16, 21)} pm"

    userSupport = findOncall(userSupports, timeFrame)
    escallation = findOncall(escallations, timeFrame)
    platformOncall = findOncall(platformOncalls, timeFrame)
    
    message = "#{userSupport.schedule.summary} - (#{formatTime(userSupport.start)} - #{formatTime(userSupport.end)}) - *#{userSupport.user.summary}*\n"
    message += "#{platformOncall.schedule.summary} - #{formatTime(platformOncall.start)} - #{formatTime(platformOncall.end)} - *#{platformOncall.user.summary}*\n"
    message += "#{escallation.schedule.summary} - #{formatTime(escallation.start)} - #{formatTime(escallation.end)} - *#{escallation.user.summary}*\n"

    msg.send(message)
  )
module.exports = getCustomOncalls