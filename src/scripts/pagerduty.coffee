# Description:
#   Interact with PagerDuty services, schedules, and incidents with Hubot.  Schedules with "hidden" in the name will be ignored.
#
# Commands:
#   hubot pager me as <email> - remember your pager email is <email>
#   hubot pager forget me - forget your pager email
#   hubot Am I on call - return if I'm currently on call or not
#   hubot who's on call - return a list of services and who is on call for them
#   hubot who's on call for <schedule> - return the username of who's on call for any schedule matching <search>
#   hubot pager trigger <user> <severity> <msg> - create a new incident with <msg> and assign it to <user>. Severity must be one of: critical, error, warning or info.
#   hubot pager trigger <schedule> <severity> <msg> - create a new incident with <msg> and assign it the user currently on call for <schedule>. Severity must be one of: critical, error, warning or info.
#   hubot pager incidents - return the current incidents
#   hubot pager sup - return the current incidents
#   hubot pager sup --canary - return the current incidents, including Nines' canary incidents
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
request = require 'request'
Scrolls = require('../../../../lib/scrolls').context({script: 'pagerduty'})

pagerDutyUserEmail     = process.env.HUBOT_PAGERDUTY_USERNAME
pagerDutyServiceApiKey = process.env.HUBOT_PAGERDUTY_SERVICE_API_KEY
pagerDutyEventsAPIURL  = 'https://events.pagerduty.com/v2/enqueue'

