# Description:
#   Interact with PagerDuty services, schedules, and incidents with Hubot.
#
# Commands:
#   hubot who's on call - return a list of services and who is on call for them
#   hubot who's on call for <schedule> - return the username of who's on call for any schedule matching <search>
#
# Authors:
#   Jesse Newland, Josh Nicols, Jacob Bednarz, Chris Lundquist, Chris Streeter, Joseph Pierri, Greg Hoin, Michael Warkentin

inspect = require('util').inspect

moment = require('moment-timezone')
async = require('async')

pagerDutyApiKey        = process.env.HUBOT_PAGERDUTY_API_KEY
pagerDutySubdomain     = process.env.HUBOT_PAGERDUTY_SUBDOMAIN
pagerDutyBaseUrl       = "https://#{pagerDutySubdomain}.pagerduty.com/api/v1"

module.exports = (robot) ->
  # @optibot whos on call for Pagerduty Schedule Name? (can be spread out)
  robot.respond /who(?:’s|'s|s| is|se)? (?:on call|oncall|on-call)(?: (?:for )?(.*?)(?:\?|$))?/i, (msg) ->
    scheduleName = msg.match[1]
    getScheduleFromScheduleName(msg, scheduleName)

  # whos the CFO? (one abbreviation, no spaces). Skips @optibot's handle being needed and allows for abbreviations to be programmed
  robot.hear /who(?:’s|'s|s| is|se)? (?:(?:the )?([0-9A-Za-z]*))/i, (msg) ->
    scheduleAbbreviation = msg.match[1]
    switch scheduleAbbreviation
      when "Deploy Captain" then getScheduleFromScheduleName(msg, 'Build & Deploy Captain')
      when "CFO" then getScheduleFromScheduleName(msg, 'Chief Frontend Officer')
      else return

  getScheduleFromScheduleName = (msg, scheduleName) ->
    getDisplayScheduleString = (s, cb) ->
      withCurrentOncall msg, s, (err, username, schedule) ->
        if !err && username && schedule
          cb(null, "* #{username} is on call for #{schedule.name} - https://#{pagerDutySubdomain}.pagerduty.com/schedules##{schedule.id}\n")
        else
          cb err

    pagerDutyGet msg, "/schedules", { query: scheduleName }, (err, json) ->
      schedules = json.schedules
      if schedules.length > 0
        async.map(schedules, getDisplayScheduleString, (err, res) ->
          msg.send '```\n' + res.join('') + '```\n'
        )
      else
        msg.send 'No schedules found!'

  missingEnvironmentForApi = (msg) ->
    missingAnything = false
    unless pagerDutySubdomain?
      msg.send "PagerDuty Subdomain is missing:  Ensure that HUBOT_PAGERDUTY_SUBDOMAIN is set."
      missingAnything |= true
    unless pagerDutyApiKey?
      msg.send "PagerDuty API Key is missing:  Ensure that HUBOT_PAGERDUTY_API_KEY is set."
      missingAnything |= true
    missingAnything


  pagerDutyGet = (msg, url, query, cb) ->
    if missingEnvironmentForApi(msg)
      return

    if pagerDutyServices? && url.match /\/incidents/
      query['service'] = pagerDutyServices

    auth = "Token token=#{pagerDutyApiKey}"
    msg.http(pagerDutyBaseUrl + url)
      .query(query)
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        if err?
          return robot.emit 'error', err, msg
        json_body = null
        switch res.statusCode
          when 200 then json_body = JSON.parse(body)
          else
            console.log res.statusCode
            console.log body
            json_body = null
        cb err, json_body

  withCurrentOncall = (msg, schedule, cb) ->
    withCurrentOncallUser msg, schedule, (err, user, s) ->
      if err
        cb err
      else
        cb err, user, s

  withCurrentOncallUser = (msg, schedule, cb) ->
    oneHour = moment().add(1, 'hours').format()
    now = moment().format()

    query = {
      since: now,
      until: oneHour,
      overflow: 'true'
    }
    pagerDutyGet msg, "/schedules/#{schedule.id}/entries", query, (err, json) ->
      user = if json.entries[0] && json.entries[0].user.name then json.entries[0].user.name else 'No one'
      if !err
        cb(null, user, schedule)
      else
        cb err
