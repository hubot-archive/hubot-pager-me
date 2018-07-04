pagerduty = require('../pagerduty')
async = require('async')
inspect = require('util').inspect
moment = require('moment-timezone')

pagerDutyUserId        = process.env.HUBOT_PAGERDUTY_USER_ID
pagerDutyServiceApiKey = process.env.HUBOT_PAGERDUTY_SERVICE_API_KEY

module.exports = (robot) ->
  
  # Am I on call?
  robot.respond /am i on (call|oncall|on-call)/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      userId = user.id

      renderSchedule = (s, cb) ->
        withCurrentOncallId msg, s, (oncallUserid, oncallUsername, schedule) ->
          if userId == oncallUserid
            cb null, "* Yes, you are on call for #{schedule.name} - https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}"
          else
            cb null, "* No, you are NOT on call for #{schedule.name} (but #{oncallUsername} is)- https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}"

      if !userId?
        msg.send "Couldn't figure out the pagerduty user connected to your account."
      else
        pagerduty.getSchedules (err, schedules) ->
          if err?
            robot.emit 'error', err, msg
            return

          if schedules.length > 0
            async.map schedules, renderSchedule, (err, results) ->
              if err?
                robot.emit 'error', err, msg
                return
              msg.send results.join("\n")
          else
            msg.send 'No schedules found!'

  # who is on call?
  robot.respond /who(?:’s|'s|s| is|se)? (?:on call|oncall|on-call)(?:\?)?(?: (?:for )?((["'])([^]*?)\2|(.*?))(?:\?|$))?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    scheduleName = msg.match[3] or msg.match[4]

    messages = []
    renderSchedule = (s, cb) ->
      withCurrentOncall msg, s, (username, schedule) ->
        if (username)
          messages.push("* #{username} is on call for #{schedule.name} - #{schedule.html_url}")
        else
          robot.logger.debug "No user for schedule #{schedule.name}"
        cb null

    if scheduleName?
      withScheduleMatching msg, scheduleName, (s) ->
        renderSchedule s, (err) ->
          if err?
            robot.emit 'error'
            return
          msg.send messages.join("\n")
    else
      pagerduty.getSchedules (err, schedules) ->
        if err?
          robot.emit 'error', err, msg
          return
        if schedules.length > 0
          async.map schedules, renderSchedule, (err) ->
            if err?
              robot.emit 'error', err, msg
              return
            msg.send messages.join("\n")
        else
          msg.send 'No schedules found!'

  robot.respond /(pager|major)( me)? services$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    pagerduty.get "/services", {}, (err, json) ->
      if err?
        robot.emit 'error', err, msg
        return

      buffer = ''
      services = json.services
      if services.length > 0
        for service in services
          buffer += "* #{service.id}: #{service.name} (#{service.status}) - #{service.html_url}\n"
        msg.send buffer
      else
        msg.send 'No services found!'

  robot.respond /(pager|major)( me)? maintenance (\d+) (.+)$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      requester_id = user.id
      return unless requester_id

      minutes = msg.match[3]
      service_ids = msg.match[4].split(' ')
      start_time = moment().format()
      end_time = moment().add('minutes', minutes).format()

      maintenance_window = {
        'start_time': start_time,
        'end_time': end_time,
        'service_ids': service_ids
      }
      data = { 'maintenance_window': maintenance_window, 'requester_id': requester_id }

      msg.send "Opening maintenance window for: #{service_ids}"
      pagerduty.post "/maintenance_windows", data, (err, json) ->
        if err?
          robot.emit 'error', err, msg
          return

        if json && json.maintenance_window
          msg.send "Maintenance window created! ID: #{json.maintenance_window.id} Ends: #{json.maintenance_window.end_time}"
        else
          msg.send "That didn't work. Check Hubot's logs for an error!"

  withCurrentOncall = (msg, schedule, cb) ->
    withCurrentOncallUser msg, schedule, (user, s) ->
      if (user)
        cb(user.name, s)
      else
        cb(null, s)

  withCurrentOncallId = (msg, schedule, cb) ->
    withCurrentOncallUser msg, schedule, (user, s) ->
      if (user)
        cb(user.id, user.name, s)
      else
        cb(null, null, s)

  withCurrentOncallUser = (msg, schedule, cb) ->
    oneHour = moment().add(1, 'hours').format()
    now = moment().format()

    scheduleId = schedule.id
    if (schedule instanceof Array && schedule[0])
      scheduleId = schedule[0].id
    unless scheduleId
      msg.send "Unable to retrieve the schedule. Use 'pager schedules' to list all schedules."
      return

    query = {
      since: now,
      until: oneHour,
    }
    pagerduty.get "/schedules/#{scheduleId}/users", query, (err, json) ->
      if err?
        robot.emit 'error', err, msg
        return
      if json.users and json.users.length > 0
        cb(json.users[0], schedule)
      else
        cb(null, schedule)

  SchedulesMatching = (msg, q, cb) ->
    query = {
      query: q
    }
    pagerduty.getSchedules query, (err, schedules) ->
      if err?
        robot.emit 'error', err, msg
        return

      cb(schedules)

  withScheduleMatching = (msg, q, cb) ->
    SchedulesMatching msg, q, (schedules) ->
      if schedules?.length < 1
        msg.send "I couldn't find any schedules matching #{q}"
      else
        cb(schedule) for schedule in schedules
      return

  userEmail = (user) ->
    user.pagerdutyEmail || user.email_address || user.profile?.email || process.env.HUBOT_PAGERDUTY_TEST_EMAIL

  campfireUserToPagerDutyUser = (msg, user, required, cb) ->

    if typeof required is 'function'
      cb = required
      required = true

    ## Determine the email based on the adapter type (v4.0.0+ of the Slack adapter stores it in `profile.email`)
    email = userEmail(user)
    speakerEmail = userEmail(msg.message.user)

    if not email
      if not required
        cb null
        return
      else
        possessive = if email is speakerEmail
                      "your"
                     else
                      "#{user.name}'s"
        addressee = if email is speakerEmail
                      "you"
                    else
                      "#{user.name}"

        msg.send "Sorry, I can't figure out #{possessive} email address :( Can #{addressee} tell me with `#{robot.name} pager me as you@yourdomain.com`?"
        return

    pagerduty.get "/users", {query: email}, (err, json) ->
      if err?
        robot.emit 'error', err, msg
        return

      if json.users.length isnt 1
        if json.users.length is 0 and not required
          cb null
          return
        else
          msg.send "Sorry, I expected to get 1 user back for #{email}, but got #{json.users.length} :sweat:. If your PagerDuty email is not #{email} use `/pager me as #{email}`"
          return

      cb(json.users[0])
