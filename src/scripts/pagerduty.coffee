# Description:
#   Interact with PagerDuty services, schedules, and incidents with Hubot.
#
# Commands:
#   hubot pager me as <email> - remember your pager email is <email>
#   hubot pager forget me - forget your pager email
#   hubot Am I on call - return if I'm currently on call or not
#   hubot who's on call - return a list of services and who is on call for them
#   hubot who's on call for <schedule> - return the username of who's on call for any schedule matching <search>
#   hubot pager trigger <user> <msg> - create a new incident with <msg> and assign it to <user>
#   hubot pager trigger <schedule> <msg> - create a new incident with <msg> and assign it the user currently on call for <schedule>
#   hubot pager incidents - return the current incidents
#   hubot pager sup - return the current incidents
#   hubot pager incident <incident> - return the incident NNN
#   hubot pager note <incident> <content> - add note to incident #<incident> with <content>
#   hubot pager notes <incident> - show notes for incident #<incident>
#   hubot pager problems - return all open incidents
#   hubot pager ack <incident> - ack incident #<incident>
#   hubot pager ack - ack triggered incidents assigned to you
#   hubot pager ack! - ack all triggered incidents, not just yours
#   hubot pager ack <incident1> <incident2> ... <incidentN> - ack all specified incidents
#   hubot pager resolve <incident> - resolve incident #<incident>
#   hubot pager resolve <incident1> <incident2> ... <incidentN> - resolve all specified incidents
#   hubot pager resolve - resolve acknowledged incidents assigned to you
#   hubot pager resolve! - resolve all acknowledged, not just yours
#   hubot pager schedules - list schedules
#   hubot pager schedules <search> - list schedules matching <search>
#   hubot pager schedule <schedule> - show <schedule>'s shifts for the upcoming month
#   hubot pager my schedule - show my on call shifts for the upcoming month in all schedules
#   hubot pager me <schedule> <minutes> - take the pager for <minutes> minutes
#   hubot pager override <schedule> <start> - <end> [username] - Create an schedule override from <start> until <end>. If [username] is left off, defaults to you. start and end should date-parsable dates, like 2014-06-24T09:06:45-07:00, see http://momentjs.com/docs/#/parsing/string/ for examples.
#   hubot pager overrides <schedule> - show upcoming overrides for the next month
#   hubot pager override <schedule> delete <id> - delete an override by its ID
#   hubot pager services - list services
#   hubot pager maintenance <minutes> <service_id1> <service_id2> ... <service_idN> - schedule a maintenance window for <minutes> for specified services
#
# Authors:
#   Jesse Newland, Josh Nicols, Jacob Bednarz, Chris Lundquist, Chris Streeter, Joseph Pierri, Greg Hoin, Michael Warkentin

pagerduty = require('../pagerduty')
async = require('async')
inspect = require('util').inspect
moment = require('moment-timezone')
Scrolls = require('../../../../lib/scrolls').context({script: 'pagerduty'})

pagerDutyUserId        = process.env.HUBOT_PAGERDUTY_USER_ID
pagerDutyServiceApiKey = process.env.HUBOT_PAGERDUTY_SERVICE_API_KEY

