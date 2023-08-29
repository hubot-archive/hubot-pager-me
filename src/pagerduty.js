/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
const HttpClient = require('scoped-http-client');

const pagerDutyApiKey        = process.env.HUBOT_PAGERDUTY_API_KEY;
const pagerDutySubdomain     = process.env.HUBOT_PAGERDUTY_SUBDOMAIN;
const pagerDutyBaseUrl       = 'https://api.pagerduty.com';
const pagerDutyServices      = process.env.HUBOT_PAGERDUTY_SERVICES;
const pagerDutyFromEmail     = process.env.HUBOT_PAGERDUTY_FROM_EMAIL;
let pagerNoop              = process.env.HUBOT_PAGERDUTY_NOOP;
if ((pagerNoop === 'false') || (pagerNoop === 'off')) { pagerNoop              = false; }

class PagerDutyError extends Error {}
module.exports = {
  http(path) {
    return HttpClient.create(`${pagerDutyBaseUrl}${path}`)
      .headers({
        'Accept': 'application/vnd.pagerduty+json;version=2',
        'Authorization': `Token token=${pagerDutyApiKey}`,
        'From': pagerDutyFromEmail
      });
  },

  missingEnvironmentForApi(msg) {
    let missingAnything = false;
    if (pagerDutyFromEmail == null) {
      msg.send("PagerDuty From is missing:  Ensure that HUBOT_PAGERDUTY_FROM_EMAIL is set.");
      missingAnything |= true;
    }
    if (pagerDutyApiKey == null) {
      msg.send("PagerDuty API Key is missing:  Ensure that HUBOT_PAGERDUTY_API_KEY is set.");
      missingAnything |= true;
    }
    return missingAnything;
  },

  get(url, query, cb) {
    if (typeof(query) === 'function') {
      cb = query;
      query = {};
    }

    if ((pagerDutyServices != null) && url.match(/\/incidents/)) {
      query['service_id'] = pagerDutyServices;
    }

    return this.http(url)
      .query(query)
      .get()(function(err, res, body) {
        if (err != null) {
          cb(err);
          return;
        }
        let json_body = null;
        switch (res.statusCode) {
          case 200: json_body = JSON.parse(body); break;
          default:
            cb(new PagerDutyError(`${res.statusCode} back from ${url}`));
        }

        return cb(null, json_body);
    });
  },

  put(url, data, cb) {
    if (pagerNoop) {
      console.log(`Would have PUT ${url}: ${inspect(data)}`);
      return;
    }

    const json = JSON.stringify(data);
    return this.http(url)
      .header('content-type', 'application/json')
      .put(json)(function(err, res, body) {
        if (err != null) {
          callback(err);
          return;
        }

        let json_body = null;
        switch (res.statusCode) {
          case 200: json_body = JSON.parse(body); break;
          default:
            if (body != null) {
              return cb(new PagerDutyError(`${res.statusCode} back from ${url} with body: ${body}`));
            } else {
              return cb(new PagerDutyError(`${res.statusCode} back from ${url}`));
            }
        }
        return cb(null, json_body);
    });
  },

  post(url, data, cb) {
    if (pagerNoop) {
      console.log(`Would have POST ${url}: ${inspect(data)}`);
      return;
    }

    const json = JSON.stringify(data);
    return this.http(url)
      .header('content-type', 'application/json')
      .post(json)(function(err, res, body) {
        if (err != null) {
          return cb(err);
        }

        let json_body = null;
        switch (res.statusCode) {
          case 201: json_body = JSON.parse(body); break;
          default:
            return cb(new PagerDutyError(`${res.statusCode} back from ${url}`));
        }
        return cb(null, json_body);
    });
  },

  delete(url, cb) {
    if (pagerNoop) {
      console.log(`Would have DELETE ${url}`);
      return;
    }

    const auth = `Token token=${pagerDutyApiKey}`;
    return this.http(url)
      .header("content-length",0)
      .delete()(function(err, res, body) {
        let value;
        if (err != null) {
          return cb(err);
        }
        const json_body = null;
        switch (res.statusCode) {
          case 204: case 200:
            value = true;
            break;
          default:
            console.log(res.statusCode);
            console.log(body);
            value = false;
        }
        return cb(null, value);
    });
  },

  getIncident(incident_key, cb) {
    const query =
      {incident_key};

    return this.get("/incidents", query, function(err, json) {
      if (err != null) {
        cb(err);
        return;
      }
      return cb(null, json.incidents);
    });
  },

  getIncidents(status, cb) {
    const query = {
      sort_by: 'incident_number:asc',
      'statuses[]': status.split(',')
    };

    return this.get("/incidents", query, function(err, json) {
      if (err != null) {
        cb(err);
        return;
      }
      return cb(null, json.incidents);
    });
  },

  getSchedules(query, cb) {
    if (typeof(query) === 'function') {
      cb = query;
      query = {};
    }

    return this.get("/schedules", query, function(err, json) {
      if (err != null) {
        cb(err);
        return;
      }

      return cb(null, json.schedules);
    });
  },

  subdomain: pagerDutySubdomain
};
