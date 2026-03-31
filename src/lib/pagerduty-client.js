const { api } = require('@pagerduty/pdjs');

function getPagerDutyApiKey() {
  return process.env.HUBOT_PAGERDUTY_API_KEY;
}

function getPagerDutyFromEmail() {
  return process.env.HUBOT_PAGERDUTY_FROM_EMAIL;
}

function getPagerDutyServiceIds() {
  const services = process.env.HUBOT_PAGERDUTY_SERVICES;
  if (!services || !services.trim()) {
    return null;
  }

  const ids = services
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  return ids.length ? ids : null;
}

function isPagerNoop() {
  const pagerNoop = process.env.HUBOT_PAGERDUTY_NOOP;
  if (!pagerNoop || pagerNoop === 'false' || pagerNoop === 'off') {
    return false;
  }
  return true;
}

/**
 * @class PagerDutyError
 * @extends Error
 */
class PagerDutyError extends Error {}

/** @type {any} */
let pdClient = null;
let pdClientToken = null;

/**
 * Get or initialize the PagerDuty API client
 * @returns {any} PagerDuty API client instance
 */
function getClient() {
  const token = getPagerDutyApiKey();

  if (!pdClient || pdClientToken !== token) {
    pdClient = api({
      token,
    });
    pdClientToken = token;
  }
  return pdClient;
}

/**
 * Build query string from query object with support for array parameters
 * @param {Object<string, any>} query - Query parameters
 * @returns {string} URL query string
 */
function buildQueryString(query) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (Array.isArray(value)) {
      value.forEach((v) => params.append(key, v));
    } else {
      params.append(key, value);
    }
  }
  return params.toString();
}

