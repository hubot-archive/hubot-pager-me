HttpClient = require 'scoped-http-client'

pagerDutyApiKey        = process.env.HUBOT_PAGERDUTY_API_KEY
pagerDutySubdomain     = process.env.HUBOT_PAGERDUTY_SUBDOMAIN
pagerDutyBaseUrl       = 'https://api.pagerduty.com'
pagerDutyServices      = process.env.HUBOT_PAGERDUTY_SERVICES
pagerDutyFromEmail     = process.env.HUBOT_PAGERDUTY_FROM_EMAIL
pagerNoop              = process.env.HUBOT_PAGERDUTY_NOOP
pagerNoop              = false if pagerNoop is 'false' or pagerNoop is 'off'

class PagerDutyError extends Error
module.exports =
  http: (path) ->
    HttpClient.create("#{pagerDutyBaseUrl}#{path}")
      .headers(
        'Accept': 'application/vnd.pagerduty+json;version=2',
        'Authorization': "Token token=#{pagerDutyApiKey}",
        'From': pagerDutyFromEmail
      )

  missingEnvironmentForApi: (msg) ->
    missingAnything = false
    unless pagerDutyFromEmail?
      msg.send "PagerDuty From is missing:  Ensure that HUBOT_PAGERDUTY_FROM_EMAIL is set."
      missingAnything |= true
    unless pagerDutyApiKey?
      msg.send "PagerDuty API Key is missing:  Ensure that HUBOT_PAGERDUTY_API_KEY is set."
      missingAnything |= true
    missingAnything

  get: (url, query, cb) ->
    if typeof(query) is 'function'
      cb = query
      query = {}

    if pagerDutyServices? && url.match /\/incidents/
      query['service'] = pagerDutyServices

    @http(url)
      .query(query)
      .get() (err, res, body) ->
        if err?
          cb(err)
          return
        json_body = null
        switch res.statusCode
          when 200 then json_body = JSON.parse(body)
          else
            cb(new PagerDutyError("#{res.statusCode} back from #{url}"))

        cb null, json_body

  put: (url, data, cb) ->
    if pagerNoop
      console.log "Would have PUT #{url}: #{inspect data}"
      return

    json = JSON.stringify(data)
    @http(url)
      .header('content-type', 'application/json')
      .put(json) (err, res, body) ->
        if err?
          callback(err)
          return

        json_body = null
        switch res.statusCode
          when 200 then json_body = JSON.parse(body)
          else
            return cb(new PagerDutyError("#{res.statusCode} back from #{url}"))
        cb null, json_body

  post: (url, data, cb) ->
    if pagerNoop
      console.log "Would have POST #{url}: #{inspect data}"
      return

    json = JSON.stringify(data)
    @http(url)
      .header('content-type', 'application/json')
      .post(json) (err, res, body) ->
        if err?
          return cb(err)

        json_body = null
        switch res.statusCode
          when 201 then json_body = JSON.parse(body)
          else
            return cb(new PagerDutyError("#{res.statusCode} back from #{url}"))
        cb null, json_body

  delete: (url, cb) ->
    if pagerNoop
      console.log "Would have DELETE #{url}"
      return

    auth = "Token token=#{pagerDutyApiKey}"
    @http(url)
      .header("content-length",0)
      .delete() (err, res, body) ->
        if err?
          return cb(err)
        json_body = null
        switch res.statusCode
          when 204, 200
            value = true
          else
            console.log res.statusCode
            console.log body
            value = false
        cb null, value

  getIncident: (incident, cb) ->
    @get "/incidents/#{encodeURIComponent incident}", {}, (err, json) ->
      if err?
        cb(err)
        return

      cb(null, json)

  getIncidents: (status, cb) ->
    query =
      sort_by: 'incident_number:asc'
      'statuses[]': status.split(',')

    @get "/incidents", query, (err, json) ->
      if err?
        cb(err)
        return
      cb(null, json.incidents)

  getSchedules: (query, cb) ->
    if typeof(query) is 'function'
      cb = query
      query = {}

    @get "/schedules", query, (err, json) ->
      if err?
        cb(err)
        return

      cb(null, json.schedules)

  subdomain: pagerDutySubdomain
