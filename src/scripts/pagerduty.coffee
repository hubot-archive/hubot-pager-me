# Description:
#   Interact with PagerDuty services, schedules, and incidents with Hubot.
#
# Commands:
#
#   hubot pager me as <email>                                    remember your pager email is <email>
#   hubot who's on call                                          return a list of services and who is on call for them
#   hubot who's on call for <search>                             return the username of who's on call for any schedule matching <search>
#   hubot pager trigger <user> <msg>                             create a new incident with <msg> and assign it to <user>
#   hubot pager trigger <schedule> <msg>                         create a new incident with <msg> and assign it the user currently on call for <schedule>
#   hubot pager incidents                                        return the current incidents
#   hubot pager sup                                              return the current incidents
#   hubot pager incident NNN                                     return the incident NNN
#   hubot pager note <incident> <content>                        add note to incident #<incident> with <content>
#   hubot pager notes <incident>                                 show notes for incident #<incident>
#   hubot pager problems                                         return all open incidents
#   hubot pager ack <incident>                                   ack incident #<incident>
#   hubot pager ack                                              ack triggered incidents assigned to you
#   hubot pager ack!                                             ack all triggered incidents, not just yours
#   hubot pager ack <incident1> <incident2> ... <incidentN>      ack all specified incidents
#   hubot pager resolve <incident>                               resolve incident #<incident>
#   hubot pager resolve <incident1> <incident2> ... <incidentN>  resolve all specified incidents
#   hubot pager resolve                                          resolve acknowledged incidents assigned to you
#   hubot pager resolve!                                         resolve all acknowledged, not just yours
#   hubot pager schedules                                        list schedules
#   hubot pager schedules <search>                               list schedules matching <search>
#   hubot pager schedule <schedule>                              show <schedule>'s shifts for the upcoming month
#   hubot pager me <schedule> 60                                 take the pager for 60 minutes
#   hubot pager override <schedule> <start> - <end> [username]   Create an schedule override from <start> until <end>. If [username] is left off, defaults to you. start and end should date-parsable dates, like 2014-06-24T09:06:45-07:00, see http://momentjs.com/docs/#/parsing/string/ for examples.
#   hubot pager overrides <schedule>                             show upcoming overrides for the next month
#   hubot pager override <schedule> delete <id>                  delete an override by its ID
#
# Authors:
#   Jesse Newland, Josh Nicols, Jacob Bednarz, Chris Lundquist, Chris Streeter, Joseph Pierri, Greg Hoin

inspect = require('util').inspect

moment = require('moment')

pagerDutyApiKey        = process.env.HUBOT_PAGERDUTY_API_KEY
pagerDutySubdomain     = process.env.HUBOT_PAGERDUTY_SUBDOMAIN
pagerDutyBaseUrl       = "https://#{pagerDutySubdomain}.pagerduty.com/api/v1"
pagerDutyServiceApiKey = process.env.HUBOT_PAGERDUTY_SERVICE_API_KEY
pagerRoom              = process.env.HUBOT_PAGERDUTY_ROOM
# Webhook listener endpoint. Set it to whatever URL you want, and make sure it matches your pagerduty service settings
pagerEndpoint          = process.env.HUBOT_PAGERDUTY_ENDPOINT || "/hook"
pagerNoop              = process.env.HUBOT_PAGERDUTY_NOOP
pagerNoop               = false if pagerNoop is "false" or pagerNoop  is "off"

