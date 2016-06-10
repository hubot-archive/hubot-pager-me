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
#   hubot pager schedule <schedule> <days> - show <schedule>'s shifts for the next <days> (default 30 days)
#   hubot pager my schedule <days> - show my on call shifts for the upcoming <days> in all schedules (default 30 days)
#   hubot pager me <schedule> <minutes> - take the pager for <minutes> minutes
#   hubot pager override <schedule> <start> - <end> [username] - Create an schedule override from <start> until <end>. If [username] is left off, defaults to you. start and end should date-parsable dates, like 2014-06-24T09:06:45-07:00, see http://momentjs.com/docs/#/parsing/string/ for examples.
#   hubot pager overrides <schedule> <days> - show upcoming overrides for the next x <days> (default 30 days)
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

pagerDutyUserId        = process.env.HUBOT_PAGERDUTY_USER_ID
pagerDutyServiceApiKey = process.env.HUBOT_PAGERDUTY_SERVICE_API_KEY
pagerDutyCharToSpace   = process.env.HUBOT_PAGERDUTY_CHAR_TO_SPACE

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
    msg.finish()

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

      if incidents.length > 0
        buffer = "Triggered:\n----------\n"
        for junk, incident of incidents.reverse()
          if incident.status == 'triggered'
            buffer = buffer + formatIncident(incident)
        buffer = buffer + "\nAcknowledged:\n-------------\n"
        for junk, incident of incidents.reverse()
          if incident.status == 'acknowledged'
            buffer = buffer + formatIncident(incident)
        msg.send buffer
      else
        msg.send "No open incidents"

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
      reassignmentParametersForUserOrScheduleOrEscalationPolicy msg, query, (results) ->
        if not (results.assigned_to_user or results.escalation_policy)
          msg.reply "Couldn't find a user or unique schedule or escalation policy matching #{query} :/"
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
              else
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

                  if json?.incidents.length == 1
                    msg.reply ":pager: assigned to #{results.name}!"
                  else
                    msg.reply "Problem reassigning the incident :/"
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

      buffer = ''
      if schedules.length > 0
        for schedule in schedules
          buffer += "* #{schedule.name} - https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}\n"
        msg.send buffer
      else
        msg.send 'No schedules found!'

  robot.respond /(pager|major)( me)? (schedule|overrides)( ([\w\-]+))?( ([^ ]+)\s*(\d+)?)?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    if msg.match[8]
      days = msg.match[8]
    else
      days = 30

    query = {
      since: moment().format(),
      until: moment().add(days, 'days').format(),
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
        if entries
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
        else
          msg.send "None found!"

  robot.respond /(pager|major)( me)? my schedule( ([^ ]+)\s?(\d+))?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    if msg.match[5]
      days = msg.match[5]
    else
      days = 30

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      userId = user.id

      query = {
        since: moment().format(),
        until: moment().add(days, 'days').format(),
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

        if schedules.length > 0
          renderSchedule = (schedule, cb) ->
            pagerduty.get "/schedules/#{schedule.id}/entries", query, (err, json) ->
              if err?
                cb(err)

              entries = json.entries

              if entries
                sortedEntries = entries.sort (a, b) ->
                  moment(a.start).unix() - moment(b.start).unix()

                buffer = ""
                for entry in sortedEntries
                  if userId == entry.user.id
                    startTime = moment(entry.start).tz(timezone).format()
                    endTime   = moment(entry.end).tz(timezone).format()

                    buffer += "* #{startTime} - #{endTime} #{entry.user.name} (#{schedule.name})\n"
                cb(null, buffer)

          async.map schedules, renderSchedule, (err, results) ->
            if err?
              robot.emit 'error', err, msg
              return
            msg.send results.join("")

        else
          msg.send 'No schedules found!'

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
      return unless userId

      withScheduleMatching msg, msg.match[4], (schedule) ->
        scheduleId = schedule.id
        return unless scheduleId

        if moment(msg.match[5]).isValid() && moment(msg.match[6]).isValid()
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

            if json && json.override
              start = moment(json.override.start)
              end = moment(json.override.end)
              msg.send "Override setup! #{json.override.user.name} has the pager from #{start.format()} until #{end.format()}"
            else
              msg.send "That didn't work. Check Hubot's logs for an error!"
        else
          msg.send "Please use a http://momentjs.com/ compatible date!"

  robot.respond /(pager|major)( me)? (overrides?) ([\w\-]*) (delete) (.*)$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    withScheduleMatching msg, msg.match[4], (schedule) ->
      scheduleId = schedule.id
      return unless scheduleId

      pagerduty.delete "/schedules/#{scheduleId}/overrides/#{msg.match[6]}", (err, success) ->
        if success
          msg.send ":boom:"
        else
          msg.send "Something went weird."

  robot.respond /pager( me)? (?!schedules?\b|overrides?\b|my schedule\b)(.+) (\d+)$/i, (msg) ->
    msg.finish()

    if pagerduty.missingEnvironmentForApi(msg)
      return

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->

      userId = user.id
      return unless userId

      if !msg.match[2] || msg.match[2] == 'me'
        msg.reply "Please specify a schedule with 'pager me infrastructure 60'. Use 'pager schedules' to list all schedules."
        return

      withScheduleMatching msg, msg.match[2], (matchingSchedule) ->

        return unless matchingSchedule.id

        start     = moment().format()
        minutes   = parseInt msg.match[3]
        end       = moment().add(minutes, 'minutes').format()
        override  = {
          'start':     start,
          'end':       end,
          'user_id':   userId
        }
        withCurrentOncall msg, matchingSchedule, (old_username, schedule) ->
          data = { 'override': override }
          pagerduty.post "/schedules/#{schedule.id}/overrides", data, (err, json) ->
            if err?
              robot.emit 'error', err, msg
              return

            if json.override
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
  robot.respond /who(?:’s|'s|s| is|se)? (?:on call|oncall|on-call)(?: (?:for )?(.*?)(?:\?|$))?/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    scheduleName = msg.match[1]

    messages = []
    renderSchedule = (s, cb) ->
      withCurrentOncall msg, s, (username, schedule) ->
        messages.push("* #{username} is on call for #{schedule.name} - https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}")
        cb null

    if scheduleName?
      withScheduleMatching msg, scheduleName, (s) ->
        renderSchedule s, (err, text) ->
          if err?
            robot.emit 'error'
            return
          msg.send text
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
          buffer += "* #{service.id}: #{service.name} (#{service.status}) - https://#{pagerduty.subdomain}.pagerduty.com/services/#{service.id}\n"
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

  parseIncidentNumbers = (match) ->
    match.split(/[ ,]+/).map (incidentNumber) ->
      parseInt(incidentNumber)

  campfireUserToPagerDutyUser = (msg, user, required, cb) ->

    if typeof required is 'function'
      cb = required
      required = true

    email  = user.pagerdutyEmail || user.email_address || process.env.HUBOT_PAGERDUTY_TEST_EMAIL
    speakerEmail = msg.message.user.pagerdutyEmail || msg.message.user.email_address
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
    q = transformCharToSpace q
    SchedulesMatching msg, q, (schedules) ->
      if schedules?.length < 1
        msg.send "I couldn't find any schedules matching #{q}"
      else
        cb(schedule) for schedule in schedules
      return

  reassignmentParametersForUserOrScheduleOrEscalationPolicy = (msg, string, cb) ->
    string = transformCharToSpace string
    if campfireUser = robot.brain.userForName(string)
      campfireUserToPagerDutyUser msg, campfireUser, (user) ->
        cb(assigned_to_user: user.id,  name: user.name)
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
          cb(escalation_policy: escalationPolicy.id, name: escalationPolicy.name)
        else
          SchedulesMatching msg, string, (schedule) ->
            if schedule
              withCurrentOncallUser msg, schedule, (user, schedule) ->
                cb(assigned_to_user: user.id,  name: user.name)
            else
              cb()

  withCurrentOncall = (msg, schedule, cb) ->
    withCurrentOncallUser msg, schedule, (user, s) ->
      cb(user.name, s)

  withCurrentOncallId = (msg, schedule, cb) ->
    withCurrentOncallUser msg, schedule, (user, s) ->
      cb(user.id, user.name, s)

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
      overflow: 'true'
    }
    pagerduty.get "/schedules/#{scheduleId}/entries", query, (err, json) ->
      if err?
        robot.emit 'error', err, msg
        return
      if json.entries and json.entries.length > 0
        cb(json.entries[0].user, schedule)

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

  transformCharToSpace = (string) ->
    if pagerDutyCharToSpace?
      string = string.replace(pagerDutyCharToSpace, ' ')

    return string

  updateIncidents = (msg, incidentNumbers, statusFilter, updatedStatus) ->
    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->

      requesterId = user.id
      return unless requesterId

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

            if json?.incidents
              buffer = "Incident"
              buffer += "s" if json.incidents.length > 1
              buffer += " "
              buffer += (incident.incident_number for incident in json.incidents).join(", ")
              buffer += " #{updatedStatus}"
              msg.reply buffer
            else
              msg.reply "Problem updating incidents #{incidentNumbers.join(',')}"


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