module.exports = (robot) ->

  robot.respond /pager( me)?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    hubotUser = robot.getUserBySlackUser(msg.message.user)

    campfireUserToPagerDutyUser msg, hubotUser, (user) ->
      emailNote = if hubotUser.pagerdutyEmail
                    "You've told me your PagerDuty email is #{hubotUser.pagerdutyEmail}"
                  else if hubotUser.email_address
                    "I'm assuming your PagerDuty email is #{hubotUser.email_address}. Change it with `#{robot.name} pager me as you@yourdomain.com`"
      if user
        msg.send "I found your PagerDuty user #{user.html_url}, #{emailNote}"
      else
        msg.send "I couldn't find your user :( #{emailNote}"

    cmds = robot.helpCommands()
    cmds = (cmd for cmd in cmds when cmd.match(/hubot (pager |who's on call)/))
    msg.send cmds.join("\n")

  # hubot pager me as <email> - remember your pager email is <email>
  robot.respond /pager(?: me)? as (.*)$/i, (msg) ->
    hubotUser = robot.getUserBySlackUser(msg.message.user)
    email = msg.match[1]
    hubotUser.pagerdutyEmail = email
    msg.send "Okay, I'll remember your PagerDuty email is #{email}"

  # hubot pager forget me - forget your pager email
  robot.respond /pager forget me$/i, (msg) ->
    hubotUser = robot.getUserBySlackUser(msg.message.user)
    hubotUser.pagerdutyEmail = undefined
    msg.send "Okay, I've forgotten your PagerDuty email"

  # hubot pager incident <incident> - return the incident NNN
  robot.respond /(pager|major)( me)? incident (.*)$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    pagerduty.getIncident msg.match[3], (err, incident) ->
      if err?
        robot.emit 'error', err, msg
        return

      msg.send formatIncident(incident)

  # hubot pager incidents - return the current incidents
  # hubot pager sup - return the current incidents
  # hubot pager problems - return all open incidents
  robot.respond /(pager|major)( me)? (inc|incidents|sup|problems)( --canary)?$/i, (msg) ->
    pagerduty.getIncidents "triggered,acknowledged", (err, incidents) ->
      if err?
        robot.emit 'error', err, msg
        return

      unless msg.match[4]
        incidents = incidents.filter (inc) ->
           !/ninesapp\/canary/.test(inc.title)

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

  # hubot pager trigger (no user/schedule)
  robot.respond /(pager|major)( me)? (?:trigger|page) ([\w\-]+)$/i, (msg) ->
    msg.reply "Please include a user or schedule to page, like 'hubot pager infrastructure everything is on fire'."

  # hubot pager trigger <user> <severity> <msg> - create a new incident with <msg> and assign it to <user>. Severity must be one of: critical, error, warning or info.
  # hubot pager trigger <schedule> <severity> <msg> - create a new incident with <msg> and assign it the user currently on call for <schedule>. Severity must be one of: critical, error, warning or info.
  robot.respond /(pager|major)( me)? (?:trigger|page) ([\w\-]+) ([\w]+) (.+)$/i, (msg) ->
    msg.finish()

    if pagerduty.missingEnvironmentForApi(msg)
      return

    hubotUser = robot.getUserBySlackUser(msg.message.user)
    fromUserName   = hubotUser.name
    query          = msg.match[3]
    severity       = msg.match[4]
    reason         = msg.match[5]
    description    = "#{reason} - @#{fromUserName}"

    supportedSeverities = ['critical', 'error', 'warning', 'info']
    if severity not in supportedSeverities
      msg.send "#{severity} is not supported. Choose one from: #{supportedSeverities.join(', ')}"
      return

    # Figure out who we are
    campfireUserToPagerDutyUser msg, hubotUser, false, (triggeredByPagerDutyUser) ->
      triggeredByPagerDutyUserEmail = if triggeredByPagerDutyUser?
                                        emailForUser(triggeredByPagerDutyUser)
                                      else if pagerDutyUserEmail
                                        pagerDutyUserEmail   
      unless triggeredByPagerDutyUserEmail
        msg.send "Sorry, I can't figure your PagerDuty account, and I don't have my own :( Can you tell me your PagerDuty email with `#{robot.name} pager me as you@yourdomain.com`?"
        return

      # Figure out what we're trying to page
      reassignmentParametersForUserOrScheduleOrEscalationPolicy msg, query, (err, results) ->
        if err?
          robot.emit 'error', err, msg
          return

        pagerDutyIntegrationAPI msg, "trigger", query, description, severity, (err, json) ->

          if err?
            robot.emit 'error', err, msg
            return

          msg.reply ":pager: triggered! now assigning it to the right user..."

          incidentKey = json.dedup_key

          setTimeout () ->
            pagerduty.get "/incidents", {incident_key: incidentKey}, (err, json) ->
              if err?
                robot.emit 'error', err, msg
                return
              
              if json?.incidents.length == 0
                msg.reply "Couldn't find the incident we just created to reassign. Please try again :/"
                return

              incident = json.incidents[0]
              data = {"type": "incident_reference"}
              
              if results.assigned_to_user?
                data['assignments'] = [{"assignee": {"id": results.assigned_to_user, "type": "user_reference"}}]
              if results.escalation_policy?
                data['escalation_policy'] = {"id": results.escalation_policy, "type": "escalation_policy_reference"}

              headers = {from: triggeredByPagerDutyUserEmail}

              pagerduty.put "/incidents/#{incident.id}", {'incident': data}, headers, (err, json) ->
                if err?
                  robot.emit 'error', err, msg
                  return

                if not json?.incident
                  msg.reply "Problem reassigning the incident :/"
                  return

                msg.reply ":pager: assigned to #{results.name}!"
          , 7000 # set timeout to 7s. sometimes PagerDuty needs a bit of time for events to propagate as incidents

  # hubot pager ack <incident> - ack incident #<incident>
  # hubot pager ack <incident1> <incident2> ... <incidentN> - ack all specified incidents
  robot.respond /(?:pager|major)(?: me)? ack(?:nowledge)? (.+)$/i, (msg) ->
    msg.finish()
    if pagerduty.missingEnvironmentForApi(msg)
      return

    incidentNumbers = parseIncidentNumbers(msg.match[1])

    # only acknowledge triggered things, since it doesn't make sense to re-acknowledge if it's already in re-acknowledge
    # if it ever doesn't need acknowledge again, it means it's timed out and has become 'triggered' again anyways
    updateIncidents(msg, incidentNumbers, 'triggered,acknowledged', 'acknowledged')

  # hubot pager ack - ack triggered incidents assigned to you
  # hubot pager ack! - ack all triggered incidents, not just yours
  robot.respond /(pager|major)( me)? ack(nowledge)?(!)?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    hubotUser = robot.getUserBySlackUser(msg.message.user)

    force = msg.match[4]?

    pagerduty.getIncidents 'triggered,acknowledged', (err, incidents) ->
      if err?
        robot.emit 'error', err, msg
        return

      email  = emailForUser(hubotUser)
      incidentsForEmail incidents, email, (err, filteredIncidents) ->
        if err? 
          msg.send err.message 
          return
        
        if force 
          filteredIncidents = incidents

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

  # hubot pager resolve <incident> - resolve incident #<incident>
  # hubot pager resolve <incident1> <incident2> ... <incidentN> - resolve all specified incidents
  robot.respond /(?:pager|major)(?: me)? res(?:olve)?(?:d)? (.+)$/i, (msg) ->
    msg.finish()

    if pagerduty.missingEnvironmentForApi(msg)
      return

    incidentNumbers = parseIncidentNumbers(msg.match[1])

    # allow resolving of triggered and acknowedlge, since being explicit
    updateIncidents(msg, incidentNumbers, 'triggered,acknowledged', 'resolved')

  # hubot pager resolve - resolve acknowledged incidents assigned to you
  # hubot pager resolve! - resolve all acknowledged, not just yours
  robot.respond /(pager|major)( me)? res(olve)?(d)?(!)?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    hubotUser = robot.getUserBySlackUser(msg.message.user)

    force = msg.match[5]?
    pagerduty.getIncidents "acknowledged", (err, incidents) ->
      if err?
        robot.emit 'error', err, msg
        return
      
      email  = emailForUser(hubotUser)
      incidentsForEmail incidents, email, (err, filteredIncidents) ->
        if err? 
          robot.emit 'error', err, msg
          return

        if force 
          filteredIncidents = incidents
        
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

  # hubot pager notes <incident> - show notes for incident #<incident>
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
        buffer += "#{note.created_at} #{note.user.summary}: #{note.content}\n"
      if not buffer 
        buffer = "No notes!"
      msg.send buffer

  # hubot pager note <incident> <content> - add note to incident #<incident> with <content>
  robot.respond /(pager|major)( me)? note ([\d\w]+) (.+)$/i, (msg) ->
    msg.finish()

    hubotUser = robot.getUserBySlackUser(msg.message.user)

    if pagerduty.missingEnvironmentForApi(msg)
      return

    incidentId = msg.match[3]
    content = msg.match[4]

    campfireUserToPagerDutyUser msg, hubotUser, (user) ->
      userEmail = emailForUser(user)
      return unless userEmail

      data =
        note:
          content: content

      headers = {from: userEmail}

      pagerduty.post "/incidents/#{incidentId}/notes", data, headers, (err, json) ->
        if err?
          robot.emit 'error', err, msg
          return

        if json && json.note
          msg.send "Got it! Note created: #{json.note.content}"
        else
          msg.send "Sorry, I couldn't do it :("

  # hubot pager schedules - list schedules
  # hubot pager schedules <search> - list schedules matching <search>
  robot.respond /(pager|major)( me)? schedules( (.+))?$/i, (msg) ->
    query = {}
    if msg.match[4]
      query['query'] = msg.match[4]

    if pagerduty.missingEnvironmentForApi(msg)
      return

    msg.send "Retrieving schedules. This may take a few seconds..."

    pagerduty.getSchedules query, (err, schedules) ->
      if err?
        robot.emit 'error', err, msg
        return

      if schedules.length == 0
        msg.send 'No schedules found!'
        return

      renderSchedule = (schedule, cb) ->
        cb(null, "• <https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}|#{schedule.name}>")

      async.map schedules, renderSchedule, (err, results) ->
        if err?
          robot.emit 'error', err, msg
          return

        for chunk in chunkMessageLines(results, 7000)
          msg.send chunk.join("\n")

  # hubot pager schedule <schedule> - show <schedule>'s shifts for the upcoming month
  # hubot pager overrides <schedule> - show upcoming overrides for the next month
  robot.respond /(pager|major)( me)? (schedule|overrides)( ([\w\-]+))?( ([^ ]+))?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    query = {
      since: moment().format(),
      until: moment().add(30, 'days').format()
    }
      
    if !msg.match[5]
      msg.reply "Please specify a schedule with 'pager #{msg.match[3]} <name>.'' Use 'pager schedules' to list all schedules."
      return
    if msg.match[7]
      timezone = msg.match[7]
    else
      timezone = 'UTC'

    msg.send "Retrieving schedules. This may take a few seconds..."

    withScheduleMatching msg, msg.match[5], (schedule) ->
      scheduleId = schedule.id
      return unless scheduleId

      if msg.match[3] && msg.match[3].match /overrides/
        url = "/schedules/#{scheduleId}/overrides"
        query['editable'] = 'true'
        query['overflow'] = 'true'
        key = "overrides"
      else
        url = "/oncalls"
        key = "oncalls"
        query['schedule_ids'] = [scheduleId]

      query['include'] = ['users']

      pagerduty.getAll url, query, key, (err, entries) ->
        if err?
          robot.emit 'error', err, msg
          return

        unless entries.length > 0
          msg.send "None found!"
          return

        sortedEntries = entries.sort (a, b) ->
          moment(a.start).unix() - moment(b.start).unix()

        msg.send formatOncalls(sortedEntries, timezone)

  # hubot pager my schedule - show my on call shifts for the upcoming month in all schedules
  robot.respond /(pager|major)( me)? my schedule( ([^ ]+))?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    hubotUser = robot.getUserBySlackUser(msg.message.user)

    campfireUserToPagerDutyUser msg, hubotUser, (user) ->
      userId = user.id

      if msg.match[4]
        timezone = msg.match[4]
      else
        timezone = 'UTC'
        
      query = {
        since: moment().format(),
        until: moment().add(30, 'days').format(),
        user_ids: [user.id]
        include: ['users']
      }

      pagerduty.getAll "/oncalls", query, "oncalls", (err, oncalls) ->
        if err?
          robot.emit 'error', err, msg
          return

        if oncalls.length == 0
          msg.send 'You are not oncall!'
          return

        msg.send formatOncalls(oncalls, timezone)

  # hubot pager override <schedule> <start> - <end> [username] - Create an schedule override from <start> until <end>. If [username] is left off, defaults to you. start and end should date-parsable dates, like 2014-06-24T09:06:45-07:00, see http://momentjs.com/docs/#/parsing/string/ for examples.
  robot.respond /(pager|major)( me)? (override) ([\w\-]+) ([\w\-:\+]+) - ([\w\-:\+]+)( (.*))?$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    if msg.match[8]
      overrideUser = robot.brain.userForName(msg.match[8])

      unless overrideUser
        msg.send "Sorry, I don't seem to know who that is. Are you sure they are in chat?"
        return
    else
      overrideUser = robot.getUserBySlackUser(msg.message.user)

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
          'user':   {
            'id': userId,
            "type": "user_reference"
          },
        }
        data = { 'override': override }
        pagerduty.post "/schedules/#{scheduleId}/overrides", data, {}, (err, json) ->
          if err?
            robot.emit 'error', err, msg
            return

          unless json && json.override
            msg.send "That didn't work. Check Hubot's logs for an error!"
            return

          start = moment(json.override.start)
          end = moment(json.override.end)
          msg.send "Override setup! #{json.override.user.summary} has the pager from #{start.format()} until #{end.format()}"

  # hubot pager override <schedule> delete <id> - delete an override by its ID
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

  # hubot pager me <schedule> <minutes> - take the pager for <minutes> minutes
  robot.respond /pager( me)? (.+) (\d+)$/i, (msg) ->
    msg.finish()

    # skip hubot pager incident NNN
    if msg.match[2] == 'incident'
      return

    if pagerduty.missingEnvironmentForApi(msg)
      return

    hubotUser = robot.getUserBySlackUser(msg.message.user)

    campfireUserToPagerDutyUser msg, hubotUser, (user) ->

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
          'start': start,
          'end':   end,
          'user':  { 
            'id':   userId,
            "type": "user_reference",
          },
        }
        withCurrentOncall msg, matchingSchedule, (err, old_username, schedule) ->
          if err?
            robot.emit 'error', err, msg
            return

          data = { 'override': override }
          pagerduty.post "/schedules/#{schedule.id}/overrides", data, {}, (err, json) ->
            if err?
              robot.emit 'error', err, msg
              return

            unless json.override
              msg.send "Something went weird."
              return

            start = moment(json.override.start)
            end = moment(json.override.end)
            getPagerDutyUser userId, (err, user) ->
              if err?
                robot.emit 'error', err, msg
                return
              
              msg.send "Rejoice, @#{old_username}! @#{user.name} has the pager on #{schedule.name} until #{end.format()}"

  # hubot Am I on call - return if I'm currently on call or not
  robot.respond /am i on (call|oncall|on-call)/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    msg.send "Finding schedules, this may take a few seconds..."

    hubotUser = robot.getUserBySlackUser(msg.message.user)

    campfireUserToPagerDutyUser msg, hubotUser, (user) ->
      userId = user.id

      renderSchedule = (s, cb) ->
        if not memberOfSchedule(s, userId)
          cb(null, {member: false})
          return 
        
        withCurrentOncallId msg, s, (err, oncallUserid, oncallUsername, schedule) ->
          if err?
            cb(err)
            return

          if userId == oncallUserid
            cb(null, {member: true, body: "* Yes, you are on call for #{schedule.name} - https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}"})
          else
            cb(null, {member: true, body: "* No, you are NOT on call for #{schedule.name} (but #{oncallUsername} is)- https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}"})

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
        
        if (schedules.every (s) -> not memberOfSchedule(s, userId))
          msg.send "You are not assigned to any schedules"
          return

        async.map schedules, renderSchedule, (err, results) ->
          if err?
            robot.emit 'error', err, msg
            return
          results = (r.body for r in results when r.member)
          unless results.length
            results = ["You are not oncall this month!"]
          msg.send results.join("\n")

  # hubot who's on call - return a list of services and who is on call for them
  # hubot who's on call for <schedule> - return the username of who's on call for any schedule matching <search>
  robot.respond /who(’s|'s|s| is|se)? (on call|oncall|on-call)( (?:for )?(.+))?/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    msg.send "Retrieving schedules. This may take a few seconds..."

    scheduleName = msg.match[4]

    renderSchedule = (s, cb) ->
      withCurrentOncallUser msg, s, (err, user, schedule) ->
        if err?
          cb(err)
          return

        Scrolls.log("info", {at: 'who-is-on-call/renderSchedule', schedule: schedule.name, username: user.name})
        if !pagerEnabledForScheduleOrEscalation(schedule) || user.name == "hubot" || user.name == undefined
          cb(null, undefined)
          return

        slackHandle = guessSlackHandleFromEmail(user)
        slackString = " (#{slackHandle})" if slackHandle
        cb(null, "• <https://#{pagerduty.subdomain}.pagerduty.com/schedules##{schedule.id}|#{schedule.name}'s> oncall is #{user.name}#{slackString}")

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
        for chunk in chunkMessageLines(results, 7000)
          msg.send chunk.join("\n")

  # hubot pager services - list services
  robot.respond /(pager|major)( me)? services$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    pagerduty.getAll "/services", {}, "services", (err, services) ->
      if err?
        robot.emit 'error', err, msg
        return

      if services.length == 0
        msg.send 'No services found!'
        return

      renderService = (service, cb) ->
        cb(null, "* #{service.id}: #{service.name} (#{service.status}) - https://#{pagerduty.subdomain}.pagerduty.com/services/#{service.id}")

      async.map services, renderService, (err, results) ->
        if err?
          robot.emit 'error', err, msg
          return
        msg.send results.join("\n")

  # hubot pager maintenance <minutes> <service_id1> <service_id2> ... <service_idN> - schedule a maintenance window for <minutes> for specified services
  robot.respond /(pager|major)( me)? maintenance (\d+) (.+)$/i, (msg) ->
    if pagerduty.missingEnvironmentForApi(msg)
      return

    hubotUser = robot.getUserBySlackUser(msg.message.user)

    campfireUserToPagerDutyUser msg, hubotUser, (user) ->
      requesterEmail = emailForUser(user)
      unless requesterEmail
        return

      minutes = msg.match[3]
      service_ids = msg.match[4].split(' ')
      start_time = moment().format()
      end_time = moment().add(minutes, 'minutes').format()

      maintenance_window = {
        'start_time': start_time,
        'end_time': end_time,
        'type': 'maintenance_window',
        'services': service_ids.map (service_id) ->
          {
            'id': service_id,
            "type": "service_reference"
          }
      }
      data = { 'maintenance_window': maintenance_window }

      headers = {'from': requesterEmail}

      msg.send "Opening maintenance window for: #{service_ids}"
      pagerduty.post "/maintenance_windows", data, headers, (err, json) ->
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

  emailForUser = (user) ->
    user.pagerdutyEmail || user.email_address || user.email || user.profile?.email

  campfireUserToPagerDutyUser = (msg, user, required, cb) ->
    if typeof required is 'function'
      cb = required
      required = true

    email  = emailForUser(user) || process.env.HUBOT_PAGERDUTY_TEST_EMAIL
    speakerEmail = emailForUser(msg.message.user)
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
          user = tryToFind(email, json.users)
          if !user
            msg.send "Sorry, I expected to get 1 user back for #{email}, but only found a list that didn't include the requested email :sweat:. Can you make sure that is actually a real user on PagerDuty?"
          else
            cb(user)
          return

      cb(json.users[0])

  tryToFind = (email, users) ->
    users.find (user) ->
      user.email == email

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
      schedule_ids: [schedule.id]
    }
    pagerduty.getAll "/oncalls", query, "oncalls", (err, oncalls) ->
      if err?
        cb(err, null, null)
        return

      unless oncalls and oncalls.length > 0
        cb(null, "nobody", schedule)
        return

      userId = oncalls[0].user.id
      getPagerDutyUser userId, (err, user) ->
        if err?
          cb(err)
          return
        cb(null, user, schedule)

  getPagerDutyUser = (userId, cb) ->
    pagerduty.get "/users/#{userId}", (err, json) ->
      if err?
        cb(err)
        return

      if not json.user
        cb(null, "nobody")
        return

      cb(null, json.user)

  pagerDutyIntegrationAPI = (msg, cmd, affected, description, severity, cb) ->
    unless pagerDutyServiceApiKey?
      msg.send "PagerDuty API service key is missing."
      msg.send "Ensure that HUBOT_PAGERDUTY_SERVICE_API_KEY is set."
      return

    data = null
    switch cmd
      when "trigger"
        payload = {summary: description, source: affected, severity: severity}
        data = {routing_key: pagerDutyServiceApiKey, event_action: "trigger", payload: payload}
        pagerDutyIntegrationPost msg, data, cb

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
              "#{inc.title} #{inc.summary}"

    names = []
    for assigned in inc.assignments
      names.push assigned.assignee.summary

    if names
      assigned_to = "- assigned to #{names.join(",")}"
    else 
      assigned_to = "- nobody currently assigned"
    
    "#{inc.incident_number}: #{inc.created_at} #{summary} #{assigned_to}\n"

  updateIncidents = (msg, incidentNumbers, statusFilter, updatedStatus) ->
    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      requesterEmail = emailForUser(user)
      unless requesterEmail
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
            incidents: foundIncidents.map (incident) ->
              {
                'id':     incident.id,
                "type":   "incident_reference",
                'status': updatedStatus
              }
          }

          headers = {from: requesterEmail}
          pagerduty.put "/incidents", data, headers, (err, json) ->
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

  pagerDutyIntegrationPost = (msg, body, cb) ->
    request.post {uri: pagerDutyEventsAPIURL, json: true, body: body}, (err, res, body) ->
      if err?
        cb(err)
        return

      switch res.statusCode
        when 200, 201, 202
          cb(null, body)
        else
          cb(new PagerDutyError("#{res.statusCode} back from #{path}"))

  allUserEmails = (cb) ->
    pagerduty.getAll "/users", {}, "users", (err, returnedUsers) ->
      if err?
        cb(err)
        return

      users = {}
      for user in returnedUsers
        users[user.id] = user.email
      cb(null, users)

  incidentsForEmail = (incidents, userEmail, cb) ->
    allUserEmails (err, userEmails) ->
      if err? 
        cb(err)
        return 
      
      filtered = []
      for incident in incidents
        for assignment in incident.assignments
          assignedEmail = userEmails[assignment.assignee.id]
          if assignedEmail is userEmail
            filtered.push incident
      cb(null, filtered)

  memberOfSchedule = (schedule, userId) ->
    schedule.users.some (scheduleUser) ->
      scheduleUser.id == userId

  formatOncalls = (oncalls, timezone) ->
    buffer = ""
    schedules = {}
    for oncall in oncalls 
      startTime = moment(oncall.start).tz(timezone).format()
      endTime   = moment(oncall.end).tz(timezone).format()
      time      = "#{startTime} - #{endTime}"
      username  = guessSlackHandleFromEmail(oncall.user) || oncall.user.summary
      if oncall.schedule?
        scheduleId = oncall.schedule.id
        if scheduleId not of schedules 
          schedules[scheduleId] = []
        if time not in schedules[scheduleId]
          schedules[scheduleId].push time
          buffer += "• #{time} #{username} (<#{oncall.schedule.html_url}|#{oncall.schedule.summary}>)\n"
      else if oncall.escalation_policy?
        # no schedule embedded
        epSummary = oncall.escalation_policy.summary
        epURL = oncall.escalation_policy.html_url
        buffer += "• #{time} #{username} (<#{epURL}|#{epSummary}>)\n"
      else 
        # override
        buffer += "• #{time} #{username}\n"
    buffer


  chunkMessageLines = (messageLines, boundary) ->
    allChunks = []
    thisChunk = []
    charCount = 0

    for line in messageLines
      if charCount >= boundary
        allChunks.push(thisChunk)
        charCount = 0
        thisChunk = []

      thisChunk.push(line)
      charCount += line.length

    allChunks.push(thisChunk)
    allChunks

  guessSlackHandleFromEmail = (user) ->
    # Context: https://github.slack.com/archives/C0GNSSLUF/p1539181657000100
    if user.email == "jp@github.com"
      "`josh`"
    else if user.email.search(/github\.com/)
      user.email.replace(/(.+)\@github\.com/, '`$1`')
    else
      null