module.exports = (robot) ->
  robot.respond /pager( me)?$/i, (msg) ->
    if missingEnvironmentForApi(msg)
      return

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      emailNote = if msg.message.user.pagerdutyEmail
                    "You've told me your PagerDuty email is #{msg.message.user.pagerdutyEmail}"
                  else if msg.message.user.email_address
                    "I'm assuming your PagerDuty email is #{msg.message.user.email_address}. Change it with `#{robot.name} pager me as you@yourdomain.com`"
      if user
        msg.send "I found your PagerDuty user https://#{pagerDutySubdomain}.pagerduty.com#{user.user_url}, #{emailNote}"
      else
        msg.send "I couldn't find your user :( #{emailNote}"



    cmds = robot.helpCommands()
    cmds = (cmd for cmd in cmds when cmd.match(/(hubot pager|on call)/))
    msg.send cmds.join("\n")

  robot.respond /pager(?: me)? as (.*)$/i, (msg) ->
    email = msg.match[1]
    msg.message.user.pagerdutyEmail = email
    msg.send "Okay, I'll remember your PagerDuty email is #{email}"

  robot.respond /(pager|major)( me)? incident (.*)$/, (msg) ->
    pagerDutyIncident msg, msg.match[3], (incident) ->
      msg.send formatIncident(incident)

  robot.respond /(pager|major)( me)? (inc|incidents|sup|problems)$/i, (msg) ->
    pagerDutyIncidents msg, "triggered,acknowledged", (incidents) ->
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
    fromUserName   = msg.message.user.name
    userOrSchedule = msg.match[3]
    reason         = msg.match[4]
    description    = "#{reason} - @#{fromUserName}"

    # Figure out who we are
    campfireUserToPagerDutyUser msg, msg.message.user, (triggerdByPagerDutyUser) ->
      triggerdByPagerDutyUserId = triggerdByPagerDutyUser.id
      return unless triggerdByPagerDutyUserId

      # Figure out what we're trying to page
      pagerDutyUserFromNameOrSchedule msg, msg.match[3], (userToPage) ->
        if !userToPage
          msg.reply "Couldn't find a user or unique schedule matching #{userOrSchedule} :/"
        else
          pagerDutyIntegrationAPI msg, "trigger", description, (json) ->
            query = {
              incident_key: json.incident_key
            }
            msg.reply ":pager: triggered! now assigning it to the right user..."
            setTimeout () ->
              pagerDutyGet msg, "/incidents", query, (json) ->
                if json?.incidents.length == 0
                  console.log inspect query
                  console.log inspect json
                  msg.reply "Couldn't find the incident we just created to reassign. Please try again :/"
                else
                  data = {
                    requester_id: triggerdByPagerDutyUserId,
                    incidents: json.incidents.map (incident) ->
                      {
                        'id':               incident.id,
                        'assigned_to_user': userToPage.id
                      }
                  }

                  pagerDutyPut msg, "/incidents", data , (json) ->
                    if json?.incidents.length == 1
                      msg.reply ":pager: assigned to #{userToPage.name}!"
                    else
                      console.log inspect data
                      console.log inspect json
                      msg.reply "Problem reassigning the incident :/"
            , 5000

  robot.respond /(?:pager|major)(?: me)? ack(?:nowledge)? (.+)$/i, (msg) ->
    msg.finish()
    incidentNumbers = parseIncidentNumbers(msg.match[1])

    # only acknowledge triggered things, since it doesn't make sense to re-acknowledge if it's already in re-acknowledge
    # if it ever doesn't need acknowledge again, it means it's timed out and has become 'triggered' again anyways
    updateIncidents(msg, incidentNumbers, 'triggered,acknowledged', 'acknowledged')

  robot.respond /(pager|major)( me)? ack(nowledge)?(!)?$/i, (msg) ->
    force = msg.match[4]?

    pagerDutyIncidents msg, 'triggered,acknwowledged', (incidents) ->
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
    incidentNumbers = parseIncidentNumbers(msg.match[1])

    # allow resolving of triggered and acknowedlge, since being explicit
    updateIncidents(msg, incidentNumbers, 'triggered,acknowledged', 'resolved')

  robot.respond /(pager|major)( me)? res(olve)?(d)?(!)?$/i, (msg) ->
    force = msg.match[5]?
    pagerDutyIncidents msg, "acknowledged", (incidents) ->
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
    incidentId = msg.match[3]
    pagerDutyGet msg, "/incidents/#{incidentId}/notes", {}, (json) ->
      buffer = ""
      for note in json.notes
        buffer += "#{note.created_at} #{note.user.name}: #{note.content}\n"
      msg.send buffer

  robot.respond /(pager|major)( me)? note ([\d\w]+) (.+)$/i, (msg) ->
    msg.finish()

    incidentId = msg.match[3]
    content = msg.match[4]

    campfireUserToPagerDutyUser msg, msg.message.user, (user) ->
      userId = user.id
      return unless userId

      data =
        note:
          content: content
        requester_id: userId

      pagerDutyPost msg, "/incidents/#{incidentId}/notes", data, (json) ->
        if json && json.note
          msg.send "Got it! Note created: #{json.note.content}"
        else
          msg.send "Sorry, I couldn't do it :("

  robot.respond /(pager|major)( me)? schedules( (.+))?$/i, (msg) ->
    query = {}
    if msg.match[4]
      query['query'] = msg.match[4]
    pagerDutyGet msg, "/schedules", query, (json) ->
      buffer = ''
      schedules = json.schedules
      if schedules.length > 0
        for schedule in schedules
          buffer += "* #{schedule.name} - https://#{pagerDutySubdomain}.pagerduty.com/schedules##{schedule.id}\n"
        msg.send buffer
      else
        msg.send 'No schedules found!'

  robot.respond /(pager|major)( me)? (schedule|overrides)( ([\w\-]+))?$/i, (msg) ->
    query = {
      since: moment().format(),
      until: moment().add('days', 30).format(),
      overflow: 'true'
    }

    thing = 'entries'
    if msg.match[3] && msg.match[3].match /overrides/
      thing = 'overrides'
      query['editable'] = 'true'

    if !msg.match[5]
      msg.reply "Please specify a schedule with 'pager #{msg.match[3]} <name>.'' Use 'pager schedules' to list all schedules."
      return

    withScheduleMatching msg, msg.match[5], (schedule) ->
      scheduleId = schedule.id
      return unless scheduleId

      pagerDutyGet msg, "/schedules/#{scheduleId}/#{thing}", query, (json) ->
        entries = json.entries || json.overrides
        if entries
          sortedEntries = entries.sort (a, b) ->
            moment(a.start).unix() - moment(b.start).unix()

          buffer = ""
          for entry in sortedEntries
            if entry.id
              buffer += "* (#{entry.id}) #{entry.start} - #{entry.end} #{entry.user.name}\n"
            else
              buffer += "* #{entry.start} - #{entry.end} #{entry.user.name}\n"
          if buffer == ""
            msg.send "None found!"
          else
            msg.send buffer
        else
          msg.send "None found!"

  robot.respond /(pager|major)( me)? (override) ([\w\-]+) ([\w\-:]+) - ([\w\-:]+)( (.*))?$/i, (msg) ->
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
          pagerDutyPost msg, "/schedules/#{scheduleId}/overrides", data, (json) ->
            if json && json.override
              start = moment(json.override.start)
              end = moment(json.override.end)
              msg.send "Override setup! #{json.override.user.name} has the pager from #{start.format()} until #{end.format()}"
            else
              msg.send "That didn't work. Check Hubot's logs for an error!"
        else
          msg.send "Please use a http://momentjs.com/ compatible date!"

  robot.respond /(pager|major)( me)? (overrides?) ([\w\-]*) (delete) (.*)$/i, (msg) ->
    withScheduleMatching msg, msg.match[4], (schedule) ->
      scheduleId = schedule.id
      return unless scheduleId

      pagerDutyDelete msg, "/schedules/#{scheduleId}/overrides/#{msg.match[6]}", (success) ->
        if success
          msg.send ":boom:"
        else
          msg.send "Something went weird."

  robot.respond /pager( me)? (.+) (\d+)$/i, (msg) ->
    msg.finish()
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
        end       = moment().add('minutes', minutes).format()
        override  = {
          'start':     start,
          'end':       end,
          'user_id':   userId
        }
        withCurrentOncall msg, matchingSchedule, (old_username, schedule) ->
          data = { 'override': override }
          pagerDutyPost msg, "/schedules/#{schedule.id}/overrides", data, (json) ->
            if json.override
              start = moment(json.override.start)
              end = moment(json.override.end)
              msg.send "Rejoice, #{old_username}! #{json.override.user.name} has the pager on #{schedule.name} until #{end.format()}"


  # who is on call?
  robot.respond /who('s|s| is|se)? (on call|oncall|on-call)( for (.+))?/i, (msg) ->
    query = {}
    if msg.match[4]
      query['query'] = msg.match[4]
    pagerDutyGet msg, "/schedules", query, (json) ->
      schedules = json.schedules
      if schedules.length > 0
        for s in schedules
          withCurrentOncall msg, s, (username, schedule) ->
            msg.send "* #{username} is on call for #{schedule.name} - https://#{pagerDutySubdomain}.pagerduty.com/schedules##{schedule.id}\n"
      else
        msg.send 'No schedules found!'

  parseIncidentNumbers = (match) ->
    match.split(/[ ,]+/).map (incidentNumber) ->
      parseInt(incidentNumber)

  missingEnvironmentForApi = (msg) ->
    missingAnything = false
    unless pagerDutySubdomain?
      msg.send "PagerDuty Subdomain is missing:  Ensure that HUBOT_PAGERDUTY_SUBDOMAIN is set."
      missingAnything |= true
    unless pagerDutyApiKey?
      msg.send "PagerDuty API Key is missing:  Ensure that HUBOT_PAGERDUTY_API_KEY is set."
      missingAnything |= true
    missingAnything


  campfireUserToPagerDutyUser = (msg, user, cb) ->

    email  = user.pagerdutyEmail || user.email_address || process.env.HUBOT_PAGERDUTY_TEST_EMAIL
    speakerEmail = msg.message.user.pagerdutyEmail || msg.message.user.email_address
    unless email
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

    pagerDutyGet msg, "/users", {query: email}, (json) ->
      if json.users.length isnt 1
        msg.send "Sorry, I expected to get 1 user back for #{email}, but got #{json.users.length} :sweat:. Can you make sure that is actually a real user on PagerDuty?"
        return

      cb(json.users[0])


  pagerDutyGet = (msg, url, query, cb) ->
    if missingEnvironmentForApi(msg)
      return

    auth = "Token token=#{pagerDutyApiKey}"
    msg.http(pagerDutyBaseUrl + url)
      .query(query)
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        json_body = null
        switch res.statusCode
          when 200 then json_body = JSON.parse(body)
          else
            console.log res.statusCode
            console.log body
            json_body = null
        cb json_body

  pagerDutyPut = (msg, url, data, cb) ->
    if missingEnvironmentForApi(msg)
      return

    if pagerNoop
      msg.send "Would have PUT #{url}: #{inspect data}"
      return

    json = JSON.stringify(data)
    auth = "Token token=#{pagerDutyApiKey}"
    msg.http(pagerDutyBaseUrl + url)
      .headers(Authorization: auth, Accept: 'application/json')
      .header("content-type","application/json")
      .header("content-length",json.length)
      .put(json) (err, res, body) ->
        json_body = null
        switch res.statusCode
          when 200 then json_body = JSON.parse(body)
          else
            console.log res.statusCode
            console.log body
            json_body = null
        cb json_body

  pagerDutyPost = (msg, url, data, cb) ->
    if missingEnvironmentForApi(msg)
      return

    if pagerNoop
      msg.send "Would have POST #{url}: #{inspect data}"
      return

    json = JSON.stringify(data)
    auth = "Token token=#{pagerDutyApiKey}"
    msg.http(pagerDutyBaseUrl + url)
      .headers(Authorization: auth, Accept: 'application/json')
      .header("content-type","application/json")
      .header("content-length",json.length)
      .post(json) (err, res, body) ->
        json_body = null
        switch res.statusCode
          when 201 then json_body = JSON.parse(body)
          else
            console.log res.statusCode
            console.log body
            json_body = null
        cb json_body

  pagerDutyDelete = (msg, url, cb) ->
    if missingEnvironmentForApi(msg)
      return

    if pagerNoop
      msg.send "Would have DELETE #{url}"
      return

    auth = "Token token=#{pagerDutyApiKey}"
    msg.http(pagerDutyBaseUrl + url)
      .headers(Authorization: auth, Accept: 'application/json')
      .header("content-length",0)
      .delete() (err, res, body) ->
        json_body = null
        switch res.statusCode
          when 204 || 200
            value = true
          else
            console.log res.statusCode
            console.log body
            value = false
        cb value

  oneScheduleMatching = (msg, q, cb) ->
    query = {
      query: q
    }
    pagerDutyGet msg, "/schedules", query, (json) ->
      schedule = null
      # Single result returned
      if json?.schedules?.length == 1
        schedule = json.schedules[0]

      # Multiple results returned and one is exact
      if json?.schedules?.length > 1
        matchingExactly = json.schedules.filter (s) ->
          s.name == q
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

  pagerDutyUserFromNameOrSchedule = (msg, string, cb) ->
    if campfireUser = robot.brain.userForName(string)
      campfireUserToPagerDutyUser msg, campfireUser, (user) ->
        cb(user)
    else
      oneScheduleMatching msg, string, (schedule) ->
        if schedule
          withCurrentOncallUser msg, schedule, (user, schedule) ->
            cb(user)
        else
          cb()

  withCurrentOncall = (msg, schedule, cb) ->
    withCurrentOncallUser msg, schedule, (user, s) ->
      cb(user.name, s)

  withCurrentOncallUser = (msg, schedule, cb) ->
    oneHour = moment().add('hours', 1).format()
    now = moment().format()

    query = {
      since: now,
      until: oneHour,
      overflow: 'true'
    }
    pagerDutyGet msg, "/schedules/#{schedule.id}/entries", query, (json) ->
      if json.entries and json.entries.length > 0
        cb(json.entries[0].user, schedule)

  pagerDutyIncident = (msg, incident, cb) ->
    pagerDutyGet msg, "/incidents/#{encodeURIComponent incident}", {}, (json) ->
      cb(json)

  pagerDutyIncidents = (msg, status, cb) ->
    query =
      status:  status
      sort_by: "incident_number:asc"
    pagerDutyGet msg, "/incidents", query, (json) ->
      cb(json.incidents)

  pagerDutyIntegrationAPI = (msg, cmd, description, cb) ->
    unless pagerDutyServiceApiKey?
      msg.send "PagerDuty API service key is missing."
      msg.send "Ensure that HUBOT_PAGERDUTY_SERVICE_API_KEY is set."
      return

    data = null
    switch cmd
      when "trigger"
        data = JSON.stringify { service_key: pagerDutyServiceApiKey, event_type: "trigger", description: description}
        pagerDutyIntergrationPost msg, data, (json) ->
          cb(json)

  formatIncident = (inc) ->
     # { pd_nagios_object: 'service',
     #   HOSTNAME: 'fs1a',
     #   SERVICEDESC: 'snapshot_repositories',
     #   SERVICESTATE: 'CRITICAL',
     #   HOSTSTATE: 'UP' },

    summary = if inc.trigger_summary_data
              # email services
              if inc.trigger_summary_data.subject
                inc.trigger_summary_data.subject
              else if inc.trigger_summary_data.description
                inc.trigger_summary_data.description
              else if inc.trigger_summary_data.pd_nagios_object == 'service'
                 "#{inc.trigger_summary_data.HOSTNAME}/#{inc.trigger_summary_data.SERVICEDESC}"
              else if inc.trigger_summary_data.pd_nagios_object == 'host'
                 "#{inc.trigger_summary_data.HOSTNAME}/#{inc.trigger_summary_data.HOSTSTATE}"
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
      return unless requesterId

      pagerDutyIncidents msg, statusFilter, (incidents) ->
        foundIncidents = []
        for incident in incidents
          # FIXME this isn't working very consistently
          if incidentNumbers.indexOf(incident.incident_number) > -1
            foundIncidents.push(incident)

        if foundIncidents.length == 0
          msg.reply "Couldn't find incidents #{incidentNumbers.join(', ')} in #{inspect incidents}"
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

          pagerDutyPut msg, "/incidents", data , (json) ->
            if json?.incidents
              buffer = "Incident"
              buffer += "s" if json.incidents.length > 1
              buffer += " "
              buffer += (incident.incident_number for incident in json.incidents).join(", ")
              buffer += " #{updatedStatus}"
              msg.reply buffer
            else
              msg.reply "Problem updating incidents #{incidentNumbers.join(',')}"


  pagerDutyIntergrationPost = (msg, json, cb) ->
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


  # Pagerduty Webhook Integration (For a payload example, see http://developer.pagerduty.com/documentation/rest/webhooks)
  parseWebhook = (req, res) ->
    hook = req.body

    messages = hook.messages

    if /^incident.*$/.test(messages[0].type)
      parseIncidents(messages)
    else
      "No incidents in webhook"

  getUserForIncident = (incident) ->
    if incident.assigned_to_user
      incident.assigned_to_user.email
    else if incident.resolved_by_user
      incident.resolved_by_user.email
    else
      '(???)'

  incidentsForEmail = (incidents, userEmail) ->
    incidents.filter (incident) ->
      incident.assigned_to.some (assignment) ->
        assignment.object.email is userEmail

  generateIncidentString = (incident, hookType) ->
    console.log "hookType is " + hookType
    assigned_user   = getUserForIncident(incident)
    incident_number = incident.incident_number

    if hookType == "incident.trigger"
      """
      Incident # #{incident_number} :
      #{incident.status} and assigned to #{assigned_user}
       #{incident.html_url}
      To acknowledge: @#{robot.name} pager me ack #{incident_number}
      To resolve: @#{robot.name} pager me resolve #{}
      """
    else if hookType == "incident.acknowledge"
      """
      Incident # #{incident_number} :
      #{incident.status} and assigned to #{assigned_user}
       #{incident.html_url}
      To resolve: @#{robot.name} pager me resolve #{incident_number}
      """
    else if hookType == "incident.resolve"
      """
      Incident # #{incident_number} has been resolved by #{assigned_user}
       #{incident.html_url}
      """
    else if hookType == "incident.unacknowledge"
      """
      #{incident.status} , unacknowledged and assigned to #{assigned_user}
       #{incident.html_url}
      To acknowledge: @#{robot.name} pager me ack #{incident_number}
       To resolve: @#{robot.name} pager me resolve #{incident_number}
      """
    else if hookType == "incident.assign"
      """
      Incident # #{incident_number} :
      #{incident.status} , reassigned to #{assigned_user}
       #{incident.html_url}
      To resolve: @#{robot.name} pager me resolve #{incident_number}
      """
    else if hookType == "incident.escalate"
      """
      Incident # #{incident_number} :
      #{incident.status} , was escalated and assigned to #{assigned_user}
       #{incident.html_url}
      To acknowledge: @#{robot.name} pager me ack #{incident_number}
      To resolve: @#{robot.name} pager me resolve #{incident_number}
      """

  parseIncidents = (messages) ->
    returnMessage = []
    count = 0
    for message in messages
      incident = message.data.incident
      hookType = message.type
      returnMessage.push(generateIncidentString(incident, hookType))
      count = count+1
    returnMessage.unshift("You have " + count + " PagerDuty update(s): \n")
    returnMessage.join("\n")


  # Webhook listener
  if pagerEndpoint && pagerRoom
    robot.router.post pagerEndpoint, (req, res) ->
      robot.messageRoom(pagerRoom, parseWebhook(req,res))
      res.end()
