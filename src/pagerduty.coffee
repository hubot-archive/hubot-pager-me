HttpClient = require 'scoped-http-client'
Scrolls    = require('../../../lib/scrolls').context({script: 'pagerduty'})
request    = require '@cypress/request'
qs         = require 'query-string'

pagerDutyApiKey        = process.env.HUBOT_PAGERDUTY_API_KEY
pagerDutySubdomain     = process.env.HUBOT_PAGERDUTY_SUBDOMAIN
pagerDutyBaseUrl       = "https://api.pagerduty.com"
pagerDutyServices      = process.env.HUBOT_PAGERDUTY_SERVICES
pagerNoop              = process.env.HUBOT_PAGERDUTY_NOOP
pagerNoop              = false if pagerNoop is "false" or pagerNoop  is "off"

class PagerDutyError extends Error
module.exports =
  subdomain: pagerDutySubdomain

  headers: (headers = {}) ->
    headers['Authorization'] = "Token token=#{pagerDutyApiKey}"
    headers['Accept'] = 'application/vnd.pagerduty+json;version=2'
    headers

  url: (path, query = {}) ->
    queryStr = qs.stringify query, {arrayFormat: 'bracket'}
    path += "?#{queryStr}" if queryStr.length > 0
    url = "#{pagerDutyBaseUrl}#{path}"
    url

  missingEnvironmentForApi: (msg) ->
    missingAnything = false
    unless pagerDutySubdomain?
      msg.send "PagerDuty Subdomain is missing:  Ensure that HUBOT_PAGERDUTY_SUBDOMAIN is set."
      missingAnything |= true
    unless pagerDutyApiKey?
      msg.send "PagerDuty API Key is missing:  Ensure that HUBOT_PAGERDUTY_API_KEY is set."
      missingAnything |= true
    missingAnything

  get: (path, query, cb) ->
    if typeof(query) is 'function'
      cb = query
      query = {}

    if pagerDutyServices? && path.match /\/incidents/
      query['service_ids'] = pagerDutyServices.split ","

    Scrolls.log('info', {at: 'get/request', path: path, query: query})

    request.get {uri: @url(path, query), json: true, headers: @headers()}, (err, res, body) ->
      if err?
        Scrolls.log('info', {at: 'get/error', path: path, query: query, error: err})
        cb(err)
        return

      Scrolls.log('info', {at: 'get/response', path: path, query: query, status: res.statusCode, body: body})

      unless res.statusCode is 200
        cb(new PagerDutyError("#{res.statusCode} back from #{path}"))
        return
      
      cb(null, body)

  getAll: (path, query, key, all_cb) ->
    entries = []
    `var self = this`

    if not query["offset"]
      query["offset"] = 0
    if not query["limit"]
      query["limit"] = 100
    
    cb = (err, body) ->
      if err?
        all_cb(err)
        return

      entries = entries.concat body[key]
      if body.more
        query["offset"] += body.limit
        `self.get(path, query, cb)`
        return

      all_cb(null, entries)

    @get(path, query, cb)

  put: (path, data, customHeaders, cb) ->
    if pagerNoop
      console.log "Would have PUT #{path}: #{inspect data}"
      return

    Scrolls.log('info', {at: 'put/request', path: path, body: data})

    request.put {uri: @url(path), json: true, headers: @headers(customHeaders), body: data}, (err, res, body) ->
      if err?
        Scrolls.log('info', {at: 'put/error', path: path, error: err})
        cb(err)
        return

      Scrolls.log('info', {at: 'put/response', path: path, status: res.statusCode, body: body})

      unless res.statusCode is 200
        cb(new PagerDutyError("#{res.statusCode} back from #{path}"))
        return

      cb(null, body)

  post: (path, data, customHeaders, cb) ->
    if pagerNoop
      console.log "Would have POST #{path}: #{inspect data}"
      return  
    
    Scrolls.log('info', {at: 'post/request', path: path, body: data})

    request.post {uri: @url(path), json: true, headers: @headers(customHeaders), body: data}, (err, res, body) ->
      if err?
        Scrolls.log('info', {at: 'post/error', path: path, error: err})
        cb(err)
        return

      Scrolls.log('info', {at: 'post/response', path: path, status: res.statusCode, body: body})

      unless res.statusCode is 201
        cb(new PagerDutyError("#{res.statusCode} back from #{path}"))
        return

      cb(null, body)

  delete: (path, cb) ->
    if pagerNoop
      console.log "Would have DELETE #{path}"
      return

    Scrolls.log('info', {at: 'delete/request', path: path, query: query})

    request.delete {uri: @url(path), headers: @headers()}, (err, res) ->
      if err?
        Scrolls.log('info', {at: 'delete/error', path: path, query: query, error: err})
        cb(err)
        return

      Scrolls.log('info', {at: 'delete/response', path: path, status: res.statusCode})

      unless res.statusCode is 200 or res.statusCode is 204
        cb(new PagerDutyError("#{res.statusCode} back from #{path}"), false)
        return

      cb(null, true)

  getIncident: (incident, cb) ->
    @get "/incidents/#{encodeURIComponent incident}", {}, (err, json) ->
      if err?
        cb(err)
        return

      cb(null, json.incident)

  getIncidents: (statuses, cb) ->
    query =
      statuses:  statuses.split ","
      sort_by: "incident_number:desc"
    @get "/incidents", query, (err, json) ->
      if err?
        cb(err)
        return

      cb(null, json.incidents)

  getSchedules: (query, cb) ->
    if typeof(query) is 'function'
      cb = query
      query = {}

    @getAll "/schedules", query, "schedules", (err, schedules) ->
      if err?
        cb(err)
        return

      # Remove any schedules with "hidden" in the name
      schedules = schedules.filter (schedule) ->
        if schedule.name?
          return schedule.name.indexOf("hidden") == -1
        else
          return true

      cb(null, schedules)
  
  getEscalationPolicies: (query, cb) ->
    if typeof(query) is 'function'
      cb = query
      query = {}

    @getAll "/escalation_policies", query, "escalation_policies", (err, escalation_policies) ->
      if err?
        cb(err)
        return

      cb(null, escalation_policies)