module.exports = (robot) ->

  robot.respond /pager( me)?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      emailNote = if msg.message.user.pagerdutyEmail
                    "You've told me your PagerDuty email is #{msg.message.user.pagerdutyEmail}"
                  else if msg.message.user.email_address
                    "I'm assuming your PagerDuty email is #{msg.message.user.email_address}. Change it with `#{robot.name} pager me as you@yourdomain.com`"
      if user
        msg.send "I found your PagerDuty user https://#{pagerduty.subdomain}.pagerduty.com#{user.user_url}, #{emailNote}"
      else
        msg.send "I couldn't find your user :( #{emailNote}"

    cmds = robot.helpCommands()
    cmds = (cmd for cmd in cmds when cmd.match(/hubot (pager |who's on call)/))
    msg.send cmds.join("\n")

  robot.respond /pager(?: me)? as (.*)$/i, (msg) ->
    email = msg.match[1]
    msg.message.user.pagerdutyEmail = email
    msg.send "Okay, I'll remember your PagerDuty email is #{email}"

  robot.respond /pager forget me$/i, (msg) ->
    msg.message.user.pagerdutyEmail = undefined
    msg.send "Okay, I've forgotten your PagerDuty email"

  robot.respond /(pager|major)( me)? incident (.*)$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    pagerduty.getIncident msg.match[3], (err, incident) ->
      if err?
        robot.emit 'error', err, msg
        return

      msg.send formatIncident(incident)

  robot.respond /(pager|major)( me)? (inc|incidents|sup|problems)$/i, (msg) ->
    pagerduty.getIncidents "triggered,acknowledged", (err, incidents) ->
      if err?
        robot.emit 'error', err, msg
        return

      if incidents.length == 0
        msg.send "No open incidents"
        return

      buffer = "Triggered:\n----------\n"
      for junk, incident of incidents.reverse()
        if incident.status == 'triggered'
          buffer = buffer + formatIncident(incident)
      buffer = buffer + "\nAcknowledged:\n-------------\n"
      for junk, incident of incidents.reverse()
        if incident.status == 'acknowledged'
          buffer = buffer + formatIncident(incident)
      msg.send buffer

  robot.respond /(pager|major)( me)? (?:trigger|page) ([\w\-]+)$/i, (msg) ->
    msg.reply "Please include a user or schedule to page, like 'hubot pager infrastructure everything is on fire'."

  robot.respond /(pager|major)( me)? (?:trigger|page) ([\w\-]+) (.+)$/i, (msg) ->
    msg.finish()

    if pagerduty.missingEnvironmentForApi(msg)
      return

    fromUserName   = msg.message.user.name
    query          = msg.match[3]
    reason         = msg.match[4]
    description    = "#{reason} - @#{fromUserName}"

    # Figure out who we are
    campfireUserToPagerDutyUser msg, msg.message.user, false, (triggerdByPagerDutyUser) ->
      triggerdByPagerDutyUserId = if triggerdByPagerDutyUser?
                                    triggerdByPagerDutyUser.id
                                  else if pagerDutyUserId
                                    pagerDutyUserId
      unless triggerdByPagerDutyUserId
        msg.send "Sorry, I can't figure your PagerDuty account, and I don't have my own :( Can you tell me your PagerDuty email with `#{robot.name} pager me as you@yourdomain.com` or make sure you've set the HUBOT_PAGERDUTY_USER_ID environment variable?"
        return

      # Figure out what we're trying to page
      reassignmentParametersForUserOrScheduleOrEscalationPolicy msg, query, (err, results) ->
        if err?
          msg.reply err.message
          return

        pagerDutyIntegrationAPI msg, "trigger", description, (json) ->
          query =
            incident_key: json.incident_key

          msg.reply ":pager: triggered! now assigning it to the right user..."

          setTimeout () ->
            pagerduty.get "/incidents", query, (err, json) ->
              if err?
                robot.emit 'error', err, msg
                return

              if json?.incidents.length == 0
                msg.reply "Couldn't find the incident we just created to reassign. Please try again :/"
                return

              data = {
                requester_id: triggerdByPagerDutyUserId,
                incidents: json.incidents.map (incident) ->
                  {
                    id:                incident.id
                    assigned_to_user:  results.assigned_to_user
                    escalation_policy: results.escalation_policy
                  }
              }

              pagerduty.put "/incidents", data , (err, json) ->
                if err?
                  robot.emit 'error', err, msg
                  return

                if json?.incidents.length != 1
                  msg.reply "Problem reassigning the incident :/"
                  return

                msg.reply ":pager: assigned to #{results.name}!"
          , 5000

  robot.respond /(?:pager|major)(?: me)? ack(?:nowledge)? (.+)$/i, (msg) ->
    msg.finish()
    if pagerduty.missingEnvironmentForApi(msg)
      return

    incidentNumbers = parseIncidentNumbers(msg.match[1])

    # only acknowledge triggered things, since it doesn't make sense to re-acknowledge if it's already in re-acknowledge
    # if it ever doesn't need acknowledge again, it means it's timed out and has become 'triggered' again anyways
    updateIncidents(msg, incidentNumbers, 'triggered,acknowledged', 'acknowledged')

  robot.respond /(pager|major)( me)? ack(nowledge)?(!)?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    force = msg.match[4]?

    pagerduty.getIncidents 'triggered,acknowledged', (err, incidents) ->
      if err?
        robot.emit 'error', err, msg
        return

      email  = msg.message.user.pagerdutyEmail || msg.message.user.email_address
      filteredIncidents = if force
                            incidents # don't filter at all
                          else
                            incidentsForEmail(incidents, email) # filter by email

      if filteredIncidents.length is 0
        # nothing assigned to the user, but there were others
        if incidents.length > 0 and not force
          msg.send "Nothing assigned to you to acknowledge. Acknowledge someone else's incident with `hubot pager ack <nnn>`"
        else
          msg.send "Nothing to acknowledge"
        return

      incidentNumbers = (incident.incident_number for incident in filteredIncidents)

      # only acknowledge triggered things
      updateIncidents(msg, incidentNumbers, 'triggered,acknowledged', 'acknowledged')

  robot.respond /(?:pager|major)(?: me)? res(?:olve)?(?:d)? (.+)$/i, (msg) ->
    msg.finish()

    if pagerduty.missingEnvironmentForApi(msg)
      return

    incidentNumbers = parseIncidentNumbers(msg.match[1])

    # allow resolving of triggered and acknowedlge, since being explicit
    updateIncidents(msg, incidentNumbers, 'triggered,acknowledged', 'resolved')

  robot.respond /(pager|major)( me)? res(olve)?(d)?(!)?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    force = msg.match[5]?
    pagerduty.getIncidents "acknowledged", (err, incidents) ->
      if err?
        robot.emit 'error', err, msg
        return

      email  = msg.message.user.pagerdutyEmail || msg.message.user.email_address
      filteredIncidents = if force
                            incidents # don't filter at all
                          else
                            incidentsForEmail(incidents, email) # filter by email
      if filteredIncidents.length is 0
        # nothing assigned to the user, but there were others
        if incidents.length > 0 and not force
          msg.send "Nothing assigned to you to resolve. Resolve someone else's incident with `hubot pager ack <nnn>`"
        else
          msg.send "Nothing to resolve"
        return

      incidentNumbers = (incident.incident_number for incident in filteredIncidents)

      # only resolve things that are acknowledged
      updateIncidents(msg, incidentNumbers, 'acknowledged', 'resolved')

  robot.respond /(pager|major)( me)? notes (.+)$/i, (msg) ->
    msg.finish()

    if pagerduty.missingEnvironmentForApi(msg)
      return

    incidentId = msg.match[3]
    pagerduty.get "/incidents/#{incidentId}/notes", {}, (err, json) ->
      if err?
        robot.emit 'error', err, msg
        return

      buffer = ""
      for note in json.notes
        buffer += "#{note.created_at} #{note.user.name}: #{note.content}\n"
      msg.send buffer

  robot.respond /(pager|major)( me)? note ([\d\w]+) (.+)$/i, (msg) ->
    msg.finish()

    if pagerduty.missingEnvironmentForApi(msg)
      return

    incidentId = msg.match[3]
    content = msg.match[4]

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      userId = user.id
      return unless userId

      data =
        note:
          content: content
        requester_id: userId

      pagerduty.post "/incidents/#{incidentId}/notes", data, (err, json) ->
        if err?
          robot.emit 'error', err, msg
          return

        if json && json.note
          msg.send "Got it! Note created: #{json.note.content}"
        else
          msg.send "Sorry, I couldn't do it :("

  robot.respond /(pager|major)( me)? schedules( (.+))?$/i, (msg) ->
    query = {}
    if msg.match[4]
      query['query'] = msg.match[4]

    if pagerduty.missingEnvironmentForApi(msg)
      return

    pagerduty.getSchedules query, (err, schedules) ->
      if err?
        robot.emit 'error', err, msg
        return

      if schedules.length == 0
        msg.send 'No schedules found!'
        return

      renderSchedule = (schedule, cb) ->
        cb(null, "* #{schedule.name} - https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}")

      async.map schedules, renderSchedule, (err, results) ->
        if err?
          robot.emit 'error', err, msg
          return
        msg.send results.join("\n")

  robot.respond /(pager|major)( me)? (schedule|overrides)( ([\w\-]+))?( ([^ ]+))?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    query = {
      since: moment().format(),
      until: moment().add(30, 'days').format(),
      overflow: 'true'
    }

    thing = 'entries'
    if msg.match[3] && msg.match[3].match /overrides/
      thing = 'overrides'
      query['editable'] = 'true'

    if !msg.match[5]
      msg.reply "Please specify a schedule with 'pager #{msg.match[3]} <name>.'' Use 'pager schedules' to list all schedules."
      return
    if msg.match[7]
      timezone = msg.match[7]
    else
      timezone = 'UTC'

    withScheduleMatching msg, msg.match[5], (schedule) ->
      scheduleId = schedule.id
      return unless scheduleId

      pagerduty.get "/schedules/#{scheduleId}/#{thing}", query, (err, json) ->
        if err?
          robot.emit 'error', err, msg
          return

        entries = json.entries || json.overrides
        unless entries
          msg.send "None found!"
          return

        sortedEntries = entries.sort (a, b) ->
          moment(a.start).unix() - moment(b.start).unix()

        buffer = ""
        for entry in sortedEntries
          startTime = moment(entry.start).tz(timezone).format()
          endTime   = moment(entry.end).tz(timezone).format()
          if entry.id
            buffer += "* (#{entry.id}) #{startTime} - #{endTime} #{entry.user.name}\n"
          else
            buffer += "* #{startTime} - #{endTime} #{entry.user.name}\n"
        if buffer == ""
          msg.send "None found!"
        else
          msg.send buffer

  robot.respond /(pager|major)( me)? my schedule( ([^ ]+))?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      userId = user.id

      query = {
        since: moment().format(),
        until: moment().add(30, 'days').format(),
        overflow: 'true'
      }

      if msg.match[4]
        timezone = msg.match[4]
      else
        timezone = 'UTC'

      pagerduty.getSchedules (err, schedules) ->
        if err?
          robot.emit 'error', err, msg
          return

        if schedules.length == 0
          msg.send 'No schedules found!'
          return

        renderSchedule = (schedule, cb) ->
          pagerduty.get "/schedules/#{schedule.id}/entries", query, (err, json) ->
            if err?
              cb(err)
              return

            buffer = ""

            entries = json.entries
            if entries
              sortedEntries = entries.sort (a, b) ->
                moment(a.start).unix() - moment(b.start).unix()

              for entry in sortedEntries
                if userId == entry.user.id
                  startTime = moment(entry.start).tz(timezone).format()
                  endTime   = moment(entry.end).tz(timezone).format()

                  buffer += "* #{startTime} - #{endTime} #{entry.user.name} (#{schedule.name})"
            else
              buffer = "couldn't get entries for #{schedule.name}"

            cb(null, buffer)

        async.map schedules, renderSchedule, (err, results) ->
          if err?
            robot.emit 'error', err, msg
            return
          msg.send results.join("\n")

  robot.respond /(pager|major)( me)? (override) ([\w\-]+) ([\w\-:\+]+) - ([\w\-:\+]+)( (.*))?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    if msg.match[8]
      overrideUser = robot.brain.userForName(msg.match[8])

      unless overrideUser
        msg.send "Sorry, I don't seem to know who that is. Are you sure they are in chat?"
        return
    else
      overrideUser = msg.message.user

    campfireUserToPagerDutyUser msg, overrideUser, (user) ->
      userId = user.id
      unless userId
        return

      withScheduleMatching msg, msg.match[4], (schedule) ->
        scheduleId = schedule.id
        unless scheduleId
          return

        unless moment(msg.match[5]).isValid() && moment(msg.match[6]).isValid()
          msg.send "Please use a http://momentjs.com/ compatible date!"
          return

        start_time = moment(msg.match[5]).format()
        end_time = moment(msg.match[6]).format()

        override  = {
          'start':     start_time,
          'end':       end_time,
          'user_id':   userId
        }
        data = { 'override': override }
        pagerduty.post "/schedules/#{scheduleId}/overrides", data, (err, json) ->
          if err?
            robot.emit 'error', err, msg
            return

          unless json && json.override
            msg.send "That didn't work. Check Hubot's logs for an error!"
            return

          start = moment(json.override.start)
          end = moment(json.override.end)
          msg.send "Override setup! #{json.override.user.name} has the pager from #{start.format()} until #{end.format()}"

  robot.respond /(pager|major)( me)? (overrides?) ([\w\-]*) (delete) (.*)$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    withScheduleMatching msg, msg.match[4], (schedule) ->
      scheduleId = schedule.id
      unless scheduleId
        return

      pagerduty.delete "/schedules/#{scheduleId}/overrides/#{msg.match[6]}", (err, success) ->
        unless success
          msg.send "Something went weird."
          return

        msg.send ":boom:"

  robot.respond /pager( me)? (.+) (\d+)$/i, (msg) ->
    msg.finish()

    if pagerduty.missingEnvironmentForApi(msg)
      return

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->

      userId = user.id
      unless userId
        return

      if !msg.match[2] || msg.match[2] == 'me'
        msg.reply "Please specify a schedule with 'pager me infrastructure 60'. Use 'pager schedules' to list all schedules."
        return

      withScheduleMatching msg, msg.match[2], (matchingSchedule) ->
        unless matchingSchedule.id
          return

        start     = moment().format()
        minutes   = parseInt msg.match[3]
        end       = moment().add(minutes, 'minutes').format()
        override  = {
          'start':     start,
          'end':       end,
          'user_id':   userId
        }
        withCurrentOncall msg, matchingSchedule, (err, old_username, schedule) ->
          if err?
            robot.emit 'error', err, msg
            return

          data = { 'override': override }
          pagerduty.post "/schedules/#{schedule.id}/overrides", data, (err, json) ->
            if err?
              robot.emit 'error', err, msg
              return

            unless json.override
              msg.send "Something went weird."
              return

            start = moment(json.override.start)
            end = moment(json.override.end)
            msg.send "Rejoice, #{old_username}! #{json.override.user.name} has the pager on #{schedule.name} until #{end.format()}"

  # Am I on call?
  robot.respond /am i on (call|oncall|on-call)/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      userId = user.id

      renderSchedule = (s, cb) ->
        withCurrentOncallId msg, s, (err, oncallUserid, oncallUsername, schedule) ->
          if err?
            cb(err)
            return

          if userId == oncallUserid
            cb(null, "* Yes, you are on call for #{schedule.name} - https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}")
          else
            cb(null, "* No, you are NOT on call for #{schedule.name} (but #{oncallUsername} is)- https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}")

      unless userId?
        msg.send "Couldn't figure out the pagerduty user connected to your account."
        return

      pagerduty.getSchedules (err, schedules) ->
        if err?
          robot.emit 'error', err, msg
          return

        if schedules.length == 0
          msg.send 'No schedules found!'
          return

        async.map schedules, renderSchedule, (err, results) ->
          if err?
            robot.emit 'error', err, msg
            return
          msg.send results.join("\n")

  # who is on call?
  robot.respond /who(’s|'s|s| is|se)? (on call|oncall|on-call)( (?:for )?(.+))?/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    scheduleName = msg.match[4]

    renderSchedule = (s, cb) ->
      withCurrentOncall msg, s, (err, username, schedule) ->
        if err?
          cb(err)
          return

        Scrolls.log("info", {at: 'who-is-on-call/renderSchedule', schedule: schedule.name, username: username})
        if !pagerEnabledForScheduleOrEscalation(schedule) || username == "hubot"
          cb(null, undefined)
          return

        cb(null, "* #{schedule.name}'s oncall is #{username} - https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}")

    if scheduleName?
      withScheduleMatching msg, scheduleName, (s) ->
        renderSchedule s, (err, text) ->
          if err?
            robot.emit 'error'
            return
          msg.send text
      return

    pagerduty.getSchedules (err, schedules) ->
      if err?
        robot.emit 'error', err, msg
        return

      if schedules.length == 0
        msg.send 'No schedules found!'
        return

      async.map schedules, renderSchedule, (err, results) ->
        if err?
          Scrolls.log("error", {at: 'who-is-on-call/map-schedules/error', error: err})
          robot.emit 'error', err, msg
          return

        results = (result for result in results when result?)
        Scrolls.log("info", {at: 'who-is-on-call/map-schedules'})
        msg.send results.join("\n")

  robot.respond /(pager|major)( me)? services$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    pagerduty.get "/services", {}, (err, json) ->
      if err?
        robot.emit 'error', err, msg
        return

      if services.length == 0
        msg.send 'No services found!'
        return

      renderService = (service, cb) ->
        cb(null, "* #{service.id}: #{service.name} (#{service.status}) - https://#{pagerduty.subdomain}.pagerduty.com/services/#{service.id}")

      async.map json.services, renderService, (err, results) ->
        if err?
          robot.emit 'error', err, msg
          return
        msg.send results.join("\n")

  robot.respond /(pager|major)( me)? maintenance (\d+) (.+)$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      requester_id = user.id
      unless requester_id
        return

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

        unless json && json.maintenance_window
          msg.send "That didn't work. Check Hubot's logs for an error!"
          return

        msg.send "Maintenance window created! ID: #{json.maintenance_window.id} Ends: #{json.maintenance_window.end_time}"

  # Determine whether a schedule's participants are available to be paged.
  #
  # s :: Object
  #      Decoded JSON from the Pagerduty Schedules or Escalation API.
  #
  # Returns a Boolean instance.
  pagerEnabledForScheduleOrEscalation = (s) ->
    description = s.description or ""
    return description.indexOf('#nopage') == -1

  parseIncidentNumbers = (match) ->
    match.split(/[ ,]+/).map (incidentNumber) ->
      parseInt(incidentNumber)

  campfireUserToPagerDutyUser = (msg, user, required, cb) ->
    if typeof required is 'function'
      cb = required
      required = true

    email  = user.pagerdutyEmail || user.email_address || process.env.HUBOT_PAGERDUTY_TEST_EMAIL || user.profile?.email
    speakerEmail = msg.message.user.pagerdutyEmail || msg.message.user.email_address || msg.message.user.profile?.email
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
          msg.send "Sorry, I expected to get 1 user back for #{email}, but got #{json.users.length} :sweat:. Can you make sure that is actually a real user on PagerDuty?"
          return

      cb(json.users[0])

  oneScheduleMatching = (msg, q, cb) ->
    query = {
      query: q
    }
    pagerduty.getSchedules query, (err, schedules) ->
      if err?
        robot.emit 'error', err, msg
        return

      # Single result returned
      if schedules?.length == 1
        schedule = schedules[0]

      # Multiple results returned and one is exact (case-insensitive)
      if schedules?.length > 1
        matchingExactly = schedules.filter (s) ->
          s.name.toLowerCase() == q.toLowerCase()
        if matchingExactly.length == 1
          schedule = matchingExactly[0]
      cb(schedule)

  withScheduleMatching = (msg, q, cb) ->
    oneScheduleMatching msg, q, (schedule) ->
      if schedule
        cb(schedule)
      else
        # maybe look for a specific name match here?
        msg.send "I couldn't determine exactly which schedule you meant by #{q}. Can you be more specific?"
        return

  reassignmentParametersForUserOrScheduleOrEscalationPolicy = (msg, string, cb) ->
    if campfireUser = robot.brain.userForName(string)
      campfireUserToPagerDutyUser msg, campfireUser, (user) ->
        cb(null, { assigned_to_user: user.id, name: user.name })
    else
      pagerduty.get "/escalation_policies", query: string, (err, json) ->
        if err?
          robot.emit 'error', err, msg
          return

        escalationPolicy = null
        if json?.escalation_policies?.length == 1
          escalationPolicy = json.escalation_policies[0]
        # Multiple results returned and one is exact (case-insensitive)
        else if json?.escalation_policies?.length > 1
          matchingExactly = json.escalation_policies.filter (es) ->
            es.name.toLowerCase() == string.toLowerCase()
          if matchingExactly.length == 1
            escalationPolicy = matchingExactly[0]

        if escalationPolicy?
          unless pagerEnabledForScheduleOrEscalation(escalationPolicy)
            error = new Error("Found the #{escalationPolicy.name} escalation policy but it is marked #nopage, see /who's on call for schedules you can page.")
            cb(error, null)
            return

          cb(null, { escalation_policy: escalationPolicy.id, name: escalationPolicy.name })
          return

        oneScheduleMatching msg, string, (schedule) ->
          if schedule
            unless pagerEnabledForScheduleOrEscalation(schedule)
              error = new Error("Found the #{schedule.name} schedule but it is marked #nopage, see /who's on call for schedules you can page.")
              cb(error, null)
              return

            withCurrentOncallUser msg, schedule, (err, user, schedule) ->
              if err?
                cb(err, null)
                return

              cb(null, { assigned_to_user: user.id,  name: user.name })

            return

          error = new Error("Couldn't find a user, unique schedule or escalation policy matching #{string} to page, see /who's on call for schedules you can page.")
          cb(error, null)

  withCurrentOncall = (msg, schedule, cb) ->
    withCurrentOncallUser msg, schedule, (err, user, s) ->
      if err?
        cb(err, null, null)
        return

      cb(null, user.name, s)

  withCurrentOncallId = (msg, schedule, cb) ->
    withCurrentOncallUser msg, schedule, (err, user, s) ->
      if err?
        cb(err, null, null, null)
        return

      cb(null, user.id, user.name, s)

  withCurrentOncallUser = (msg, schedule, cb) ->
    oneHour = moment().add(1, 'hours').format()
    now = moment().format()

    query = {
      since: now,
      until: oneHour,
      overflow: 'true'
    }
    pagerduty.get "/schedules/#{schedule.id}/entries", query, (err, json) ->
      if err?
        cb(err, null, null)
        return

      unless json.entries and json.entries.length > 0
        cb(null, "nobody", schedule)
        return

      cb(null, json.entries[0].user, schedule)

  pagerDutyIntegrationAPI = (msg, cmd, description, cb) ->
    unless pagerDutyServiceApiKey?
      msg.send "PagerDuty API service key is missing."
      msg.send "Ensure that HUBOT_PAGERDUTY_SERVICE_API_KEY is set."
      return

    data = null
    switch cmd
      when "trigger"
        data = JSON.stringify { service_key: pagerDutyServiceApiKey, event_type: "trigger", description: description}
        pagerDutyIntegrationPost msg, data, (json) ->
          cb(json)

  formatIncident = (inc) ->
     # { pd_nagios_object: 'service',
     #   HOSTNAME: 'fs1a',
     #   SERVICEDESC: 'snapshot_repositories',
     #   SERVICESTATE: 'CRITICAL',
     #   HOSTSTATE: 'UP' },

    summary = if inc.trigger_summary_data
              if inc.trigger_summary_data.pd_nagios_object == 'service'
                 "#{inc.trigger_summary_data.HOSTNAME}/#{inc.trigger_summary_data.SERVICEDESC}"
              else if inc.trigger_summary_data.pd_nagios_object == 'host'
                 "#{inc.trigger_summary_data.HOSTNAME}/#{inc.trigger_summary_data.HOSTSTATE}"
              # email services
              else if inc.trigger_summary_data.subject
                inc.trigger_summary_data.subject
              else if inc.trigger_summary_data.description
                inc.trigger_summary_data.description
              else
                ""
            else
              ""
    assigned_to = if inc.assigned_to
                    names = inc.assigned_to.map (assignment) -> assignment.object.name
                    "- assigned to #{names.join(', ')}"
                  else
                    ""


    "#{inc.incident_number}: #{inc.created_on} #{summary} #{assigned_to}\n"

  updateIncidents = (msg, incidentNumbers, statusFilter, updatedStatus) ->
    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      requesterId = user.id
      unless requesterId
        return

      pagerduty.getIncidents statusFilter, (err, incidents) ->
        if err?
          robot.emit 'error', err, msg
          return

        foundIncidents = []
        for incident in incidents
          # FIXME this isn't working very consistently
          if incidentNumbers.indexOf(incident.incident_number) > -1
            foundIncidents.push(incident)

        if foundIncidents.length == 0
          msg.reply "Couldn't find incident(s) #{incidentNumbers.join(', ')}. Use `#{robot.name} pager incidents` for listing."
        else
          # loljson
          data = {
            requester_id: requesterId
            incidents: foundIncidents.map (incident) ->
              {
                'id':     incident.id,
                'status': updatedStatus
              }
          }

          pagerduty.put "/incidents", data , (err, json) ->
            if err?
              robot.emit 'error', err, msg
              return

            unless json?.incidents
              msg.reply "Problem updating incidents #{incidentNumbers.join(',')}"
              return

            buffer = "Incident"
            buffer += "s" if json.incidents.length > 1
            buffer += " "
            buffer += (incident.incident_number for incident in json.incidents).join(", ")
            buffer += " #{updatedStatus}"
            msg.reply buffer

  pagerDutyIntegrationPost = (msg, json, cb) ->
    msg.http('https://events.pagerduty.com/generic/2010-04-15/create_event.json')
      .header("content-type","application/json")
      .header("content-length", json.length)
      .post(json) (err, res, body) ->
        switch res.statusCode
          when 200
            json = JSON.parse(body)
            cb(json)
          else
            console.log res.statusCode
            console.log body

  incidentsForEmail = (incidents, userEmail) ->
    incidents.filter (incident) ->
      incident.assigned_to.some (assignment) ->
        assignment.object.email is userEmail