module.exports = {
  /**
   * Make an HTTP GET request to PagerDuty API
   * @param {string} url - The API endpoint path
   * @param {Object<string, any>} [query={}] - Query parameters
   * @param {Function} cb - Callback function(err, json)
   * @returns {void}
   */
  get(url, query, cb) {
    if (typeof query === 'function') {
      cb = query;
      query = {};
    }

    // Add service_id filtering only for the incidents list endpoint.
    const serviceIds = getPagerDutyServiceIds();
    if (serviceIds && url === '/incidents') {
      query['service_ids[]'] = serviceIds;
    }

    this._getAsync(url, query)
      .then((data) => cb(null, data))
      .catch((err) => cb(err));
  },

  /**
   * Internal async GET implementation
   * @private
   * @param {string} url - The API endpoint path
   * @param {Object<string, any>} query - Query parameters
   * @returns {Promise<any>} Resolves with response data
   */
  async _getAsync(url, query) {
    const client = getClient();
    const queryString = buildQueryString(query);
    const fullUrl = queryString ? `${url}?${queryString}` : url;
    const fromEmail = getPagerDutyFromEmail();
    const options = {
      headers: fromEmail ? { From: fromEmail } : {},
    };

    try {
      const { data } = await client.get(fullUrl, options);
      return data;
    } catch (err) {
      if (err.response && err.response.statusCode) {
        throw new PagerDutyError(`${err.response.statusCode} back from ${url}`);
      }
      throw err;
    }
  },

  /**
   * Make an HTTP PUT request to PagerDuty API
   * @param {string} url - The API endpoint path
   * @param {Object} data - Request body
   * @param {Function} cb - Callback function(err, json)
   * @returns {void}
   */
  put(url, data, cb) {
    if (isPagerNoop()) {
      console.log(`Would have PUT ${url}: ${JSON.stringify(data)}`);
      return;
    }

    this._putAsync(url, data)
      .then((responseData) => cb(null, responseData))
      .catch((err) => cb(err));
  },

  /**
   * Internal async PUT implementation
   * @private
   * @param {string} url - The API endpoint path
   * @param {Object} data - Request body
   * @returns {Promise<any>} Resolves with response data
   */
  async _putAsync(url, data) {
    const client = getClient();
    const fromEmail = getPagerDutyFromEmail();
    const headers = fromEmail ? { From: fromEmail } : {};

    try {
      const { data: responseData } = await client.put(url, {
        data,
        headers,
      });
      return responseData;
    } catch (err) {
      if (err.response && err.response.statusCode) {
        const errorMsg = err.response.body
          ? `${err.response.statusCode} back from ${url} with body: ${JSON.stringify(err.response.body)}`
          : `${err.response.statusCode} back from ${url}`;
        throw new PagerDutyError(errorMsg);
      }
      throw err;
    }
  },

  /**
   * Make an HTTP POST request to PagerDuty API
   * @param {string} url - The API endpoint path
   * @param {Object} data - Request body
   * @param {Function} cb - Callback function(err, json)
   * @returns {void}
   */
  post(url, data, cb) {
    if (isPagerNoop()) {
      console.log(`Would have POST ${url}: ${JSON.stringify(data)}`);
      return;
    }

    this._postAsync(url, data)
      .then((responseData) => cb(null, responseData))
      .catch((err) => cb(err));
  },

  /**
   * Internal async POST implementation
   * @private
   * @param {string} url - The API endpoint path
   * @param {Object} data - Request body
   * @returns {Promise<any>} Resolves with response data
   */
  async _postAsync(url, data) {
    const client = getClient();
    const fromEmail = getPagerDutyFromEmail();
    const headers = fromEmail ? { From: fromEmail } : {};

    try {
      const { data: responseData } = await client.post(url, {
        data,
        headers,
      });
      return responseData;
    } catch (err) {
      if (err.response && err.response.statusCode) {
        throw new PagerDutyError(`${err.response.statusCode} back from ${url}`);
      }
      throw err;
    }
  },

  /**
   * Make an HTTP DELETE request to PagerDuty API
   * @param {string} url - The API endpoint path
   * @param {Function} cb - Callback function(err, success)
   * @returns {void}
   */
  delete(url, cb) {
    if (isPagerNoop()) {
      console.log(`Would have DELETE ${url}`);
      return;
    }

    this._deleteAsync(url)
      .then((success) => cb(null, success))
      .catch((err) => cb(err));
  },

  /**
   * Internal async DELETE implementation
   * @private
   * @param {string} url - The API endpoint path
   * @returns {Promise<boolean>} Resolves with success status
   */
  async _deleteAsync(url) {
    const client = getClient();
    const fromEmail = getPagerDutyFromEmail();
    const headers = fromEmail ? { From: fromEmail } : {};

    try {
      await client.delete(url, { headers });
      return true;
    } catch (err) {
      if (err.response && err.response.statusCode) {
        if (err.response.statusCode === 204 || err.response.statusCode === 200) {
          return true;
        }
        console.log(err.response.statusCode);
        console.log(err.response.body);
        return false;
      }
      throw err;
    }
  },

  /**
   * Get an incident by incident_key
   * @param {string} incident_key - The incident key to search for
   * @param {Function} cb - Callback function(err, incidents)
   * @returns {void}
   */
  getIncident(incident_key, cb) {
    const query = { incident_key };

    this.get('/incidents', query, function (err, json) {
      if (err != null) {
        cb(err);
        return;
      }
      cb(null, json.incidents);
    });
  },

  /**
   * Get incidents filtered by status
   * @param {string} status - Comma-separated status values (e.g., 'triggered,acknowledged')
   * @param {Function} cb - Callback function(err, incidents)
   * @returns {void}
   */
  getIncidents(status, cb) {
    const query = {
      sort_by: 'incident_number:asc',
      'statuses[]': status.split(','),
    };

    this.get('/incidents', query, function (err, json) {
      if (err != null) {
        cb(err);
        return;
      }

      cb(null, json.incidents);
    });
  },

  /**
   * Get schedules
   * @param {Object|Function} [query] - Query parameters or callback if omitted
   * @param {Function} [cb] - Callback function(err, schedules)
   * @returns {void}
   */
  getSchedules(query, cb) {
    if (typeof query === 'function') {
      cb = query;
      query = {};
    }

    this.get('/schedules', query, function (err, json) {
      if (err != null) {
        cb(err);
        return;
      }

      cb(null, json.schedules);
    });
  },

  /**
   * Check for missing environment configuration
   * @param {Object} msg - Hubot message object with send method
   * @returns {boolean} True if any required env vars are missing
   */
  missingEnvironmentForApi(msg) {
    let missingAnything = false;
    if (getPagerDutyFromEmail() == null) {
      msg.send('PagerDuty From is missing:  Ensure that HUBOT_PAGERDUTY_FROM_EMAIL is set.');
      missingAnything = true;
    }
    if (getPagerDutyApiKey() == null) {
      msg.send('PagerDuty API Key is missing:  Ensure that HUBOT_PAGERDUTY_API_KEY is set.');
      missingAnything = true;
    }
    return missingAnything;
  },
};

